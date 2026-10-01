import 'dart:convert';
import 'package:nguyendu_tool/core/errors/app_exceptions.dart';
import '../../../teaching_suite/domain/models/question_models.dart';
import 'question_choice.dart';

/// Immutable snapshot of a question when finalized into an ExamPaper (Sections 8, 20, 86).
/// Guarantees that alterations in the Question Bank will never mutate an existing exam.
class ExamQuestionSnapshot {
  final String questionId;
  String get sourceQuestionId => questionId;
  final String prompt;
  final List<QuestionChoice> choices;
  final String correctChoiceId;
  final String correctAnswerText;
  final QuestionType type;
  final QuestionDifficulty difficulty;
  final String? objectiveId;
  final double score;
  final String? explanation;
  final int sectionIndex;
  final List<String> tags;

  const ExamQuestionSnapshot({
    required this.questionId,
    required this.prompt,
    this.choices = const [],
    required this.correctChoiceId,
    required this.correctAnswerText,
    this.type = QuestionType.multipleChoice,
    this.difficulty = QuestionDifficulty.nhanBiet,
    this.objectiveId,
    this.score = 1.0,
    this.explanation,
    this.sectionIndex = 0,
    this.tags = const [],
  });

  /// Creates a frozen snapshot from a live QuestionItem.
  factory ExamQuestionSnapshot.fromQuestionItem(
    QuestionItem item, {
    double score = 1.0,
    int sectionIndex = 0,
  }) {
    final choices = QuestionChoice.fromStrings(item.choices);
    String correctChoiceId = '';
    final normalized = item.correctAnswer.trim().toUpperCase();

    if (item.type == QuestionType.multipleChoice) {
      if (choices.length != 4) {
        throw InvalidExamQuestionException(
          'Câu hỏi trắc nghiệm ${item.id} phải có đúng 4 phương án lựa chọn (hiện có ${choices.length}).',
          questionId: item.id,
        );
      }
      if (normalized.isEmpty) {
        throw InvalidExamQuestionException(
          'Câu hỏi trắc nghiệm ${item.id} không có đáp án đúng.',
          questionId: item.id,
        );
      }

      if (normalized == 'A' || normalized == 'B' || normalized == 'C' || normalized == 'D') {
        final idx = QuestionChoice.letterToIndex(normalized);
        if (idx >= 0 && idx < choices.length) {
          correctChoiceId = choices[idx].id;
        } else {
          throw InvalidExamQuestionException(
            'Chỉ số đáp án $normalized không hợp lệ đối với câu hỏi ${item.id}.',
            questionId: item.id,
          );
        }
      } else {
        // Find matching choice text
        final cleanAns = normalized.replaceFirst(RegExp(r'^[A-D][\.\:\)]\s*'), '').trim().toLowerCase();
        final matchingIndices = <int>[];
        for (int i = 0; i < choices.length; i++) {
          if (choices[i].text.trim().toLowerCase() == cleanAns) {
            matchingIndices.add(i);
          }
        }

        if (matchingIndices.isEmpty) {
          throw InvalidExamQuestionException(
            'Không tìm thấy phương án nào khớp với đáp án "${item.correctAnswer}" trong câu hỏi ${item.id}.',
            questionId: item.id,
          );
        } else if (matchingIndices.length > 1) {
          throw InvalidExamQuestionException(
            'Đáp án "${item.correctAnswer}" trong câu hỏi ${item.id} trùng lặp với nhiều phương án lựa chọn, gây mơ hồ.',
            questionId: item.id,
          );
        } else {
          correctChoiceId = choices[matchingIndices.first].id;
        }
      }

      if (correctChoiceId.isEmpty) {
        throw InvalidExamQuestionException(
          'Không thể xác định đáp án đúng hợp lệ cho câu hỏi trắc nghiệm ${item.id}.',
          questionId: item.id,
        );
      }
    } else {
      // Non-MCQ: Short answer, True/False, Essay
      if (choices.isNotEmpty) {
        if (normalized == 'A' || normalized == 'B' || normalized == 'C' || normalized == 'D') {
          final idx = QuestionChoice.letterToIndex(normalized);
          if (idx >= 0 && idx < choices.length) {
            correctChoiceId = choices[idx].id;
          }
        } else {
          final cleanAns = normalized.replaceFirst(RegExp(r'^[A-D][\.\:\)]\s*'), '').trim().toLowerCase();
          final matchIdx = choices.indexWhere((c) => c.text.trim().toLowerCase() == cleanAns);
          if (matchIdx >= 0) {
            correctChoiceId = choices[matchIdx].id;
          }
        }
      }
    }

    return ExamQuestionSnapshot(
      questionId: item.id,
      prompt: item.prompt,
      choices: choices,
      correctChoiceId: correctChoiceId,
      correctAnswerText: item.correctAnswer,
      type: item.type,
      difficulty: item.difficulty,
      objectiveId: item.learningObjective,
      score: score,
      explanation: item.explanation,
      sectionIndex: sectionIndex,
      tags: item.tags,
    );
  }

