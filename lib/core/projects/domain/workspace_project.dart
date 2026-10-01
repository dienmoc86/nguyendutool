import 'project_type.dart';

/// Representation of a workspace project unifying lesson plans, media, and outputs.
class WorkspaceProject {
  final String id;
  final ProjectType type;
  final String name;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? metadataJson;
  final String? thumbnailPath;

  const WorkspaceProject({
    required this.id,
    required this.type,
    required this.name,
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
    this.metadataJson,
    this.thumbnailPath,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.id,
        'name': name,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'metadata_json': metadataJson,
        'thumbnail_path': thumbnailPath,
      };

  factory WorkspaceProject.fromMap(Map<String, dynamic> map) {
    return WorkspaceProject(
      id: map['id'] as String,
      type: ProjectType.fromId(map['type'] as String),
      name: map['name'] as String,
      status: map['status'] as String? ?? 'active',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      metadataJson: map['metadata_json'] as String?,
      thumbnailPath: map['thumbnail_path'] as String?,
    );
  }

  WorkspaceProject copyWith({
    String? id,
    ProjectType? type,
    String? name,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? metadataJson,
    String? thumbnailPath,
  }) {
    return WorkspaceProject(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadataJson: metadataJson ?? this.metadataJson,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }
}
