import '../../../teaching_suite/domain/models/question_models.dart';

/// Single question answer item for an exam code (Section 37).
class ExamAnswerKeyItem {
  final int questionNumber;
  final String correctDisplayAnswer;
  final double score;
  final String questionId;
  final String promptSnippet;
  final String? explanation;
  final QuestionType type;

  const ExamAnswerKeyItem({
    required this.questionNumber,
    required this.correctDisplayAnswer,
    required this.score,
    required this.questionId,
    required this.promptSnippet,
    this.explanation,
    this.type = QuestionType.multipleChoice,
  });

  Map<String, dynamic> toMap() => {
        'question_number': questionNumber,
        'correct_display_answer': correctDisplayAnswer,
        'score': score,
        'question_id': questionId,
        'prompt_snippet': promptSnippet,
        'explanation': explanation,
        'type': type.name,
      };

  factory ExamAnswerKeyItem.fromMap(Map<String, dynamic> map) => ExamAnswerKeyItem(
        questionNumber: (map['question_number'] as num?)?.toInt() ?? 1,
        correctDisplayAnswer: (map['correct_display_answer'] as String?) ?? '',
        score: (map['score'] as num?)?.toDouble() ?? 1.0,
        questionId: (map['question_id'] as String?) ?? '',
        promptSnippet: (map['prompt_snippet'] as String?) ?? '',
        explanation: map['explanation'] as String?,
        type: QuestionType.fromString(map['type'] as String?),
      );
}

/// Answer key for a specific exam code (Section 37).
class ExamAnswerKey {
  final String examCode;
  final List<ExamAnswerKeyItem> items;

  const ExamAnswerKey({
    required this.examCode,
    this.items = const [],
  });

  double get totalScore => items.fold(0.0, (sum, i) => sum + i.score);

  Map<String, dynamic> toMap() => {
        'exam_code': examCode,
        'items': items.map((i) => i.toMap()).toList(),
      };

  factory ExamAnswerKey.fromMap(Map<String, dynamic> map) => ExamAnswerKey(
        examCode: (map['exam_code'] as String?) ?? '',
        items: (map['items'] as List<dynamic>?)
                ?.map((e) => ExamAnswerKeyItem.fromMap(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}
