import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/logging/app_logger.dart';
import '../../teaching_suite/domain/models/question_models.dart';
import '../data/assessment_repository.dart';
import '../domain/models/exam_matrix.dart';
import '../domain/models/exam_paper.dart';
import '../domain/models/exam_question_snapshot.dart';
import '../domain/models/exam_specification.dart';
import '../domain/services/exam_question_selector.dart';
import 'assessment_project_notifier.dart';

class ExamBuilderState {
  final ExamPaper? masterPaper;
  final ExamSelectionResult? selectionResult;
  final bool isGenerating;
  final bool isFinalizing;
  final String? errorMessage;

  const ExamBuilderState({
    this.masterPaper,
    this.selectionResult,
    this.isGenerating = false,
    this.isFinalizing = false,
    this.errorMessage,
  });

  ExamBuilderState copyWith({
    ExamPaper? masterPaper,
    bool clearPaper = false,
    ExamSelectionResult? selectionResult,
    bool clearSelection = false,
    bool? isGenerating,
    bool? isFinalizing,
    String? errorMessage,
  }) {
    return ExamBuilderState(
      masterPaper: clearPaper ? null : (masterPaper ?? this.masterPaper),
      selectionResult: clearSelection ? null : (selectionResult ?? this.selectionResult),
      isGenerating: isGenerating ?? this.isGenerating,
      isFinalizing: isFinalizing ?? this.isFinalizing,
      errorMessage: errorMessage,
    );
  }
}

class ExamBuilderNotifier extends StateNotifier<ExamBuilderState> {
  final AssessmentRepository _repository;
  final ExamQuestionSelector _selector;

  ExamBuilderNotifier(this._repository, [this._selector = const ExamQuestionSelector()])
      : super(const ExamBuilderState());

  /// Loads existing master exam paper for an assessment project.
  Future<ExamPaper?> loadMasterPaper(String projectId) async {
    try {
      final paper = await _repository.getExamPaper(projectId);
      state = state.copyWith(masterPaper: paper);
      return paper;
    } catch (e, st) {
      AppLogger.error('Failed to load master paper for project $projectId', e, st);
      state = state.copyWith(errorMessage: 'Lỗi tải đề thi gốc: $e');
      return null;
    }
  }

  /// Generates master exam paper according to matrix requirements (Sections 26, 27, 28, 64).
  Future<ExamSelectionResult> generateMasterPaper({
    required ExamMatrix matrix,
    required List<QuestionItem> bank,
    required ExamSpecification spec,
    int? seed,
  }) async {
    state = state.copyWith(isGenerating: true, errorMessage: null);

    try {
      final result = _selector.selectQuestions(
        matrix: matrix,
        questionBank: bank,
        randomSeed: seed,
      );

      if (!result.isSuccess) {
        state = state.copyWith(
          isGenerating: false,
          selectionResult: result,
          errorMessage: result.errorMessage,
        );
        return result;
      }

      final paper = ExamPaper(
        id: 'ep_${spec.projectId}_${DateTime.now().millisecondsSinceEpoch}',
        assessmentProjectId: spec.projectId,
        specificationId: spec.id,
        title: spec.title,
        examCode: 'MASTER',
        durationMinutes: spec.durationMinutes,
        totalScore: spec.totalScore,
        questions: result.questions,
        randomSeed: seed,
        revisionNumber: 1,
        isFinalized: false,
        createdAt: DateTime.now(),
      );

      await _repository.saveExamPaper(paper);
      state = state.copyWith(
        masterPaper: paper,
        selectionResult: result,
        isGenerating: false,
      );
      AppLogger.info('Generated Master Exam Paper: ${paper.id} with ${paper.questions.length} questions');
      return result;
    } catch (e, st) {
      AppLogger.error('Failed to generate master paper', e, st);
      state = state.copyWith(
        isGenerating: false,
        errorMessage: 'Lỗi tạo đề gốc theo ma trận: $e',
      );
      rethrow;
    }
  }

