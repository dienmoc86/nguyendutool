import 'dart:math';
import 'package:nguyendu_tool/core/errors/app_exceptions.dart';
import '../../../teaching_suite/domain/models/question_models.dart';
import '../models/exam_answer_key.dart';
import '../models/exam_code.dart';
import '../models/exam_paper.dart';
import '../models/question_choice.dart';

/// Bundled result of generating multi-code exams (Section 32).
class ExamMultiCodeResult {
  final List<ExamCode> codes;
  final Map<String, ExamAnswerKey> answerKeys;

  const ExamMultiCodeResult({
    required this.codes,
    required this.answerKeys,
  });
}

/// Shuffling and deterministic answer remapping engine (Sections 33, 34, 35, 73, 85).
class ExamCodeEngine {
  const ExamCodeEngine();

  ExamMultiCodeResult generateCodes({
    required ExamPaper masterPaper,
    int numberOfCodes = 4,
    int startingCode = 101,
    bool shuffleQuestions = true,
    bool shuffleChoices = true,
    int? baseSeed,
  }) {
    final List<ExamCode> generatedCodes = [];
    final Map<String, ExamAnswerKey> answerKeys = {};

    for (int i = 0; i < numberOfCodes; i++) {
      final codeInt = startingCode + i;
      final codeStr = codeInt.toString();
      final canonicalExamCodeId = 'ec_${masterPaper.id}_$codeStr';
      final codeSeed = (baseSeed ?? 4242) + (i * 317);
      final Random rng = Random(codeSeed);

      // Separate questions by section:
      // Section 0 = MCQ, Section 1 = Short Answer / True False, Section 2 = Essay
      final mcqQuestions = masterPaper.questions.where((q) => q.sectionIndex == 0).toList();
      final shortAnswerQuestions = masterPaper.questions.where((q) => q.sectionIndex == 1).toList();
      final essayQuestions = masterPaper.questions.where((q) => q.sectionIndex == 2).toList();

      if (shuffleQuestions) {
        mcqQuestions.shuffle(rng);
        shortAnswerQuestions.shuffle(rng);
        // Essay questions remain in fixed pedagogical sequence (Section 33)
      }

      final orderedSnapshots = [...mcqQuestions, ...shortAnswerQuestions, ...essayQuestions];
      final List<ExamCodeQuestion> codeQuestions = [];
      final List<ExamAnswerKeyItem> keyItems = [];

      for (int qIdx = 0; qIdx < orderedSnapshots.length; qIdx++) {
        final snap = orderedSnapshots[qIdx];
        final orderNumber = qIdx + 1;
        List<String> choiceOrder = [];
        String correctDisplayAnswer = snap.correctAnswerText;

        if (snap.type == QuestionType.multipleChoice && snap.choices.isNotEmpty) {
          if (shuffleChoices) {
            // Shuffle choices deterministically
            final shuffled = List<QuestionChoice>.from(snap.choices)..shuffle(rng);
            choiceOrder = shuffled.map((c) => c.id).toList();

            // Find new index of the stable correct choice ID
            final newIdx = shuffled.indexWhere((c) => c.id == snap.correctChoiceId);
            if (newIdx >= 0) {
              correctDisplayAnswer = QuestionChoice.indexToLetter(newIdx);
            } else {
              throw InvalidExamQuestionException(
                'Lỗi xáo trộn đáp án: Không tìm thấy ID đáp án đúng "${snap.correctChoiceId}" trong danh sách lựa chọn cho câu ${snap.questionId}.',
                questionId: snap.questionId,
              );
            }
          } else {
            choiceOrder = snap.choices.map((c) => c.id).toList();
            final idx = snap.choices.indexWhere((c) => c.id == snap.correctChoiceId);
            if (idx >= 0) {
              correctDisplayAnswer = QuestionChoice.indexToLetter(idx);
            } else {
              throw InvalidExamQuestionException(
                'Không tìm thấy ID đáp án đúng "${snap.correctChoiceId}" trong các phương án của câu ${snap.questionId}.',
                questionId: snap.questionId,
              );
            }
          }
        }

        final codeQuestionId = 'ecq_${canonicalExamCodeId}_$orderNumber';
        final codeQuestion = ExamCodeQuestion(
          id: codeQuestionId,
          examCodeId: canonicalExamCodeId,
          questionId: snap.questionId,
          orderIndex: qIdx,
          score: snap.score,
          correctDisplayAnswer: correctDisplayAnswer,
          choiceOrder: choiceOrder,
          snapshot: snap,
        );
        codeQuestions.add(codeQuestion);

        // Generate Answer Key Item
        final snippet = snap.prompt.length > 60
            ? '${snap.prompt.substring(0, 60)}...'
            : snap.prompt;

        keyItems.add(
          ExamAnswerKeyItem(
            questionNumber: orderNumber,
            correctDisplayAnswer: correctDisplayAnswer,
            score: snap.score,
            questionId: snap.questionId,
            promptSnippet: snippet,
            explanation: snap.explanation,
            type: snap.type,
          ),
        );
      }

      final examCode = ExamCode(
        id: canonicalExamCodeId,
        examPaperId: masterPaper.id,
        code: codeStr,
        questions: codeQuestions,
        createdAt: DateTime.now(),
      );

      generatedCodes.add(examCode);
      answerKeys[codeStr] = ExamAnswerKey(
        examCode: codeStr,
        items: keyItems,
      );
    }

    return ExamMultiCodeResult(
      codes: generatedCodes,
      answerKeys: answerKeys,
    );
  }
}
