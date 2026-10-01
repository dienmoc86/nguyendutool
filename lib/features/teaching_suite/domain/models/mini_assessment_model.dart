import 'dart:convert';
import 'question_models.dart';

/// Configuration for building a quick mini-assessment from a question bank.
class MiniAssessmentConfig {
  final String title;
  final int durationMinutes;
  final int totalQuestions;
  final Set<QuestionType> allowedTypes;
  final Set<QuestionDifficulty> allowedDifficulties;
  final bool shuffleQuestions;
  final bool includeAnswers;

  const MiniAssessmentConfig({
    required this.title,
    this.durationMinutes = 15,
    this.totalQuestions = 10,
    this.allowedTypes = const {
      QuestionType.multipleChoice,
      QuestionType.trueFalse,
      QuestionType.shortAnswer,
    },
    this.allowedDifficulties = const {
      QuestionDifficulty.nhanBiet,
      QuestionDifficulty.thongHieu,
      QuestionDifficulty.vanDung,
    },
    this.shuffleQuestions = false,
    this.includeAnswers = true,
  });
}

/// Structured persistent mini assessment entity.
class MiniAssessment {
  final String id;
  final String projectId;
  final String? sourceQuestionSetId;
  final String title;
  final int durationMinutes;
  final List<QuestionItem> questions;
  final List<String> questionOrder;
  final DateTime createdAt;

  MiniAssessment({
    required this.id,
    required this.projectId,
    this.sourceQuestionSetId,
    required this.title,
    this.durationMinutes = 15,
    this.questions = const [],
    List<String>? questionOrder,
    List<String>? questionIds,
    DateTime? createdAt,
  })  : questionOrder = questionOrder ?? questionIds ?? questions.map((q) => q.id).toList(),
        createdAt = createdAt ?? DateTime.now();

  List<String> get questionIds => questionOrder;

  Map<int, String> get deterministicAnswerKey => toResult().deterministicAnswerKey;

  MiniAssessmentResult toResult() => MiniAssessmentResult.fromQuestions(
        title: title,
        durationMinutes: durationMinutes,
        questions: questions,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'source_question_set_id': sourceQuestionSetId,
        'title': title,
        'duration': durationMinutes,
        'questions': questions.map((q) => q.toMap()).toList(),
        'question_order': questionOrder,
        'created_at': createdAt.toIso8601String(),
      };

  factory MiniAssessment.fromMap(
    Map<String, dynamic> map, {
    List<QuestionItem>? questions,
    List<String>? questionOrder,
  }) {
    final qList = questions ??
        ((map['questions'] as List<dynamic>?)
            ?.map((e) => QuestionItem.fromMap(e as Map<String, dynamic>))
            .toList() ??
            const <QuestionItem>[]);

    final order = questionOrder ??
        (map['question_order'] as List<dynamic>?)?.map((e) => e.toString()).toList();

    return MiniAssessment(
      id: (map['id'] as String?) ?? '',
      projectId: (map['project_id'] as String?) ?? '',
      sourceQuestionSetId: map['source_question_set_id'] as String?,
      title: (map['title'] as String?) ?? '',
      durationMinutes: (map['duration'] as num?)?.toInt() ?? 15,
      questions: qList,
      questionOrder: order,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory MiniAssessment.fromJson(String source) =>
      MiniAssessment.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

/// Generated mini assessment containing test sheet questions and deterministic answer key.
class MiniAssessmentResult {
  final String title;
  final int durationMinutes;
  final List<QuestionItem> questions;
  final Map<int, String> deterministicAnswerKey; // 1-based question number -> Answer string

  const MiniAssessmentResult({
    required this.title,
    required this.durationMinutes,
    required this.questions,
    required this.deterministicAnswerKey,
  });

  /// Deterministically creates answer key map from question items without requiring AI
  factory MiniAssessmentResult.fromQuestions({
    required String title,
    required int durationMinutes,
    required List<QuestionItem> questions,
  }) {
    final Map<int, String> answers = {};
    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      final qNum = i + 1;
      String ans = q.correctAnswer;
      if (q.explanation != null && q.explanation!.trim().isNotEmpty) {
        ans += ' (Giải thích: ${q.explanation!.trim()})';
      }
      answers[qNum] = ans;
    }

    return MiniAssessmentResult(
      title: title,
      durationMinutes: durationMinutes,
      questions: questions,
      deterministicAnswerKey: answers,
    );
  }
}
