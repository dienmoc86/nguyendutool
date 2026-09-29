/// Media types supported in Video Studio.
enum MediaType {
  image,
  video,
  audio,
  subtitle,
}

/// Represents an imported media asset in the video project.
class MediaAsset {
  final String id;
  final String name;
  final String path;
  final MediaType type;
  final int? width;
  final int? height;
  final int? durationMs;
  final int fileSize;
  final String? mimeType;
  final DateTime importedAt;

  const MediaAsset({
    required this.id,
    required this.name,
    required this.path,
    required this.type,
    this.width,
    this.height,
    this.durationMs,
    required this.fileSize,
    this.mimeType,
    required this.importedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'type': type.name,
        'width': width,
        'height': height,
        'durationMs': durationMs,
        'fileSize': fileSize,
        'mimeType': mimeType,
        'importedAt': importedAt.toIso8601String(),
      };

  factory MediaAsset.fromJson(Map<String, dynamic> json) => MediaAsset(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        path: json['path'] as String? ?? '',
        type: MediaType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => MediaType.image,
        ),
        width: json['width'] as int?,
        height: json['height'] as int?,
        durationMs: json['durationMs'] as int?,
        fileSize: json['fileSize'] as int? ?? 0,
        mimeType: json['mimeType'] as String?,
        importedAt: json['importedAt'] != null
            ? DateTime.parse(json['importedAt'] as String)
            : DateTime.now(),
      );
}