  /// Manually replaces a question in master exam with a compatible candidate (Section 65).
  Future<void> replaceQuestion({
    required int questionIndex,
    required QuestionItem newQuestion,
  }) async {
    if (state.masterPaper == null) return;
    final paper = state.masterPaper!;
    if (paper.isFinalized) {
      throw FinalizedExamImmutableException(
        'Đề thi ${paper.id} đã được chốt duyệt (Finalized) và là bất biến. Hãy tạo bản hiệu đính (revision) mới để thay thế câu hỏi.',
        paperId: paper.id,
      );
    }
    if (questionIndex < 0 || questionIndex >= paper.questions.length) return;

    final currentSnap = paper.questions[questionIndex];

    // Section 15: Candidate compatibility validation
    if (paper.questions.any((q) => q.questionId == newQuestion.id && q != currentSnap)) {
      throw ArgumentError('Câu hỏi ${newQuestion.id} đã tồn tại trong đề thi.');
    }
    if (newQuestion.difficulty != currentSnap.difficulty) {
      throw ArgumentError('Mức độ câu hỏi mới (${newQuestion.difficulty.label}) không khớp với vị trí (${currentSnap.difficulty.label}).');
    }
    if (newQuestion.type != currentSnap.type) {
      throw ArgumentError('Dạng câu hỏi mới (${newQuestion.type.label}) không khớp với dạng yêu cầu (${currentSnap.type.label}).');
    }
    if (currentSnap.objectiveId != null &&
        currentSnap.objectiveId!.isNotEmpty &&
        currentSnap.objectiveId != 'ALL') {
      if (newQuestion.learningObjective != currentSnap.objectiveId) {
        throw ArgumentError('Mục tiêu học tập câu hỏi mới (${newQuestion.learningObjective}) không khớp với mục tiêu yêu cầu (${currentSnap.objectiveId}).');
      }
    }

    final newSnap = ExamQuestionSnapshot.fromQuestionItem(
      newQuestion,
      score: currentSnap.score,
      sectionIndex: currentSnap.sectionIndex,
    );

    final updatedQuestions = List<ExamQuestionSnapshot>.from(paper.questions);
    updatedQuestions[questionIndex] = newSnap;

    final updatedPaper = paper.copyWith(questions: updatedQuestions);
    await _repository.saveExamPaper(updatedPaper);
    state = state.copyWith(masterPaper: updatedPaper);
    AppLogger.info('Replaced question at index $questionIndex in paper ${paper.id}');
  }

  /// Reorders questions in the master exam (Section 29).
  Future<void> reorderQuestions(int oldIndex, int newIndex) async {
    if (state.masterPaper == null) return;
    final paper = state.masterPaper!;
    if (paper.isFinalized) {
      throw FinalizedExamImmutableException(
        'Đề thi ${paper.id} đã được chốt duyệt (Finalized) và là bất biến. Không thể sắp xếp lại câu hỏi.',
        paperId: paper.id,
      );
    }
    final questions = List<ExamQuestionSnapshot>.from(paper.questions);

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = questions.removeAt(oldIndex);
    questions.insert(newIndex, item);

    final updatedPaper = paper.copyWith(questions: questions);
    await _repository.saveExamPaper(updatedPaper);
    state = state.copyWith(masterPaper: updatedPaper);
  }

  /// Creates an explicit new revision from a finalized exam paper.
  Future<ExamPaper> createRevision() async {
    if (state.masterPaper == null) {
      throw StateError('Chưa có đề thi gốc để tạo revision.');
    }
    final current = state.masterPaper!;
    final newRevision = await _repository.createNewRevision(current.id);
    state = state.copyWith(masterPaper: newRevision);
    return newRevision;
  }

  /// Finalizes the master exam into an immutable snapshot (Section 30 & 86).
  Future<void> finalizePaper() async {
    if (state.masterPaper == null) return;
    state = state.copyWith(isFinalizing: true);

    try {
      final paper = state.masterPaper!;
      final finalized = paper.copyWith(
        isFinalized: true,
        finalizedAt: DateTime.now(),
      );
      await _repository.saveExamPaper(finalized);
      state = state.copyWith(masterPaper: finalized, isFinalizing: false);
      AppLogger.info('Finalized exam paper ${paper.id}');
    } catch (e) {
      AppLogger.error('Failed to finalize exam paper: $e');
      state = state.copyWith(isFinalizing: false, errorMessage: 'Lỗi chốt duyệt đề: $e');
    }
  }

  void reset() {
    state = const ExamBuilderState();
  }
}

final examBuilderNotifierProvider =
    StateNotifierProvider<ExamBuilderNotifier, ExamBuilderState>((ref) {
  final repo = ref.watch(assessmentRepositoryProvider);
  return ExamBuilderNotifier(repo);
});
