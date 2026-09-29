import 'audio_ducking_level.dart';
import 'media_asset.dart';
import 'video_export_settings.dart';
import 'video_scene.dart';

/// Represents a complete Video Studio Project.
class VideoProject {
  final String id;
  final String name;
  final VideoAspectRatio aspectRatio;
  final VideoResolution resolution;
  final int fps;
  final List<VideoScene> scenes;
  final List<MediaAsset> assets;
  final String? backgroundMusicPath;
  final double backgroundMusicVolume;
  final bool backgroundMusicLoop;
  final AudioDuckingLevel audioDucking;
  final VideoExportSettings exportSettings;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VideoProject({
    required this.id,
    required this.name,
    this.aspectRatio = VideoAspectRatio.widescreen16x9,
    this.resolution = VideoResolution.res1080p,
    this.fps = 30,
    this.scenes = const [],
    this.assets = const [],
    this.backgroundMusicPath,
    this.backgroundMusicVolume = 0.35,
    this.backgroundMusicLoop = true,
    this.audioDucking = AudioDuckingLevel.medium,
    this.exportSettings = const VideoExportSettings(),
    required this.createdAt,
    required this.updatedAt,
  });

  /// Total duration of all scenes in seconds.
  double get totalDurationSeconds =>
      scenes.fold(0.0, (sum, s) => sum + s.durationSeconds);

  VideoProject copyWith({
    String? id,
    String? name,
    VideoAspectRatio? aspectRatio,
    VideoResolution? resolution,
    int? fps,
    List<VideoScene>? scenes,
    List<MediaAsset>? assets,
    String? backgroundMusicPath,
    double? backgroundMusicVolume,
    bool? backgroundMusicLoop,
    AudioDuckingLevel? audioDucking,
    VideoExportSettings? exportSettings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      VideoProject(
        id: id ?? this.id,
        name: name ?? this.name,
        aspectRatio: aspectRatio ?? this.aspectRatio,
        resolution: resolution ?? this.resolution,
        fps: fps ?? this.fps,
        scenes: scenes ?? this.scenes,
        assets: assets ?? this.assets,
        backgroundMusicPath: backgroundMusicPath ?? this.backgroundMusicPath,
        backgroundMusicVolume: backgroundMusicVolume ?? this.backgroundMusicVolume,
        backgroundMusicLoop: backgroundMusicLoop ?? this.backgroundMusicLoop,
        audioDucking: audioDucking ?? this.audioDucking,
        exportSettings: exportSettings ?? this.exportSettings,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'aspectRatio': aspectRatio.name,
        'resolution': resolution.name,
        'fps': fps,
        'scenes': scenes.map((s) => s.toJson()).toList(),
        'assets': assets.map((a) => a.toJson()).toList(),
        'backgroundMusicPath': backgroundMusicPath,
        'backgroundMusicVolume': backgroundMusicVolume,
        'backgroundMusicLoop': backgroundMusicLoop,
        'audioDucking': audioDucking.name,
        'exportSettings': exportSettings.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory VideoProject.fromJson(Map<String, dynamic> json) => VideoProject(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Dự án Video Mới',
        aspectRatio: VideoAspectRatio.values.firstWhere(
          (a) => a.name == json['aspectRatio'],
          orElse: () => VideoAspectRatio.widescreen16x9,
        ),
        resolution: VideoResolution.values.firstWhere(
          (r) => r.name == json['resolution'],
          orElse: () => VideoResolution.res1080p,
        ),
        fps: json['fps'] as int? ?? 30,
        scenes: (json['scenes'] as List<dynamic>?)
                ?.map((s) => VideoScene.fromJson(s as Map<String, dynamic>))
                .toList() ??
            const [],
        assets: (json['assets'] as List<dynamic>?)
                ?.map((a) => MediaAsset.fromJson(a as Map<String, dynamic>))
                .toList() ??
            const [],
        backgroundMusicPath: json['backgroundMusicPath'] as String?,
        backgroundMusicVolume: (json['backgroundMusicVolume'] as num?)?.toDouble() ?? 0.35,
        backgroundMusicLoop: json['backgroundMusicLoop'] as bool? ?? true,
        audioDucking: AudioDuckingLevel.values.firstWhere(
          (d) => d.name == json['audioDucking'],
          orElse: () => AudioDuckingLevel.medium,
        ),
        exportSettings: json['exportSettings'] != null
            ? VideoExportSettings.fromJson(json['exportSettings'] as Map<String, dynamic>)
            : const VideoExportSettings(),
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : DateTime.now(),
      );
}
