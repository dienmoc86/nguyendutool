import 'dart:convert';

/// A performance level within a rubric criterion.
class RubricLevel {
  final String name; // e.g., 'Xuất sắc', 'Tốt', 'Đạt', 'Cần cố gắng'
  final double score; // e.g., 4.0, 3.0, 2.0, 1.0 or percentage
  final String description; // Detailed descriptors of student performance

  double get points => score;

  const RubricLevel({
    required this.name,
    double? score,
    double? points,
    required this.description,
  }) : score = score ?? points ?? 1.0;

  RubricLevel copyWith({
    String? name,
    double? score,
    String? description,
  }) {
    return RubricLevel(
      name: name ?? this.name,
      score: score ?? this.score,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'score': score,
        'description': description,
      };

  factory RubricLevel.fromMap(Map<String, dynamic> map) => RubricLevel(
        name: (map['name'] as String?) ?? '',
        score: (map['score'] as num?)?.toDouble() ?? 1.0,
        description: (map['description'] as String?) ?? '',
      );
}

/// A single evaluation criterion in a rubric.
class RubricCriterion {
  final String id;
  final String name;
  final double weight; // In percent, e.g., 25.0
  final String? objectiveId; // Link to learning objective
  final List<RubricLevel> levels;

  String get title => name;
  double get maxScore => weight;

  const RubricCriterion({
    required this.id,
    String? name,
    String? title,
    double? weight,
    double? maxScore,
    this.objectiveId,
    this.levels = const [],
  })  : name = name ?? title ?? '',
        weight = weight ?? maxScore ?? 25.0;

  RubricCriterion copyWith({
    String? id,
    String? name,
    double? weight,
    String? objectiveId,
    List<RubricLevel>? levels,
  }) {
    return RubricCriterion(
      id: id ?? this.id,
      name: name ?? this.name,
      weight: weight ?? this.weight,
      objectiveId: objectiveId ?? this.objectiveId,
      levels: levels ?? this.levels,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'weight': weight,
        'objectiveId': objectiveId,
        'levels': levels.map((l) => l.toMap()).toList(),
      };

  factory RubricCriterion.fromMap(Map<String, dynamic> map) => RubricCriterion(
        id: (map['id'] as String?) ?? 'crit_${DateTime.now().millisecondsSinceEpoch}',
        name: (map['name'] as String?) ?? '',
        weight: (map['weight'] as num?)?.toDouble() ?? 25.0,
        objectiveId: map['objectiveId'] as String?,
        levels: (map['levels'] as List<dynamic>?)
                ?.map((e) => RubricLevel.fromMap(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

/// Evaluation rubric model for a lesson project.
class RubricModel {
  final String id;
  final String projectId;
  final String title;
  final List<RubricCriterion> criteria;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get totalScore => totalWeight;

  RubricModel({
    required this.id,
    required this.projectId,
    required this.title,
    this.criteria = const [],
    double? totalScore,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Sum of all criteria weights
  double get totalWeight => criteria.fold(0.0, (sum, c) => sum + c.weight);

  /// Validates whether total weight sums to 100% (with small floating precision tolerance)
  bool get isWeightValid {
    if (criteria.isEmpty) return false;
    final diff = (totalWeight - 100.0).abs();
    return diff < 0.01;
  }

  RubricModel copyWith({
    String? id,
    String? projectId,
    String? title,
    List<RubricCriterion>? criteria,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RubricModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      criteria: criteria ?? this.criteria,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'projectId': projectId,
        'title': title,
        'criteria': criteria.map((c) => c.toMap()).toList(),
        'totalWeight': totalWeight,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory RubricModel.fromMap(Map<String, dynamic> map) {
    List<RubricCriterion> parsedCriteria = [];
    if (map['criteria'] is List) {
      parsedCriteria = (map['criteria'] as List)
          .map((e) => RubricCriterion.fromMap(e as Map<String, dynamic>))
          .toList();
    } else if (map['criteria_json'] is String) {
      try {
        final decoded = jsonDecode(map['criteria_json'] as String);
        if (decoded is List) {
          parsedCriteria = decoded
              .map((e) => RubricCriterion.fromMap(e as Map<String, dynamic>))
              .toList();
        }
      } catch (_) {}
    }

    return RubricModel(
      id: (map['id'] as String?) ?? 'rub_${DateTime.now().millisecondsSinceEpoch}',
      projectId: (map['projectId'] ?? map['project_id'] ?? '') as String,
      title: (map['title'] as String?) ?? '',
      criteria: parsedCriteria,
      createdAt: map['created_at'] != null || map['createdAt'] != null
          ? DateTime.tryParse((map['created_at'] ?? map['createdAt']) as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null || map['updatedAt'] != null
          ? DateTime.tryParse((map['updated_at'] ?? map['updatedAt']) as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory RubricModel.fromJson(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return RubricModel.fromMap(decoded);
      }
      return RubricModel(id: 'rub_${DateTime.now().millisecondsSinceEpoch}', projectId: '', title: '');
    } catch (_) {
      return RubricModel(id: 'rub_${DateTime.now().millisecondsSinceEpoch}', projectId: '', title: '');
    }
  }
}
