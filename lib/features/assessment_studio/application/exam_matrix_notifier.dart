import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/logging/app_logger.dart';
import '../../teaching_suite/domain/models/learning_objective.dart';
import '../../teaching_suite/domain/models/question_models.dart';
import '../data/assessment_repository.dart';
import '../domain/models/exam_matrix.dart';
import '../domain/models/exam_specification.dart';
import '../domain/validation/exam_blueprint_validator.dart';
import 'assessment_project_notifier.dart';

class ExamMatrixState {
  final ExamMatrix? matrix;
  final List<LearningObjective> objectives;
  final ExamBlueprintValidationResult? validationResult;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  const ExamMatrixState({
    this.matrix,
    this.objectives = const [],
    this.validationResult,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
  });

  ExamMatrixState copyWith({
    ExamMatrix? matrix,
    bool clearMatrix = false,
    List<LearningObjective>? objectives,
    ExamBlueprintValidationResult? validationResult,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
  }) {
    return ExamMatrixState(
      matrix: clearMatrix ? null : (matrix ?? this.matrix),
      objectives: objectives ?? this.objectives,
      validationResult: validationResult ?? this.validationResult,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
    );
  }
}

class ExamMatrixNotifier extends StateNotifier<ExamMatrixState> {
  final AssessmentRepository _repository;
  final ExamBlueprintValidator _validator;

  ExamMatrixNotifier(this._repository, [this._validator = const ExamBlueprintValidator()])
      : super(const ExamMatrixState());

  /// Loads or initializes the ExamMatrix for a given specification and project.
  Future<ExamMatrix> loadForSpecification({
    required String specificationId,
    required String projectId,
    required ExamSpecification specification,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // 1. Load objectives
      var objs = await _repository.getLearningObjectives(projectId);
      if (objs.isEmpty) {
        // Create initial default GDPT 2018 learning objective
        final defaultObj = LearningObjective(
          id: 'obj_${projectId}_kt1',
          projectId: projectId,
          code: 'NL_01',
          description: 'Năng lực đọc hiểu và cảm thụ tác phẩm văn học',
          category: 'Năng lực đặc thù',
          orderIndex: 0,
        );
        await _repository.saveLearningObjectives(projectId, [defaultObj]);
        objs = [defaultObj];
      }

      // 2. Load matrix
      var matrix = await _repository.getMatrix(specificationId);
      if (matrix == null || matrix.cells.isEmpty) {
        // Initialize default cells across objectives and 4 cognitive levels
        final List<ExamMatrixCell> initialCells = [];
        for (final obj in objs) {
          for (final diff in QuestionDifficulty.values) {
            initialCells.add(
              ExamMatrixCell(
                id: 'cell_${specificationId}_${obj.id}_${diff.name}',
                specificationId: specificationId,
                objectiveId: obj.id,
                difficulty: diff,
                questionCount: diff == QuestionDifficulty.nhanBiet ? 2 : 1,
                scorePerQuestion: 0.25,
              ),
            );
          }
        }
        matrix = ExamMatrix(specificationId: specificationId, cells: initialCells);
        await _repository.saveMatrix(matrix);
      }

      // 3. Validate
      final vResult = _validator.validate(
        specification: specification,
        matrix: matrix,
        definedObjectiveIds: objs.map((o) => o.id).toList(),
      );

      state = state.copyWith(
        matrix: matrix,
        objectives: objs,
        validationResult: vResult,
        isLoading: false,
      );
      return matrix;
    } catch (e, st) {
      AppLogger.error('Failed to load matrix for spec $specificationId', e, st);
      state = state.copyWith(isLoading: false, errorMessage: 'Lỗi tải ma trận đề: $e');
      rethrow;
    }
  }

