import 'dart:convert';
import 'exam_question_snapshot.dart';

/// The master exam paper (Sections 25, 29, 30, 31).
/// Represents the canonical exam before multi-code student shuffling.
class ExamPaper {
  final String id;
  final String assessmentProjectId;
  final String specificationId;
  final String title;
  final String examCode;
  final int durationMinutes;
  final double totalScore;
  final List<ExamQuestionSnapshot> questions;
  final int? randomSeed;
  final int revisionNumber;
  final bool isFinalized;
  final DateTime createdAt;
  final DateTime? finalizedAt;

  const ExamPaper({
    required this.id,
    required this.assessmentProjectId,
    required this.specificationId,
    required this.title,
    this.examCode = 'MASTER',
    this.durationMinutes = 45,
    this.totalScore = 10.0,
    this.questions = const [],
    this.randomSeed,
    this.revisionNumber = 1,
    this.isFinalized = false,
    required this.createdAt,
    this.finalizedAt,
  });

  /// Computed actual total score from question snapshots
  double get calculatedScore => questions.fold(0.0, (sum, q) => sum + q.score);

  int get questionCount => questions.length;

  ExamPaper copyWith({
    String? id,
    String? assessmentProjectId,
    String? specificationId,
    String? title,
    String? examCode,
    int? durationMinutes,
    double? totalScore,
    List<ExamQuestionSnapshot>? questions,
    int? randomSeed,
    int? revisionNumber,
    bool? isFinalized,
    DateTime? createdAt,
    DateTime? finalizedAt,
  }) {
    return ExamPaper(
      id: id ?? this.id,
      assessmentProjectId: assessmentProjectId ?? this.assessmentProjectId,
      specificationId: specificationId ?? this.specificationId,
      title: title ?? this.title,
      examCode: examCode ?? this.examCode,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      totalScore: totalScore ?? this.totalScore,
      questions: questions ?? this.questions,
      randomSeed: randomSeed ?? this.randomSeed,
      revisionNumber: revisionNumber ?? this.revisionNumber,
      isFinalized: isFinalized ?? this.isFinalized,
      createdAt: createdAt ?? this.createdAt,
      finalizedAt: finalizedAt ?? this.finalizedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': assessmentProjectId,
        'specification_id': specificationId,
        'title': title,
        'exam_code': examCode,
        'duration_minutes': durationMinutes,
        'total_score': totalScore,
        'random_seed': randomSeed,
        'revision_number': revisionNumber,
        'is_finalized': isFinalized ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'finalized_at': finalizedAt?.toIso8601String(),
        'questions': questions.map((q) => q.toMap()).toList(),
      };

  factory ExamPaper.fromMap(Map<String, dynamic> map, {List<ExamQuestionSnapshot> questions = const []}) {
    List<ExamQuestionSnapshot> parsedQuestions = questions;
    if (parsedQuestions.isEmpty && map['questions'] is List) {
      parsedQuestions = (map['questions'] as List)
          .map((q) => ExamQuestionSnapshot.fromMap(q as Map<String, dynamic>))
          .toList();
    }

    return ExamPaper(
      id: (map['id'] as String?) ?? '',
      assessmentProjectId: (map['project_id'] ?? map['assessmentProjectId']) as String? ?? '',
      specificationId: (map['specification_id'] ?? map['specificationId']) as String? ?? '',
      title: (map['title'] as String?) ?? 'Đề thi gốc',
      examCode: (map['exam_code'] as String?) ?? 'MASTER',
      durationMinutes: (map['duration_minutes'] as num?)?.toInt() ?? 45,
      totalScore: (map['total_score'] as num?)?.toDouble() ?? 10.0,
      questions: parsedQuestions,
      randomSeed: (map['random_seed'] as num?)?.toInt(),
      revisionNumber: (map['revision_number'] as num?)?.toInt() ?? 1,
      isFinalized: (map['is_finalized'] == 1 || map['is_finalized'] == true),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      finalizedAt: map['finalized_at'] != null
          ? DateTime.tryParse(map['finalized_at'] as String)
          : null,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory ExamPaper.fromJson(String source) =>
      ExamPaper.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
