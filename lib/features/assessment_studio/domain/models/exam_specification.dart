import 'dart:convert';
import '../../../teaching_suite/domain/models/question_models.dart';

/// Specification and blueprint requirements for an assessment (Section 9).
class ExamSpecification {
  final String id;
  final String projectId;
  final String title;
  final String subject;
  final String grade;
  final int durationMinutes;
  final double totalScore;
  final int questionCount;
  final String? instructions;
  final List<QuestionType> allowedQuestionTypes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExamSpecification({
    required this.id,
    required this.projectId,
    required this.title,
    this.subject = 'Ngữ văn',
    this.grade = '9',
    this.durationMinutes = 45,
    this.totalScore = 10.0,
    this.questionCount = 10,
    this.instructions,
    this.allowedQuestionTypes = const [
      QuestionType.multipleChoice,
      QuestionType.trueFalse,
      QuestionType.shortAnswer,
      QuestionType.essay,
    ],
    required this.createdAt,
    required this.updatedAt,
  });

  ExamSpecification copyWith({
    String? id,
    String? projectId,
    String? title,
    String? subject,
    String? grade,
    int? durationMinutes,
    double? totalScore,
    int? questionCount,
    String? instructions,
    List<QuestionType>? allowedQuestionTypes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExamSpecification(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      grade: grade ?? this.grade,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      totalScore: totalScore ?? this.totalScore,
      questionCount: questionCount ?? this.questionCount,
      instructions: instructions ?? this.instructions,
      allowedQuestionTypes: allowedQuestionTypes ?? this.allowedQuestionTypes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'title': title,
        'subject': subject,
        'grade': grade,
        'duration_minutes': durationMinutes,
        'total_score': totalScore,
        'question_count': questionCount,
        'instructions': instructions,
        'allowed_question_types_json': jsonEncode(
          allowedQuestionTypes.map((t) => t.name).toList(),
        ),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory ExamSpecification.fromMap(Map<String, dynamic> map) {
    List<QuestionType> parsedTypes = [
      QuestionType.multipleChoice,
      QuestionType.trueFalse,
      QuestionType.shortAnswer,
      QuestionType.essay,
    ];

    if (map['allowed_question_types_json'] is String) {
      try {
        final decoded = jsonDecode(map['allowed_question_types_json'] as String);
        if (decoded is List) {
          parsedTypes = decoded.map((e) => QuestionType.fromString(e.toString())).toList();
        }
      } catch (_) {}
    } else if (map['allowed_question_types'] is List) {
      parsedTypes = (map['allowed_question_types'] as List)
          .map((e) => QuestionType.fromString(e.toString()))
          .toList();
    }

    return ExamSpecification(
      id: (map['id'] as String?) ?? '',
      projectId: (map['project_id'] as String?) ?? '',
      title: (map['title'] as String?) ?? 'Đặc tả đề kiểm tra',
      subject: (map['subject'] as String?) ?? 'Ngữ văn',
      grade: (map['grade'] as String?) ?? '9',
      durationMinutes: (map['duration_minutes'] as num?)?.toInt() ?? 45,
      totalScore: (map['total_score'] as num?)?.toDouble() ?? 10.0,
      questionCount: (map['question_count'] as num?)?.toInt() ?? 10,
      instructions: map['instructions'] as String?,
      allowedQuestionTypes: parsedTypes,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory ExamSpecification.fromJson(String source) =>
      ExamSpecification.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
