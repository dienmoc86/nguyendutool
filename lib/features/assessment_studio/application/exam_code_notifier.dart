import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/projects/data/workspace_project_repository.dart';
import '../../teaching_suite/domain/models/learning_objective.dart';
import '../data/assessment_repository.dart';
import '../infrastructure/assessment_docx_exporter.dart';
import '../domain/models/assessment_project_data.dart';
import '../domain/models/exam_answer_key.dart';
import '../domain/models/exam_code.dart';
import '../domain/models/exam_export_result.dart';
import '../domain/models/exam_matrix.dart';
import '../domain/models/exam_paper.dart';
import '../domain/models/exam_specification.dart';
import '../domain/services/exam_code_engine.dart';
import '../domain/validation/exam_code_verifier.dart';
import '../domain/validation/exam_preflight_validator.dart';
import 'assessment_project_notifier.dart';

class ExamCodeState {
  final List<ExamCode> codes;
  final Map<String, ExamAnswerKey> answerKeys;
  final ExamPreflightValidationResult? preflightResult;
  final ExamExportResult? exportResult;
  final bool isGenerating;
  final bool isExporting;
  final String? errorMessage;

  const ExamCodeState({
    this.codes = const [],
    this.answerKeys = const {},
    this.preflightResult,
    this.exportResult,
    this.isGenerating = false,
    this.isExporting = false,
    this.errorMessage,
  });

  ExamCodeState copyWith({
    List<ExamCode>? codes,
    Map<String, ExamAnswerKey>? answerKeys,
    ExamPreflightValidationResult? preflightResult,
    bool clearPreflight = false,
    ExamExportResult? exportResult,
    bool clearExportResult = false,
    bool? isGenerating,
    bool? isExporting,
    String? errorMessage,
  }) {
    return ExamCodeState(
      codes: codes ?? this.codes,
      answerKeys: answerKeys ?? this.answerKeys,
      preflightResult: clearPreflight ? null : (preflightResult ?? this.preflightResult),
      exportResult: clearExportResult ? null : (exportResult ?? this.exportResult),
      isGenerating: isGenerating ?? this.isGenerating,
      isExporting: isExporting ?? this.isExporting,
      errorMessage: errorMessage,
    );
  }
}

class ExamCodeNotifier extends StateNotifier<ExamCodeState> {
  final AssessmentRepository _repository;
  final ExamCodeEngine _engine;
  final ExamCodeVerifier _codeVerifier;
  final ExamPreflightValidator _preflightValidator;

  ExamCodeNotifier(
    this._repository, [
    this._engine = const ExamCodeEngine(),
    this._codeVerifier = const ExamCodeVerifier(),
    this._preflightValidator = const ExamPreflightValidator(),
  ]) : super(const ExamCodeState());

  /// Loads student exam codes for a given master exam paper.
  Future<void> loadCodes(String examPaperId) async {
    try {
      final codes = await _repository.getExamCodes(examPaperId);
      final Map<String, ExamAnswerKey> answerKeys = {};

      for (final code in codes) {
        final List<ExamAnswerKeyItem> keyItems = [];
        for (final q in code.questions) {
          final snippet = q.snapshot.prompt.length > 60
              ? '${q.snapshot.prompt.substring(0, 60)}...'
              : q.snapshot.prompt;
          keyItems.add(
            ExamAnswerKeyItem(
              questionNumber: q.orderIndex + 1,
              correctDisplayAnswer: q.correctDisplayAnswer,
              score: q.score,
              questionId: q.questionId,
              promptSnippet: snippet,
              explanation: q.snapshot.explanation,
              type: q.snapshot.type,
            ),
          );
        }
        answerKeys[code.code] = ExamAnswerKey(examCode: code.code, items: keyItems);
      }

      state = state.copyWith(codes: codes, answerKeys: answerKeys);
    } catch (e, st) {
      AppLogger.error('Failed to load exam codes for $examPaperId', e, st);
    }
  }

