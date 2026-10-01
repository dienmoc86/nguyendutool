import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/logging/app_logger.dart';
import '../../teaching_suite/application/ai_text_generation_service.dart';
import '../../teaching_suite/application/teaching_suite_providers.dart';
import '../../teaching_suite/domain/models/lesson_project_data.dart';
import '../../teaching_suite/domain/models/question_models.dart';
import '../data/assessment_repository.dart';
import 'assessment_project_notifier.dart';

class AssessmentQuestionBankState {
  final List<QuestionItem> allQuestions;
  final List<QuestionItem> filteredQuestions;
  final String searchQuery;
  final String? selectedObjective;
  final QuestionDifficulty? selectedDifficulty;
  final QuestionType? selectedType;
  final bool isLoading;
  final bool isGeneratingAi;
  final String? errorMessage;

  const AssessmentQuestionBankState({
    this.allQuestions = const [],
    this.filteredQuestions = const [],
    this.searchQuery = '',
    this.selectedObjective,
    this.selectedDifficulty,
    this.selectedType,
    this.isLoading = false,
    this.isGeneratingAi = false,
    this.errorMessage,
  });

  AssessmentQuestionBankState copyWith({
    List<QuestionItem>? allQuestions,
    List<QuestionItem>? filteredQuestions,
    String? searchQuery,
    String? selectedObjective,
    bool clearObjective = false,
    QuestionDifficulty? selectedDifficulty,
    bool clearDifficulty = false,
    QuestionType? selectedType,
    bool clearType = false,
    bool? isLoading,
    bool? isGeneratingAi,
    String? errorMessage,
  }) {
    return AssessmentQuestionBankState(
      allQuestions: allQuestions ?? this.allQuestions,
      filteredQuestions: filteredQuestions ?? this.filteredQuestions,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedObjective: clearObjective ? null : (selectedObjective ?? this.selectedObjective),
      selectedDifficulty: clearDifficulty ? null : (selectedDifficulty ?? this.selectedDifficulty),
      selectedType: clearType ? null : (selectedType ?? this.selectedType),
      isLoading: isLoading ?? this.isLoading,
      isGeneratingAi: isGeneratingAi ?? this.isGeneratingAi,
      errorMessage: errorMessage,
    );
  }
}

class AssessmentQuestionBankNotifier extends StateNotifier<AssessmentQuestionBankState> {
  final AssessmentRepository _repository;
  final AiTextGenerationService? _aiService;

  AssessmentQuestionBankNotifier(this._repository, [this._aiService])
      : super(const AssessmentQuestionBankState());

  /// Loads questions for project and linked lesson project.
  Future<void> loadQuestions(String projectId, {String? linkedLessonProjectId}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final questions = await _repository.getQuestionBank(
        projectId,
        linkedLessonProjectId: linkedLessonProjectId,
      );
      state = state.copyWith(
        allQuestions: questions,
        filteredQuestions: _applyFilters(
          questions,
          state.searchQuery,
          state.selectedObjective,
          state.selectedDifficulty,
          state.selectedType,
        ),
        isLoading: false,
      );
      AppLogger.info('Loaded ${questions.length} questions for Assessment Bank ($projectId)');
    } catch (e, st) {
      AppLogger.error('Failed to load assessment question bank', e, st);
      state = state.copyWith(isLoading: false, errorMessage: 'Lỗi tải ngân hàng câu hỏi: $e');
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(
      searchQuery: query,
      filteredQuestions: _applyFilters(
        state.allQuestions,
        query,
        state.selectedObjective,
        state.selectedDifficulty,
        state.selectedType,
      ),
    );
  }

  void filterByObjective(String? objId) {
    state = state.copyWith(
      selectedObjective: objId,
      clearObjective: objId == null || objId == 'ALL',
      filteredQuestions: _applyFilters(
        state.allQuestions,
        state.searchQuery,
        objId == 'ALL' ? null : objId,
        state.selectedDifficulty,
        state.selectedType,
      ),
    );
  }

  void filterByDifficulty(QuestionDifficulty? diff) {
    state = state.copyWith(
      selectedDifficulty: diff,
      clearDifficulty: diff == null,
      filteredQuestions: _applyFilters(
        state.allQuestions,
        state.searchQuery,
        state.selectedObjective,
        diff,
        state.selectedType,
      ),
    );
  }

  void filterByType(QuestionType? type) {
    state = state.copyWith(
      selectedType: type,
      clearType: type == null,
      filteredQuestions: _applyFilters(
        state.allQuestions,
        state.searchQuery,
        state.selectedObjective,
        state.selectedDifficulty,
        type,
      ),
    );
  }

