import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/exam_paper.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/exam_question_snapshot.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/question_choice.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/services/exam_code_engine.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/validation/exam_code_verifier.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/question_models.dart';

void main() {
  group('Assessment Studio - Multi-Code, Shuffling & Answer Remapping Tests (Sections 84, 85)', () {
    const engine = ExamCodeEngine();
    const verifier = ExamCodeVerifier();

    test('Section 85 Choice Remap Rule: Master [A: One, B: Two, C: Three, D: Four] with correct B remapped when shuffled', () {
      // 1. Create choices with stable IDs
      const cA = QuestionChoice(id: 'c_one', text: 'One');
      const cB = QuestionChoice(id: 'c_two', text: 'Two');
      const cC = QuestionChoice(id: 'c_three', text: 'Three');
      const cD = QuestionChoice(id: 'c_four', text: 'Four');

      // Master snapshot: Correct is B ("Two" -> id: 'c_two')
      const masterSnapshot = ExamQuestionSnapshot(
        questionId: 'q_section_85',
        prompt: 'Đếm số lượng:',
        choices: [cA, cB, cC, cD],
        correctChoiceId: 'c_two',
        correctAnswerText: 'B',
        type: QuestionType.multipleChoice,
        difficulty: QuestionDifficulty.nhanBiet,
        score: 1.0,
      );

      // Section 85 Specific target shuffle order:
      // A. Four ('c_four')
      // B. One ('c_one')
      // C. Two ('c_two')  <-- Target correct answer!
      // D. Three ('c_three')
      final shuffledChoices = [cD, cA, cB, cC];

      // Re-map the correct letter based on stable correctChoiceId ('c_two')
      final newIndex = shuffledChoices.indexWhere((c) => c.id == masterSnapshot.correctChoiceId);
      final newDisplayAnswer = QuestionChoice.indexToLetter(newIndex);

      expect(newIndex, equals(2)); // 0 = A, 1 = B, 2 = C, 3 = D
      expect(newDisplayAnswer, equals('C')); // Exactly as required by Section 85!
    });

    test('Multi-Code generation generates 4 valid codes (101 to 104) and answer keys (Section 32, 37)', () {
      final questions = List.generate(8, (i) {
        final choices = [
          QuestionChoice(id: 'c_${i}_1', text: 'Lựa chọn 1'),
          QuestionChoice(id: 'c_${i}_2', text: 'Lựa chọn 2'),
          QuestionChoice(id: 'c_${i}_3', text: 'Lựa chọn 3'),
          QuestionChoice(id: 'c_${i}_4', text: 'Lựa chọn 4'),
        ];
        return ExamQuestionSnapshot(
          questionId: 'q_$i',
          prompt: 'Câu hỏi số $i',
          choices: choices,
          correctChoiceId: 'c_${i}_2', // Choice 2 is correct
          correctAnswerText: 'B',
          type: QuestionType.multipleChoice,
          difficulty: i < 4 ? QuestionDifficulty.nhanBiet : QuestionDifficulty.thongHieu,
          objectiveId: i < 4 ? 'obj_1' : 'obj_2',
          score: 1.25,
          sectionIndex: 0, // MCQ section
        );
      });

      // Add 2 essay questions (sectionIndex: 2)
      questions.addAll([
        const ExamQuestionSnapshot(
          questionId: 'q_essay_1',
          prompt: 'Câu tự luận 1: Phân tích bài thơ...',
          choices: [],
          correctChoiceId: '',
          correctAnswerText: 'Dàn ý tự luận 1',
          type: QuestionType.essay,
          difficulty: QuestionDifficulty.vanDung,
          objectiveId: 'obj_1',
          score: 2.0,
          sectionIndex: 2, // Essay section
        ),
        const ExamQuestionSnapshot(
          questionId: 'q_essay_2',
          prompt: 'Câu tự luận 2: Viết bài văn nghị luận...',
          choices: [],
          correctChoiceId: '',
          correctAnswerText: 'Dàn ý tự luận 2',
          type: QuestionType.essay,
          difficulty: QuestionDifficulty.vanDungCao,
          objectiveId: 'obj_2',
          score: 3.0,
          sectionIndex: 2, // Essay section
        ),
      ]);

      final masterPaper = ExamPaper(
        id: 'paper_test_master',
        assessmentProjectId: 'proj_test_multi',
        specificationId: 'spec_01',
        title: 'Đề thi gốc mẫu',
        examCode: 'MASTER',
        questions: questions,
        durationMinutes: 90,
        totalScore: 15.0, // (8 * 1.25) + 2.0 + 3.0 = 10.0 + 5.0 = 15.0
        createdAt: DateTime.now(),
        finalizedAt: DateTime.now(),
      );

      final result = engine.generateCodes(
        masterPaper: masterPaper,
        numberOfCodes: 4,
        startingCode: 101,
        shuffleQuestions: true,
        shuffleChoices: true,
        baseSeed: 12345,
      );

      expect(result.codes.length, equals(4));
      expect(result.codes.map((c) => c.code).toList(), equals(['101', '102', '103', '104']));
      expect(result.answerKeys.length, equals(4));

      // Verify that each answer key has 10 items
      for (final code in result.codes) {
        final key = result.answerKeys[code.code]!;
        expect(key.items.length, equals(10));
        expect(key.totalScore, equals(15.0));

        // Essay questions should remain at the end in original relative order (Section 33)
        final q9 = code.questions[8];
        final q10 = code.questions[9];
        expect(q9.questionId, equals('q_essay_1'));
        expect(q10.questionId, equals('q_essay_2'));
      }

      // Verify cross-code equivalence (Section 38, 39, 84)
      final verification = verifier.verifyCodes(result.codes);
      expect(verification.isEquivalent, isTrue);
      expect(verification.mismatches, isEmpty);
    });
  });
}
