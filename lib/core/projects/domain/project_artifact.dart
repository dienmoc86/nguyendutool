import 'artifact_type.dart';

/// Representation of an output artifact linked to a WorkspaceProject.
class ProjectArtifact {
  final String id;
  final String projectId;
  final ArtifactType artifactType;
  final String? fileId;
  final String? filePath;
  final DateTime createdAt;
  final String? metadataJson;

  const ProjectArtifact({
    required this.id,
    required this.projectId,
    required this.artifactType,
    this.fileId,
    this.filePath,
    required this.createdAt,
    this.metadataJson,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'artifact_type': artifactType.id,
        'file_id': fileId,
        'file_path': filePath,
        'created_at': createdAt.toIso8601String(),
        'metadata_json': metadataJson,
      };

  factory ProjectArtifact.fromMap(Map<String, dynamic> map) {
    return ProjectArtifact(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      artifactType: ArtifactType.fromId(map['artifact_type'] as String),
      fileId: map['file_id'] as String?,
      filePath: map['file_path'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      metadataJson: map['metadata_json'] as String?,
    );
  }

  ProjectArtifact copyWith({
    String? id,
    String? projectId,
    ArtifactType? artifactType,
    String? fileId,
    String? filePath,
    DateTime? createdAt,
    String? metadataJson,
  }) {
    return ProjectArtifact(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      artifactType: artifactType ?? this.artifactType,
      fileId: fileId ?? this.fileId,
      filePath: filePath ?? this.filePath,
      createdAt: createdAt ?? this.createdAt,
      metadataJson: metadataJson ?? this.metadataJson,
    );
  }
}
