import 'dart:convert';
import '../../../teaching_suite/domain/models/question_models.dart';

/// Single cell in the Exam Matrix corresponding to an Objective & Cognitive Level (GDPT 2018) (Section 11).
class ExamMatrixCell {
  final String id;
  final String specificationId;
  final String objectiveId;
  final QuestionDifficulty difficulty;
  final int questionCount;
  final double scorePerQuestion;
  final Map<QuestionType, int> questionTypeDistribution;

  const ExamMatrixCell({
    required this.id,
    required this.specificationId,
    required this.objectiveId,
    required this.difficulty,
    this.questionCount = 0,
    this.scorePerQuestion = 0.25,
    this.questionTypeDistribution = const {},
  });

  /// Total calculated score for this cell.
  double get cellTotalScore => questionCount * scorePerQuestion;

  /// Safe score in hundredths (e.g. 2.50 points = 250) (Section 13).
  int get cellScoreHundredths => (cellTotalScore * 100).round();

  ExamMatrixCell copyWith({
    String? id,
    String? specificationId,
    String? objectiveId,
    QuestionDifficulty? difficulty,
    int? questionCount,
    double? scorePerQuestion,
    Map<QuestionType, int>? questionTypeDistribution,
  }) {
    return ExamMatrixCell(
      id: id ?? this.id,
      specificationId: specificationId ?? this.specificationId,
      objectiveId: objectiveId ?? this.objectiveId,
      difficulty: difficulty ?? this.difficulty,
      questionCount: questionCount ?? this.questionCount,
      scorePerQuestion: scorePerQuestion ?? this.scorePerQuestion,
      questionTypeDistribution: questionTypeDistribution ?? this.questionTypeDistribution,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'specification_id': specificationId,
        'objective_id': objectiveId,
        'difficulty': difficulty.name,
        'question_count': questionCount,
        'score_per_question': scorePerQuestion,
        'question_type_distribution_json': jsonEncode(
          questionTypeDistribution.map((k, v) => MapEntry(k.name, v)),
        ),
      };

  factory ExamMatrixCell.fromMap(Map<String, dynamic> map) {
    Map<QuestionType, int> parsedDist = {};
    if (map['question_type_distribution_json'] is String) {
      try {
        final decoded = jsonDecode(map['question_type_distribution_json'] as String);
        if (decoded is Map) {
          decoded.forEach((key, val) {
            final type = QuestionType.fromString(key.toString());
            parsedDist[type] = (val as num).toInt();
          });
        }
      } catch (_) {}
    }

    return ExamMatrixCell(
      id: (map['id'] as String?) ?? '',
      specificationId: (map['specification_id'] as String?) ?? '',
      objectiveId: (map['objective_id'] as String?) ?? '',
      difficulty: QuestionDifficulty.fromString(map['difficulty'] as String?),
      questionCount: (map['question_count'] as num?)?.toInt() ?? 0,
      scorePerQuestion: (map['score_per_question'] as num?)?.toDouble() ?? 0.25,
      questionTypeDistribution: parsedDist,
    );
  }
}

/// The complete Exam Matrix structured grid (Section 10).
class ExamMatrix {
  final String specificationId;
  final List<ExamMatrixCell> cells;

  const ExamMatrix({
    required this.specificationId,
    this.cells = const [],
  });

  /// Total questions across all cells.
  int get totalQuestionCount => cells.fold(0, (sum, c) => sum + c.questionCount);
  int get totalQuestions => totalQuestionCount;

  /// Total calculated score across all cells.
  double get totalScore => cells.fold(0.0, (sum, c) => sum + c.cellTotalScore);

  /// Safe total score in hundredths (1000 = 10.00 pts) (Section 13).
  int get totalScoreHundredths => cells.fold(0, (sum, c) => sum + c.cellScoreHundredths);

  /// Returns total questions allocated for a specific cognitive level.
  int getQuestionCountByDifficulty(QuestionDifficulty difficulty) {
    return cells
        .where((c) => c.difficulty == difficulty)
        .fold(0, (sum, c) => sum + c.questionCount);
  }

  /// Returns total score allocated for a specific cognitive level.
  double getScoreByDifficulty(QuestionDifficulty difficulty) {
    return cells
        .where((c) => c.difficulty == difficulty)
        .fold(0.0, (sum, c) => sum + c.cellTotalScore);
  }

  /// Returns total questions allocated for an objective.
  int getQuestionCountByObjective(String objectiveId) {
    return cells
        .where((c) => c.objectiveId == objectiveId)
        .fold(0, (sum, c) => sum + c.questionCount);
  }

  /// Returns total score allocated for an objective.
  double getScoreByObjective(String objectiveId) {
    return cells
        .where((c) => c.objectiveId == objectiveId)
        .fold(0.0, (sum, c) => sum + c.cellTotalScore);
  }

  /// Finds a specific cell by objective and difficulty.
  ExamMatrixCell? getCell(String objectiveId, QuestionDifficulty difficulty) {
    try {
      return cells.firstWhere(
        (c) => c.objectiveId == objectiveId && c.difficulty == difficulty,
      );
    } catch (_) {
      return null;
    }
  }

  /// Checks if a cell exists for objective and difficulty.
  bool hasCellFor(String objectiveId, QuestionDifficulty difficulty) {
    return getCell(objectiveId, difficulty) != null;
  }

  /// Checks if matrix score matches expected score within tolerance (Section 12 & 13).
  bool matchesTotalScore(double expectedScore, {double tolerance = 0.01}) {
    return (totalScore - expectedScore).abs() <= tolerance;
  }

  /// Checks if matrix question count matches expected count.
  bool matchesQuestionCount(int expectedCount) {
    return totalQuestionCount == expectedCount;
  }

  ExamMatrix copyWith({
    String? specificationId,
    List<ExamMatrixCell>? cells,
  }) {
    return ExamMatrix(
      specificationId: specificationId ?? this.specificationId,
      cells: cells ?? this.cells,
    );
  }

  Map<String, dynamic> toMap() => {
        'specification_id': specificationId,
        'cells': cells.map((c) => c.toMap()).toList(),
      };

  factory ExamMatrix.fromMap(Map<String, dynamic> map) {
    List<ExamMatrixCell> parsedCells = [];
    if (map['cells'] is List) {
      parsedCells = (map['cells'] as List)
          .map((c) => ExamMatrixCell.fromMap(c as Map<String, dynamic>))
          .toList();
    }
    return ExamMatrix(
      specificationId: (map['specification_id'] as String?) ?? '',
      cells: parsedCells,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory ExamMatrix.fromJson(String source) =>
      ExamMatrix.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
