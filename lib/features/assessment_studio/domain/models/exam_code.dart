import 'dart:convert';
import 'exam_question_snapshot.dart';
import 'question_choice.dart';

/// Represents a single question inside a student exam code (Sections 33, 34, 35).
class ExamCodeQuestion {
  final String id;
  final String examCodeId;
  final String questionId;
  final int orderIndex;
  final double score;
  final String correctDisplayAnswer;
  final List<String> choiceOrder; // Choice IDs in shuffled order
  final ExamQuestionSnapshot snapshot;

  const ExamCodeQuestion({
    required this.id,
    required this.examCodeId,
    required this.questionId,
    required this.orderIndex,
    required this.score,
    required this.correctDisplayAnswer,
    this.choiceOrder = const [],
    required this.snapshot,
  });

  /// Returns choices rendered in the shuffled order for this code
  List<QuestionChoice> get orderedChoices {
    if (choiceOrder.isEmpty) return snapshot.choices;
    final List<QuestionChoice> result = [];
    for (final cid in choiceOrder) {
      final choice = snapshot.choices.firstWhere(
        (c) => c.id == cid,
        orElse: () => QuestionChoice(id: cid, text: ''),
      );
      result.add(choice);
    }
    return result;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'exam_code_id': examCodeId,
        'question_id': questionId,
        'order_index': orderIndex,
        'score': score,
        'correct_display_answer': correctDisplayAnswer,
        'choice_order_json': jsonEncode(choiceOrder),
        'snapshot_json': snapshot.toJson(),
      };

  factory ExamCodeQuestion.fromMap(Map<String, dynamic> map) {
    List<String> parsedOrder = [];
    if (map['choice_order_json'] is String) {
      try {
        final decoded = jsonDecode(map['choice_order_json'] as String);
        if (decoded is List) {
          parsedOrder = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    } else if (map['choiceOrder'] is List) {
      parsedOrder = (map['choiceOrder'] as List).map((e) => e.toString()).toList();
    }

    ExamQuestionSnapshot snap;
    if (map['snapshot'] is ExamQuestionSnapshot) {
      snap = map['snapshot'] as ExamQuestionSnapshot;
    } else if (map['snapshot_json'] is String) {
      snap = ExamQuestionSnapshot.fromJson(map['snapshot_json'] as String);
    } else if (map['snapshot'] is Map<String, dynamic>) {
      snap = ExamQuestionSnapshot.fromMap(map['snapshot'] as Map<String, dynamic>);
    } else {
      snap = ExamQuestionSnapshot(
        questionId: (map['question_id'] as String?) ?? '',
        prompt: '',
        correctChoiceId: '',
        correctAnswerText: '',
      );
    }

    return ExamCodeQuestion(
      id: (map['id'] as String?) ?? '',
      examCodeId: (map['exam_code_id'] ?? map['examCodeId']) as String? ?? '',
      questionId: (map['question_id'] ?? map['questionId']) as String? ?? '',
      orderIndex: (map['order_index'] ?? map['orderIndex'] as num?)?.toInt() ?? 0,
      score: (map['score'] as num?)?.toDouble() ?? 1.0,
      correctDisplayAnswer: (map['correct_display_answer'] ?? map['correctDisplayAnswer']) as String? ?? '',
      choiceOrder: parsedOrder,
      snapshot: snap,
    );
  }
}

/// A specific student exam code (e.g. 101, 102, 103, 104) (Section 32).
class ExamCode {
  final String id;
  final String examPaperId;
  final String code;
  final List<ExamCodeQuestion> questions;
  final DateTime createdAt;

  const ExamCode({
    required this.id,
    required this.examPaperId,
    required this.code,
    this.questions = const [],
    required this.createdAt,
  });

  double get totalScore => questions.fold(0.0, (sum, q) => sum + q.score);

  int get questionCount => questions.length;

  ExamCode copyWith({
    String? id,
    String? examPaperId,
    String? code,
    List<ExamCodeQuestion>? questions,
    DateTime? createdAt,
  }) {
    return ExamCode(
      id: id ?? this.id,
      examPaperId: examPaperId ?? this.examPaperId,
      code: code ?? this.code,
      questions: questions ?? this.questions,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'exam_paper_id': examPaperId,
        'code': code,
        'created_at': createdAt.toIso8601String(),
        'questions': questions.map((q) => q.toMap()).toList(),
      };

  factory ExamCode.fromMap(Map<String, dynamic> map, {List<ExamCodeQuestion> questions = const []}) {
    List<ExamCodeQuestion> parsedQuestions = questions;
    if (parsedQuestions.isEmpty && map['questions'] is List) {
      parsedQuestions = (map['questions'] as List)
          .map((q) => ExamCodeQuestion.fromMap(q as Map<String, dynamic>))
          .toList();
    }

    return ExamCode(
      id: (map['id'] as String?) ?? '',
      examPaperId: (map['exam_paper_id'] ?? map['examPaperId']) as String? ?? '',
      code: (map['code'] as String?) ?? '',
      questions: parsedQuestions,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory ExamCode.fromJson(String source) =>
      ExamCode.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