  /// Updates a cell in the matrix and recalculates validation immediately.
  Future<void> updateCell(ExamMatrixCell updatedCell, ExamSpecification spec) async {
    if (state.matrix == null) return;
    try {
      final currentCells = List<ExamMatrixCell>.from(state.matrix!.cells);
      final idx = currentCells.indexWhere((c) =>
          c.objectiveId == updatedCell.objectiveId && c.difficulty == updatedCell.difficulty);

      if (idx >= 0) {
        currentCells[idx] = updatedCell;
      } else {
        currentCells.add(updatedCell);
      }

      final updatedMatrix = state.matrix!.copyWith(cells: currentCells);
      final vResult = _validator.validate(
        specification: spec,
        matrix: updatedMatrix,
        definedObjectiveIds: state.objectives.map((o) => o.id).toList(),
      );

      state = state.copyWith(matrix: updatedMatrix, validationResult: vResult);
      await _repository.saveMatrix(updatedMatrix);
    } catch (e) {
      AppLogger.error('Failed to update matrix cell: $e');
    }
  }

  /// Imports objectives from linked Teaching Suite lesson project (Section 15).
  Future<void> importObjectivesFromLessonProject({
    required String lessonProjectId,
    required String assessmentProjectId,
    required ExamSpecification spec,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final imported = await _repository.importObjectivesFromLessonProject(
        sourceLessonProjectId: lessonProjectId,
        targetAssessmentProjectId: assessmentProjectId,
      );

      if (imported.isNotEmpty && state.matrix != null) {
        // Expand matrix cells for new objectives if not present
        final currentCells = List<ExamMatrixCell>.from(state.matrix!.cells);
        for (final obj in imported) {
          for (final diff in QuestionDifficulty.values) {
            final exists = currentCells.any((c) => c.objectiveId == obj.id && c.difficulty == diff);
            if (!exists) {
              currentCells.add(
                ExamMatrixCell(
                  id: 'cell_${spec.id}_${obj.id}_${diff.name}',
                  specificationId: spec.id,
                  objectiveId: obj.id,
                  difficulty: diff,
                  questionCount: 0,
                  scorePerQuestion: 0.25,
                ),
              );
            }
          }
        }
        final updatedMatrix = state.matrix!.copyWith(cells: currentCells);
        await _repository.saveMatrix(updatedMatrix);

        final vResult = _validator.validate(
          specification: spec,
          matrix: updatedMatrix,
          definedObjectiveIds: imported.map((o) => o.id).toList(),
        );

        state = state.copyWith(
          objectives: imported,
          matrix: updatedMatrix,
          validationResult: vResult,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      AppLogger.error('Failed to import objectives: $e');
      state = state.copyWith(isLoading: false, errorMessage: 'Lỗi import mục tiêu: $e');
    }
  }

  /// Adds a new objective manually (Section 16).
  Future<void> addObjective(LearningObjective objective, ExamSpecification spec) async {
    try {
      final currentObjs = [...state.objectives, objective];
      await _repository.saveLearningObjectives(objective.projectId, currentObjs);

      // Create cells for new objective
      final currentCells = List<ExamMatrixCell>.from(state.matrix?.cells ?? []);
      for (final diff in QuestionDifficulty.values) {
        currentCells.add(
          ExamMatrixCell(
            id: 'cell_${spec.id}_${objective.id}_${diff.name}',
            specificationId: spec.id,
            objectiveId: objective.id,
            difficulty: diff,
            questionCount: 0,
            scorePerQuestion: 0.25,
          ),
        );
      }

      final updatedMatrix = (state.matrix ?? ExamMatrix(specificationId: spec.id)).copyWith(cells: currentCells);
      await _repository.saveMatrix(updatedMatrix);

      final vResult = _validator.validate(
        specification: spec,
        matrix: updatedMatrix,
        definedObjectiveIds: currentObjs.map((o) => o.id).toList(),
      );

      state = state.copyWith(objectives: currentObjs, matrix: updatedMatrix, validationResult: vResult);
    } catch (e) {
      AppLogger.error('Failed to add objective: $e');
    }
  }

  void reset() {
    state = const ExamMatrixState();
  }
}

final examMatrixNotifierProvider =
    StateNotifierProvider<ExamMatrixNotifier, ExamMatrixState>((ref) {
  final repo = ref.watch(assessmentRepositoryProvider);
  return ExamMatrixNotifier(repo);
});