  ExamQuestionSnapshot copyWith({
    String? questionId,
    String? prompt,
    List<QuestionChoice>? choices,
    String? correctChoiceId,
    String? correctAnswerText,
    QuestionType? type,
    QuestionDifficulty? difficulty,
    String? objectiveId,
    double? score,
    String? explanation,
    int? sectionIndex,
    List<String>? tags,
  }) {
    return ExamQuestionSnapshot(
      questionId: questionId ?? this.questionId,
      prompt: prompt ?? this.prompt,
      choices: choices ?? this.choices,
      correctChoiceId: correctChoiceId ?? this.correctChoiceId,
      correctAnswerText: correctAnswerText ?? this.correctAnswerText,
      type: type ?? this.type,
      difficulty: difficulty ?? this.difficulty,
      objectiveId: objectiveId ?? this.objectiveId,
      score: score ?? this.score,
      explanation: explanation ?? this.explanation,
      sectionIndex: sectionIndex ?? this.sectionIndex,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toMap() => {
        'question_id': questionId,
        'prompt': prompt,
        'choices': choices.map((c) => c.toMap()).toList(),
        'correct_choice_id': correctChoiceId,
        'correct_answer_text': correctAnswerText,
        'type': type.name,
        'difficulty': difficulty.name,
        'objective_id': objectiveId,
        'score': score,
        'explanation': explanation,
        'section_index': sectionIndex,
        'tags': tags,
      };

  factory ExamQuestionSnapshot.fromMap(Map<String, dynamic> map) {
    List<QuestionChoice> parsedChoices = [];
    if (map['choices'] is List) {
      parsedChoices = (map['choices'] as List)
          .map((c) => QuestionChoice.fromMap(c as Map<String, dynamic>))
          .toList();
    }

    List<String> parsedTags = [];
    if (map['tags'] is List) {
      parsedTags = (map['tags'] as List).map((t) => t.toString()).toList();
    }

    return ExamQuestionSnapshot(
      questionId: (map['question_id'] as String?) ?? '',
      prompt: (map['prompt'] as String?) ?? '',
      choices: parsedChoices,
      correctChoiceId: (map['correct_choice_id'] as String?) ?? '',
      correctAnswerText: (map['correct_answer_text'] as String?) ?? '',
      type: QuestionType.fromString(map['type'] as String?),
      difficulty: QuestionDifficulty.fromString(map['difficulty'] as String?),
      objectiveId: map['objective_id'] as String?,
      score: (map['score'] as num?)?.toDouble() ?? 1.0,
      explanation: map['explanation'] as String?,
      sectionIndex: (map['section_index'] as num?)?.toInt() ?? 0,
      tags: parsedTags,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory ExamQuestionSnapshot.fromJson(String source) =>
      ExamQuestionSnapshot.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
