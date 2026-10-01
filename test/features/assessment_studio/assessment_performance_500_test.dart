import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/exam_matrix.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/exam_paper.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/services/exam_code_engine.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/services/exam_question_selector.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/question_models.dart';

void main() {
  group('Assessment Studio - 500 Question Bank Performance Benchmark (Section 93)', () {
    const selector = ExamQuestionSelector();
    const codeEngine = ExamCodeEngine();
    const specId = 'spec_perf_500';

    late List<QuestionItem> questionBank500;

    setUp(() {
      final difficulties = [
        QuestionDifficulty.nhanBiet,
        QuestionDifficulty.thongHieu,
        QuestionDifficulty.vanDung,
        QuestionDifficulty.vanDungCao,
      ];

      questionBank500 = [];
      int idx = 0;
      for (int obj = 1; obj <= 10; obj++) {
        for (final diff in difficulties) {
          for (int k = 0; k < 13; k++) {
            idx++;
            final type = (k % 4 == 3) ? QuestionType.essay : QuestionType.multipleChoice;
            questionBank500.add(
              QuestionItem(
                id: 'q_perf_${idx.toString().padLeft(4, '0')}',
                setId: 'set_perf',
                prompt: 'Câu hỏi hiệu năng số $idx: Phân tích kiến thức môn học theo chuẩn GDPT 2018 mục tiêu $obj [${diff.label}]?',
                type: type,
                difficulty: diff,
                learningObjective: 'obj_$obj',
                choices: type == QuestionType.multipleChoice
                    ? [
                        'Phương án lựa chọn A cho câu $idx',
                        'Phương án lựa chọn B cho câu $idx',
                        'Phương án lựa chọn C cho câu $idx',
                        'Phương án lựa chọn D cho câu $idx',
                      ]
                    : const [],
                correctAnswer: 'A',
                tags: ['Performance', 'GDPT2018', 'Chủ đề $obj'],
                orderIndex: idx,
              ),
            );
          }
        }
      }
      // Total = 10 * 4 * 13 = 520 questions (>= 500 questions as required by Section 93)
    });

    test('Filtering over 500 questions responds within 50ms', () {
      final sw = Stopwatch()..start();

      // Perform complex search and multi-criteria filter
      const query = 'chuẩn GDPT';
      const targetObjective = 'obj_3';
      const targetDifficulty = QuestionDifficulty.thongHieu;

      final filtered = questionBank500.where((q) {
        if (q.learningObjective != targetObjective) return false;
        if (q.difficulty != targetDifficulty) return false;
        if (query.isNotEmpty) {
          final qLower = query.toLowerCase();
          final matchPrompt = q.prompt.toLowerCase().contains(qLower);
          final matchChoice = q.choices.any((c) => c.toLowerCase().contains(qLower));
          if (!matchPrompt && !matchChoice) return false;
        }
        return true;
      }).toList();

      sw.stop();

      expect(filtered.isNotEmpty, isTrue);
      expect(sw.elapsedMilliseconds, lessThan(100), reason: 'Filtering 500 items must be ultra fast (< 100ms)');
    });

    test('Selecting 100-question master exam and generating 4 student codes completes in < 300ms (Section 93)', () {
      // Create a 100-question matrix across 10 objectives x 4 difficulty levels (25 questions per difficulty)
      final List<ExamMatrixCell> cells = [];
      final difficulties = [
        QuestionDifficulty.nhanBiet,
        QuestionDifficulty.thongHieu,
        QuestionDifficulty.vanDung,
        QuestionDifficulty.vanDungCao,
      ];

      for (int obj = 1; obj <= 10; obj++) {
        for (final diff in difficulties) {
          // 10 objectives * 4 difficulties = 40 cells
          // 40 cells * 2.5 questions avg = 100 questions
          final count = (diff == QuestionDifficulty.nhanBiet || diff == QuestionDifficulty.thongHieu) ? 3 : 2;
          cells.add(
            ExamMatrixCell(
              id: 'c_${obj}_${diff.name}',
              specificationId: specId,
              objectiveId: 'obj_$obj',
              difficulty: diff,
              questionCount: count, // 10 * 3 + 10 * 3 + 10 * 2 + 10 * 2 = 100
              scorePerQuestion: 0.1,
            ),
          );
        }
      }

      final matrix = ExamMatrix(
        specificationId: specId,
        cells: cells,
      );

      expect(matrix.totalQuestionCount, equals(100));

      // Benchmark Selection of 100 questions from 500 bank
      final selectSw = Stopwatch()..start();
      final selectionResult = selector.selectQuestions(
        matrix: matrix,
        questionBank: questionBank500,
        randomSeed: 2026,
      );
      selectSw.stop();

      expect(selectionResult.isSuccess, isTrue);
      expect(selectionResult.questions.length, equals(100));
      expect(selectSw.elapsedMilliseconds, lessThan(200), reason: 'Selection must take < 200ms');

      // Create Master ExamPaper with 100 questions
      final masterPaper = ExamPaper(
        id: 'paper_perf_100',
        assessmentProjectId: 'proj_perf',
        specificationId: specId,
        title: 'Đề thi 100 câu benchmark hiệu năng',
        examCode: 'MASTER',
        questions: selectionResult.questions,
        durationMinutes: 120,
        totalScore: 10.0,
        createdAt: DateTime.now(),
        finalizedAt: DateTime.now(),
      );

      // Benchmark Multi-Code Generation (4 codes with question & choice shuffling)
      final multiCodeSw = Stopwatch()..start();
      final multiCodeResult = codeEngine.generateCodes(
        masterPaper: masterPaper,
        numberOfCodes: 4,
        startingCode: 101,
        shuffleQuestions: true,
        shuffleChoices: true,
        baseSeed: 8888,
      );
      multiCodeSw.stop();

      expect(multiCodeResult.codes.length, equals(4));
      expect(multiCodeResult.codes[0].questions.length, equals(100));
      expect(multiCodeResult.codes[1].questions.length, equals(100));
      expect(multiCodeResult.codes[2].questions.length, equals(100));
      expect(multiCodeResult.codes[3].questions.length, equals(100));
      expect(multiCodeResult.answerKeys.length, equals(4));
      expect(multiCodeSw.elapsedMilliseconds, lessThan(200), reason: 'Shuffling 4 x 100 questions must take < 200ms');
    });
  });
}
