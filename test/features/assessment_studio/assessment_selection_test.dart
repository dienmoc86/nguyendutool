import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/exam_matrix.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/services/exam_question_selector.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/question_models.dart';

void main() {
  group('Assessment Studio - Question Selection & Bank Shortage Tests (Section 83)', () {
    const String specId = 'spec_selection_test';
    const selector = ExamQuestionSelector();

    List<QuestionItem> createSyntheticBank({
      required String objectiveId,
      required QuestionDifficulty difficulty,
      required int count,
      String prefix = 'q',
    }) {
      return List.generate(count, (i) {
        return QuestionItem(
          id: '${prefix}_${objectiveId}_${difficulty.name}_$i',
          setId: 'set_synthetic',
          prompt: 'Câu hỏi kiểm tra số $i cho $objectiveId [${difficulty.label}]',
          type: QuestionType.multipleChoice,
          difficulty: difficulty,
          learningObjective: objectiveId,
          choices: const ['Phương án A', 'Phương án B', 'Phương án C', 'Phương án D'],
          correctAnswer: 'A',
          orderIndex: i,
        );
      });
    }

    test('Exact matrix fulfillment succeeds without duplicates (Section 26, 83)', () {
      const matrix = ExamMatrix(
        specificationId: specId,
        cells: [
          ExamMatrixCell(
            id: 'c1',
            specificationId: specId,
            objectiveId: 'obj_1',
            difficulty: QuestionDifficulty.nhanBiet,
            questionCount: 3,
            scorePerQuestion: 0.5,
          ),
          ExamMatrixCell(
            id: 'c2',
            specificationId: specId,
            objectiveId: 'obj_1',
            difficulty: QuestionDifficulty.thongHieu,
            questionCount: 2,
            scorePerQuestion: 1.0,
          ),
          ExamMatrixCell(
            id: 'c3',
            specificationId: specId,
            objectiveId: 'obj_2',
            difficulty: QuestionDifficulty.vanDung,
            questionCount: 2,
            scorePerQuestion: 1.5,
          ),
        ],
      );

      // Create ample bank
      final bank = [
        ...createSyntheticBank(objectiveId: 'obj_1', difficulty: QuestionDifficulty.nhanBiet, count: 5),
        ...createSyntheticBank(objectiveId: 'obj_1', difficulty: QuestionDifficulty.thongHieu, count: 5),
        ...createSyntheticBank(objectiveId: 'obj_2', difficulty: QuestionDifficulty.vanDung, count: 5),
      ];

      final result = selector.selectQuestions(
        matrix: matrix,
        questionBank: bank,
        randomSeed: 42,
      );

      expect(result.isSuccess, isTrue);
      expect(result.questions.length, equals(7)); // 3 + 2 + 2 = 7

      // Verify no duplicate questions
      final selectedIds = result.questions.map((q) => q.sourceQuestionId).toSet();
      expect(selectedIds.length, equals(7));

      // Verify scores match matrix cells
      final nhanBietSnapshots = result.questions.where((q) => q.difficulty == QuestionDifficulty.nhanBiet).toList();
      expect(nhanBietSnapshots.length, equals(3));
      for (final s in nhanBietSnapshots) {
        expect(s.score, equals(0.5));
      }

      final vanDungSnapshots = result.questions.where((q) => q.difficulty == QuestionDifficulty.vanDung).toList();
      expect(vanDungSnapshots.length, equals(2));
      for (final s in vanDungSnapshots) {
        expect(s.score, equals(1.5));
      }
    });

    test('Insufficient bank returns failure with exact deficit report (Section 27, 83)', () {
      const matrix = ExamMatrix(
        specificationId: specId,
        cells: [
          ExamMatrixCell(
            id: 'c1',
            specificationId: specId,
            objectiveId: 'obj_3',
            difficulty: QuestionDifficulty.vanDung,
            questionCount: 5, // Requires 5
            scorePerQuestion: 1.0,
          ),
        ],
      );

      // Bank only contains 2 questions for obj_3 / vanDung
      final bank = createSyntheticBank(
        objectiveId: 'obj_3',
        difficulty: QuestionDifficulty.vanDung,
        count: 2,
      );

      final result = selector.selectQuestions(
        matrix: matrix,
        questionBank: bank,
      );

      expect(result.isSuccess, isFalse);
      expect(result.shortages.length, equals(1));

      final shortage = result.shortages.first;
      expect(shortage.objectiveId, equals('obj_3'));
      expect(shortage.difficulty, equals(QuestionDifficulty.vanDung));
      expect(shortage.requiredCount, equals(5));
      expect(shortage.availableCount, equals(2));
      expect(shortage.deficit, equals(3)); // 5 - 2 = 3
    });

    test('Deterministic question selection with identical seed produces same results (Section 28, 83)', () {
      const matrix = ExamMatrix(
        specificationId: specId,
        cells: [
          ExamMatrixCell(
            id: 'c1',
            specificationId: specId,
            objectiveId: 'obj_A',
            difficulty: QuestionDifficulty.nhanBiet,
            questionCount: 4,
            scorePerQuestion: 0.5,
          ),
        ],
      );

      final bank = createSyntheticBank(
        objectiveId: 'obj_A',
        difficulty: QuestionDifficulty.nhanBiet,
        count: 20,
      );

      const seed = 9999;
      final run1 = selector.selectQuestions(matrix: matrix, questionBank: bank, randomSeed: seed);
      final run2 = selector.selectQuestions(matrix: matrix, questionBank: bank, randomSeed: seed);

      expect(run1.isSuccess, isTrue);
      expect(run2.isSuccess, isTrue);

      final run1Ids = run1.questions.map((q) => q.sourceQuestionId).toList();
      final run2Ids = run2.questions.map((q) => q.sourceQuestionId).toList();

      expect(run1Ids, equals(run2Ids));
    });
  });
}