  /// Adds or updates a question with strict MCQ validation (Section 19).
  Future<void> saveQuestion(QuestionItem question, String projectId) async {
    if (question.type == QuestionType.multipleChoice && !question.isValidMcq) {
      throw ArgumentError('Câu hỏi trắc nghiệm MCQ phải có đúng 4 lựa chọn không trùng lặp và đáp án hợp lệ.');
    }

    try {
      await _repository.saveQuestion(question, projectId);
      final current = List<QuestionItem>.from(state.allQuestions);
      final idx = current.indexWhere((q) => q.id == question.id);
      if (idx >= 0) {
        current[idx] = question;
      } else {
        current.add(question);
      }

      state = state.copyWith(
        allQuestions: current,
        filteredQuestions: _applyFilters(
          current,
          state.searchQuery,
          state.selectedObjective,
          state.selectedDifficulty,
          state.selectedType,
        ),
      );
    } catch (e) {
      AppLogger.error('Failed to save question: $e');
      rethrow;
    }
  }

  /// Deletes a question from bank.
  Future<void> deleteQuestion(String questionId, String projectId) async {
    try {
      await _repository.deleteQuestion(questionId);
      final updated = state.allQuestions.where((q) => q.id != questionId).toList();
      state = state.copyWith(
        allQuestions: updated,
        filteredQuestions: _applyFilters(
          updated,
          state.searchQuery,
          state.selectedObjective,
          state.selectedDifficulty,
          state.selectedType,
        ),
      );
    } catch (e) {
      AppLogger.error('Failed to delete question: $e');
    }
  }

  /// Generates questions using AI and strict JSON response parser (Sections 22, 23).
  Future<List<QuestionItem>> generateQuestionsWithAi({
    required String projectId,
    required String subject,
    required String grade,
    required String topic,
    required QuestionDifficulty difficulty,
    required QuestionType type,
    required int count,
    String? objectiveId,
  }) async {
    if (_aiService == null) {
      throw StateError('Dịch vụ AI chưa được cấu hình.');
    }

    state = state.copyWith(isGeneratingAi: true, errorMessage: null);

    try {
      final lessonProj = LessonProjectData(
        subject: subject,
        grade: grade,
        lessonTitle: topic,
      );

      final rawItems = await _aiService.generateQuestions(
        project: lessonProj,
        count: count,
        difficulty: difficulty,
        type: type,
      );

      final List<QuestionItem> generatedItems = [];
      for (final q in rawItems) {
        final item = q.copyWith(
          id: 'q_ai_${DateTime.now().millisecondsSinceEpoch}_${generatedItems.length}',
          learningObjective: objectiveId,
          tags: ['AI_Draft', topic],
        );
        await _repository.saveQuestion(item, projectId);
        generatedItems.add(item);
      }

      final updatedAll = [...state.allQuestions, ...generatedItems];
      state = state.copyWith(
        allQuestions: updatedAll,
        filteredQuestions: _applyFilters(
          updatedAll,
          state.searchQuery,
          state.selectedObjective,
          state.selectedDifficulty,
          state.selectedType,
        ),
        isGeneratingAi: false,
      );
      return generatedItems;
    } catch (e, st) {
      AppLogger.error('Failed to generate AI questions', e, st);
      state = state.copyWith(
        isGeneratingAi: false,
        errorMessage: 'Lỗi sinh câu hỏi AI: $e',
      );
      rethrow;
    }
  }

  List<QuestionItem> _applyFilters(
    List<QuestionItem> questions,
    String query,
    String? objectiveId,
    QuestionDifficulty? diff,
    QuestionType? type,
  ) {
    return questions.where((q) {
      if (objectiveId != null && objectiveId.isNotEmpty && objectiveId != 'ALL') {
        if (q.learningObjective != objectiveId) return false;
      }
      if (diff != null && q.difficulty != diff) return false;
      if (type != null && q.type != type) return false;
      if (query.isNotEmpty) {
        final qLower = query.toLowerCase();
        final matchPrompt = q.prompt.toLowerCase().contains(qLower);
        final matchChoice = q.choices.any((c) => c.toLowerCase().contains(qLower));
        final matchTag = q.tags.any((t) => t.toLowerCase().contains(qLower));
        if (!matchPrompt && !matchChoice && !matchTag) return false;
      }
      return true;
    }).toList();
  }

  void reset() {
    state = const AssessmentQuestionBankState();
  }
}

final assessmentQuestionBankNotifierProvider =
    StateNotifierProvider<AssessmentQuestionBankNotifier, AssessmentQuestionBankState>((ref) {
  final repo = ref.watch(assessmentRepositoryProvider);
  final aiService = ref.watch(aiTextGenerationServiceProvider);
  return AssessmentQuestionBankNotifier(repo, aiService);
});
