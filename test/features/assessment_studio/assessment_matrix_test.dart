import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/exam_matrix.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/exam_specification.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/validation/exam_blueprint_validator.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/learning_objective.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/question_models.dart';

void main() {
  group('Assessment Studio - Exam Matrix & Blueprint Validation Tests (Section 82)', () {
    const String projectId = 'proj_test_matrix';
    const String specId = 'spec_test_matrix';
    const validator = ExamBlueprintValidator();

    final objectives = [
      const LearningObjective(
        id: 'obj_1',
        projectId: projectId,
        code: 'NL_01',
        description: 'Nhận biết các yếu tố hình thức của văn bản truyện',
        category: 'Năng lực đọc hiểu',
        orderIndex: 1,
      ),
      const LearningObjective(
        id: 'obj_2',
        projectId: projectId,
        code: 'NL_02',
        description: 'Thông hiểu chủ đề và tư tưởng của đoạn trích',
        category: 'Năng lực đọc hiểu',
        orderIndex: 2,
      ),
      const LearningObjective(
        id: 'obj_3',
        projectId: projectId,
        code: 'NL_03',
        description: 'Vận dụng kiến thức tiếng Việt để giải bài tập',
        category: 'Năng lực thực hành tiếng Việt',
        orderIndex: 3,
      ),
    ];

    test('Matrix totals and hundredths decimal score precision (Section 13, 82)', () {
      final cells = [
        const ExamMatrixCell(
          id: 'c1',
          specificationId: specId,
          objectiveId: 'obj_1',
          difficulty: QuestionDifficulty.nhanBiet,
          questionCount: 4,
          scorePerQuestion: 0.50, // 4 * 0.50 = 2.0 pts
        ),
        const ExamMatrixCell(
          id: 'c2',
          specificationId: specId,
          objectiveId: 'obj_2',
          difficulty: QuestionDifficulty.thongHieu,
          questionCount: 4,
          scorePerQuestion: 0.75, // 4 * 0.75 = 3.0 pts
        ),
        const ExamMatrixCell(
          id: 'c3',
          specificationId: specId,
          objectiveId: 'obj_3',
          difficulty: QuestionDifficulty.vanDung,
          questionCount: 5,
          scorePerQuestion: 1.00, // 5 * 1.00 = 5.0 pts
        ),
      ];

      final matrix = ExamMatrix(
        specificationId: specId,
        cells: cells,
      );

      expect(matrix.totalQuestionCount, equals(13));
      // (4 * 50) + (4 * 75) + (5 * 100) = 200 + 300 + 500 = 1000 hundredths = 10.00 pts
      expect(matrix.totalScoreHundredths, equals(1000));
      expect(matrix.totalScore, equals(10.0));
      expect(matrix.hasCellFor('obj_1', QuestionDifficulty.nhanBiet), isTrue);
      expect(matrix.getCell('obj_1', QuestionDifficulty.nhanBiet)?.questionCount, equals(4));
    });

    test('Valid blueprint passes validation with zero errors (Section 12, 17)', () {
      final spec = ExamSpecification(
        id: specId,
        projectId: projectId,
        title: 'Đề kiểm tra giữa kỳ I - Ngữ văn 9',
        subject: 'Ngữ văn',
        grade: '9',
        durationMinutes: 90,
        totalScore: 10.0,
        questionCount: 10,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final cells = [
        const ExamMatrixCell(
          id: 'c1',
          specificationId: specId,
          objectiveId: 'obj_1',
          difficulty: QuestionDifficulty.nhanBiet,
          questionCount: 4,
          scorePerQuestion: 1.00, // 4 * 1.0 = 4.0 pts
        ),
        const ExamMatrixCell(
          id: 'c2',
          specificationId: specId,
          objectiveId: 'obj_2',
          difficulty: QuestionDifficulty.thongHieu,
          questionCount: 3,
          scorePerQuestion: 1.00, // 3 * 1.0 = 3.0 pts
        ),
        const ExamMatrixCell(
          id: 'c3',
          specificationId: specId,
          objectiveId: 'obj_3',
          difficulty: QuestionDifficulty.vanDung,
          questionCount: 3,
          scorePerQuestion: 1.00, // 3 * 1.0 = 3.0 pts
        ),
      ];

      final matrix = ExamMatrix(
        specificationId: specId,
        cells: cells,
      );

      final result = validator.validate(
        specification: spec,
        matrix: matrix,
        definedObjectiveIds: objectives.map((o) => o.id).toList(),
      );

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    test('Total score mismatch triggers TOTAL_SCORE_MISMATCH error (Section 12, 17)', () {
      final spec = ExamSpecification(
        id: specId,
        projectId: projectId,
        title: 'Đề kiểm tra 15 phút',
        subject: 'Ngữ văn',
        grade: '9',
        durationMinutes: 15,
        totalScore: 10.0, // Expected 10.0
        questionCount: 5,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final cells = [
        const ExamMatrixCell(
          id: 'c1',
          specificationId: specId,
          objectiveId: 'obj_1',
          difficulty: QuestionDifficulty.nhanBiet,
          questionCount: 5,
          scorePerQuestion: 1.5, // 5 * 1.5 = 7.5 pts != 10.0
        ),
      ];

      final matrix = ExamMatrix(
        specificationId: specId,
        cells: cells,
      );

      final result = validator.validate(
        specification: spec,
        matrix: matrix,
        definedObjectiveIds: objectives.map((o) => o.id).toList(),
      );

      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('TOTAL_SCORE_MISMATCH')), isTrue);
    });

    test('Question count mismatch triggers QUESTION_COUNT_MISMATCH error (Section 17)', () {
      final spec = ExamSpecification(
        id: specId,
        projectId: projectId,
        title: 'Đề thi 45 phút',
        subject: 'Ngữ văn',
        grade: '9',
        durationMinutes: 45,
        totalScore: 10.0,
        questionCount: 10, // Spec requires 10
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final cells = [
        const ExamMatrixCell(
          id: 'c1',
          specificationId: specId,
          objectiveId: 'obj_1',
          difficulty: QuestionDifficulty.nhanBiet,
          questionCount: 5,
          scorePerQuestion: 2.0, // 5 * 2.0 = 10.0 pts (Score matches, but count is 5 != 10)
        ),
      ];

      final matrix = ExamMatrix(
        specificationId: specId,
        cells: cells,
      );

      final result = validator.validate(
        specification: spec,
        matrix: matrix,
        definedObjectiveIds: objectives.map((o) => o.id).toList(),
      );

      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('QUESTION_COUNT_MISMATCH')), isTrue);
    });

    test('Empty matrix cells triggers NO_OBJECTIVES error (Section 17)', () {
      final spec = ExamSpecification(
        id: specId,
        projectId: projectId,
        title: 'Đề thi',
        subject: 'Ngữ văn',
        grade: '9',
        durationMinutes: 45,
        totalScore: 10.0,
        questionCount: 10,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      const matrix = ExamMatrix(
        specificationId: specId,
        cells: [],
      );

      final result = validator.validate(
        specification: spec,
        matrix: matrix,
        definedObjectiveIds: objectives.map((o) => o.id).toList(),
      );

      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('NO_OBJECTIVES')), isTrue);
    });

    test('Uncovered objectives emit OBJECTIVE_NOT_COVERED warning (Section 17)', () {
      final spec = ExamSpecification(
        id: specId,
        projectId: projectId,
        title: 'Đề kiểm tra',
        subject: 'Ngữ văn',
        grade: '9',
        durationMinutes: 45,
        totalScore: 10.0,
        questionCount: 10,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Only covers obj_1; obj_2 and obj_3 are left uncovered
      final cells = [
        const ExamMatrixCell(
          id: 'c1',
          specificationId: specId,
          objectiveId: 'obj_1',
          difficulty: QuestionDifficulty.nhanBiet,
          questionCount: 10,
          scorePerQuestion: 1.0,
        ),
      ];

      final matrix = ExamMatrix(
        specificationId: specId,
        cells: cells,
      );

      final result = validator.validate(
        specification: spec,
        matrix: matrix,
        definedObjectiveIds: objectives.map((o) => o.id).toList(),
      );

      expect(result.isValid, isTrue); // Warnings do not block isValid
      expect(result.warnings.any((w) => w.contains('OBJECTIVE_NOT_COVERED')), isTrue);
    });
  });
}