  /// Generates multi-code exams with deterministic shuffle and choice remapping (Sections 32-35).
  Future<void> generateCodes({
    required ExamPaper masterPaper,
    int numberOfCodes = 4,
    int startingCode = 101,
    bool shuffleQuestions = true,
    bool shuffleChoices = true,
    int? seed,
  }) async {
    state = state.copyWith(isGenerating: true, errorMessage: null);

    try {
      final result = _engine.generateCodes(
        masterPaper: masterPaper,
        numberOfCodes: numberOfCodes,
        startingCode: startingCode,
        shuffleQuestions: shuffleQuestions,
        shuffleChoices: shuffleChoices,
        baseSeed: seed,
      );

      // Verify code equivalence against canonical master (Sections 10, 38, 39)
      final vResult = _codeVerifier.verifyCodes(result.codes, canonicalMaster: masterPaper);
      if (!vResult.isEquivalent) {
        throw StateError('Lỗi kiểm tra tính tương đương giữa các mã đề: ${vResult.mismatches.join(", ")}');
      }

      await _repository.saveExamCodes(result.codes);
      state = state.copyWith(
        codes: result.codes,
        answerKeys: result.answerKeys,
        isGenerating: false,
      );
      AppLogger.info('Generated and verified ${result.codes.length} student exam codes');
    } catch (e, st) {
      AppLogger.error('Failed to generate exam codes', e, st);
      state = state.copyWith(isGenerating: false, errorMessage: 'Lỗi sinh mã đề: $e');
      rethrow;
    }
  }

  /// Runs preflight checks before export (Sections 69, 70).
  ExamPreflightValidationResult runPreflight({
    required ExamSpecification specification,
    required ExamMatrix matrix,
    required ExamPaper masterPaper,
  }) {
    final result = _preflightValidator.validate(
      specification: specification,
      matrix: matrix,
      masterPaper: masterPaper,
      codes: state.codes,
      answerKeys: state.answerKeys,
    );
    state = state.copyWith(preflightResult: result);
    return result;
  }

  /// Executes full batch export of exam package (Sections 43-53).
  Future<ExamExportResult> exportPackage({
    required AssessmentProjectData project,
    required ExamSpecification specification,
    required ExamMatrix matrix,
    required List<LearningObjective> objectives,
    required ExamPaper masterPaper,
    required String baseExportDir,
    WorkspaceProjectRepository? projectRepository,
  }) async {
    state = state.copyWith(isExporting: true, errorMessage: null);

    try {
      // 1. Run Preflight
      final preflight = runPreflight(
        specification: specification,
        matrix: matrix,
        masterPaper: masterPaper,
      );

      if (!preflight.canExport) {
        state = state.copyWith(
          isExporting: false,
          errorMessage: 'Không thể xuất tệp: ${preflight.blockingErrors.join("\n")}',
        );
        return ExamExportResult(
          successful: false,
          exportDirectory: '',
          errors: preflight.blockingErrors,
        );
      }

      // 2. Export package
      final exportResult = await AssessmentDocxExporter.exportPackage(
        project: project,
        specification: specification,
        matrix: matrix,
        objectives: objectives,
        masterPaper: masterPaper,
        codes: state.codes,
        answerKeys: state.answerKeys,
        baseExportDir: baseExportDir,
        projectRepository: projectRepository,
      );

      state = state.copyWith(
        exportResult: exportResult,
        isExporting: false,
      );

      return exportResult;
    } catch (e, st) {
      AppLogger.error('Failed to export exam package', e, st);
      state = state.copyWith(
        isExporting: false,
        errorMessage: 'Lỗi xuất trọn bộ đề thi: $e',
      );
      return ExamExportResult(
        successful: false,
        exportDirectory: '',
        errors: [e.toString()],
      );
    }
  }

  void reset() {
    state = const ExamCodeState();
  }
}

final examCodeNotifierProvider =
    StateNotifierProvider<ExamCodeNotifier, ExamCodeState>((ref) {
  final repo = ref.watch(assessmentRepositoryProvider);
  return ExamCodeNotifier(repo);
});
