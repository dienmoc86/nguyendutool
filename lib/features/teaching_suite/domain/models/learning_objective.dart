import 'dart:convert';

/// Structured learning objective for GDPT 2018 (Yêu cầu cần đạt / Mục tiêu dạy học).
class LearningObjective {
  final String id;
  final String projectId;
  final String code; // e.g. "NL_V1", "KT_01", "PC_NHAN_AI"
  final String description;
  final String? category; // e.g. "Năng lực đặc thù", "Phẩm chất", "Kiến thức"
  final int orderIndex;

  const LearningObjective({
    required this.id,
    required this.projectId,
    required this.code,
    required this.description,
    this.category,
    this.orderIndex = 0,
  });

  LearningObjective copyWith({
    String? id,
    String? projectId,
    String? code,
    String? description,
    String? category,
    int? orderIndex,
  }) {
    return LearningObjective(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      code: code ?? this.code,
      description: description ?? this.description,
      category: category ?? this.category,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'code': code,
        'description': description,
        'category': category,
        'order_index': orderIndex,
      };

  factory LearningObjective.fromMap(Map<String, dynamic> map) => LearningObjective(
        id: (map['id'] as String?) ?? '',
        projectId: (map['project_id'] as String?) ?? '',
        code: (map['code'] as String?) ?? '',
        description: (map['description'] as String?) ?? '',
        category: map['category'] as String?,
        orderIndex: (map['order_index'] as num?)?.toInt() ?? 0,
      );

  String toJson() => jsonEncode(toMap());

  factory LearningObjective.fromJson(String source) =>
      LearningObjective.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
