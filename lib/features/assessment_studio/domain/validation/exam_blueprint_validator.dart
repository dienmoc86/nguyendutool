import '../../../teaching_suite/domain/models/question_models.dart';
import '../models/exam_matrix.dart';
import '../models/exam_specification.dart';

/// Validation result for Exam Matrix and Blueprint (Section 17).
class ExamBlueprintValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const ExamBlueprintValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  bool get hasErrors => errors.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
}

/// Validates an Exam Matrix against its Specification (GDPT 2018) (Sections 12 & 17).
class ExamBlueprintValidator {
  const ExamBlueprintValidator();

  ExamBlueprintValidationResult validate({
    required ExamSpecification specification,
    required ExamMatrix matrix,
    List<String> definedObjectiveIds = const [],
  }) {
    final List<String> errors = [];
    final List<String> warnings = [];

    // 1. Objectives presence check
    if (matrix.cells.isEmpty) {
      errors.add('NO_OBJECTIVES: Ma trận đề chưa có mục tiêu học tập (YCCĐ) nào được thiết lập.');
    }

    // 2. Question count check
    if (matrix.totalQuestionCount == 0) {
      errors.add('NO_QUESTION_COVERAGE: Ma trận chưa phân bổ số lượng câu hỏi nào.');
    } else if (matrix.totalQuestionCount != specification.questionCount) {
      errors.add(
        'QUESTION_COUNT_MISMATCH: Tổng số câu trong ma trận (${matrix.totalQuestionCount} câu) '
        'không khớp với đặc tả yêu cầu (${specification.questionCount} câu).',
      );
    }

    // 3. Total score check (floating-point safe)
    if (!matrix.matchesTotalScore(specification.totalScore)) {
      errors.add(
        'TOTAL_SCORE_MISMATCH: Tổng điểm ma trận (${matrix.totalScore.toStringAsFixed(2)} đ) '
        'không khớp với thang điểm đặc tả (${specification.totalScore.toStringAsFixed(2)} đ).',
      );
    }

    // 4. Matrix cell validity
    for (final cell in matrix.cells) {
      if (cell.questionCount < 0 || cell.scorePerQuestion < 0) {
        errors.add(
          'INVALID_MATRIX_CELL: Ô ma trận [Mục tiêu: ${cell.objectiveId}, Mức: ${cell.difficulty.label}] '
          'có giá trị âm không hợp lệ.',
        );
      }
    }

    // 5. Warnings: Unbalanced difficulty
    for (final diff in QuestionDifficulty.values) {
      final count = matrix.getQuestionCountByDifficulty(diff);
      if (count == 0 && matrix.totalQuestionCount > 4) {
        warnings.add(
          'UNBALANCED_DIFFICULTY: Ma trận chưa có câu hỏi nào thuộc mức độ nhận thức [${diff.label}].',
        );
      }
    }

    // 6. Warnings: Defined objectives not covered
    for (final objId in definedObjectiveIds) {
      final count = matrix.getQuestionCountByObjective(objId);
      if (count == 0) {
        warnings.add(
          'OBJECTIVE_NOT_COVERED: Mục tiêu học tập [$objId] chưa được phân bổ câu hỏi trong ma trận.',
        );
      }
    }

    return ExamBlueprintValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }
}
