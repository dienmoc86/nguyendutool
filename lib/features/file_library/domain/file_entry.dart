/// Represents a recorded file in the local workspace library.
class FileEntry {
  final String id;
  final String? projectId;
  final String originalName;
  final String localPath;
  final String? mimeType;
  final int size; // bytes
  final DateTime createdAt;

  const FileEntry({
    required this.id,
    this.projectId,
    required this.originalName,
    required this.localPath,
    this.mimeType,
    required this.size,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'original_name': originalName,
      'local_path': localPath,
      'mime_type': mimeType,
      'size': size,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory FileEntry.fromMap(Map<String, dynamic> map) {
    return FileEntry(
      id: map['id'] as String,
      projectId: map['project_id'] as String?,
      originalName: map['original_name'] as String,
      localPath: map['local_path'] as String,
      mimeType: map['mime_type'] as String?,
      size: (map['size'] as num).toInt(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
