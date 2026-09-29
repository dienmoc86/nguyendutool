import 'package:nguyendu_tool/features/text_to_speech/domain/models/tts_timing_segment.dart';
import 'ken_burns_effect.dart';
import 'transition.dart';

/// Image scaling & framing modes inside the scene canvas.
enum ImageFitMode {
  fit('Vừa khung (Hiển thị trọn vẹn, viền mờ nền)'),
  fill('Lấp đầy (Cắt nhẹ mép để phủ kín màn hình)'),
  crop('Cắt trọng tâm (Center crop)');

  final String displayName;
  const ImageFitMode(this.displayName);
}

/// Represents an individual scene / slide in a Video Project.
class VideoScene {
  final String id;
  final String projectId;
  final int index;
  final double durationSeconds;
  final String? backgroundImagePath;
  final String? videoClipPath;
  final double clipTrimStartSeconds;
  final double? clipTrimEndSeconds;
  final bool clipMuteOriginalAudio;
  final ImageFitMode imageFitMode;
  final bool blurBackground;
  final KenBurnsEffect kenBurns;
  final SceneTransition transition;
  final String? title;
  final String? subtitle;
  final String? bodyText;
  final String? narrationText;
  final String? voiceoverAudioPath;
  final double? voiceoverDurationSeconds;
  final List<TtsTimingSegment> subtitleSegments;

  const VideoScene({
    required this.id,
    required this.projectId,
    required this.index,
    this.durationSeconds = 5.0,
    this.backgroundImagePath,
    this.videoClipPath,
    this.clipTrimStartSeconds = 0.0,
    this.clipTrimEndSeconds,
    this.clipMuteOriginalAudio = false,
    this.imageFitMode = ImageFitMode.fit,
    this.blurBackground = true,
    this.kenBurns = KenBurnsEffect.none,
    this.transition = const SceneTransition(type: TransitionType.fade, durationSeconds: 0.5),
    this.title,
    this.subtitle,
    this.bodyText,
    this.narrationText,
    this.voiceoverAudioPath,
    this.voiceoverDurationSeconds,
    this.subtitleSegments = const [],
  });

  bool get hasVoiceover => voiceoverAudioPath != null && voiceoverAudioPath!.isNotEmpty;
  bool get hasVideoClip => videoClipPath != null && videoClipPath!.isNotEmpty;
  bool get hasImage => backgroundImagePath != null && backgroundImagePath!.isNotEmpty;

  VideoScene copyWith({
    String? id,
    String? projectId,
    int? index,
    double? durationSeconds,
    String? backgroundImagePath,
    String? videoClipPath,
    double? clipTrimStartSeconds,
    double? clipTrimEndSeconds,
    bool? clipMuteOriginalAudio,
    ImageFitMode? imageFitMode,
    bool? blurBackground,
    KenBurnsEffect? kenBurns,
    SceneTransition? transition,
    String? title,
    String? subtitle,
    String? bodyText,
    String? narrationText,
    String? voiceoverAudioPath,
    double? voiceoverDurationSeconds,
    List<TtsTimingSegment>? subtitleSegments,
  }) =>
      VideoScene(
        id: id ?? this.id,
        projectId: projectId ?? this.projectId,
        index: index ?? this.index,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        backgroundImagePath: backgroundImagePath ?? this.backgroundImagePath,
        videoClipPath: videoClipPath ?? this.videoClipPath,
        clipTrimStartSeconds: clipTrimStartSeconds ?? this.clipTrimStartSeconds,
        clipTrimEndSeconds: clipTrimEndSeconds ?? this.clipTrimEndSeconds,
        clipMuteOriginalAudio: clipMuteOriginalAudio ?? this.clipMuteOriginalAudio,
        imageFitMode: imageFitMode ?? this.imageFitMode,
        blurBackground: blurBackground ?? this.blurBackground,
        kenBurns: kenBurns ?? this.kenBurns,
        transition: transition ?? this.transition,
        title: title ?? this.title,
        subtitle: subtitle ?? this.subtitle,
        bodyText: bodyText ?? this.bodyText,
        narrationText: narrationText ?? this.narrationText,
        voiceoverAudioPath: voiceoverAudioPath ?? this.voiceoverAudioPath,
        voiceoverDurationSeconds: voiceoverDurationSeconds ?? this.voiceoverDurationSeconds,
        subtitleSegments: subtitleSegments ?? this.subtitleSegments,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'index': index,
        'durationSeconds': durationSeconds,
        'backgroundImagePath': backgroundImagePath,
        'videoClipPath': videoClipPath,
        'clipTrimStartSeconds': clipTrimStartSeconds,
        'clipTrimEndSeconds': clipTrimEndSeconds,
        'clipMuteOriginalAudio': clipMuteOriginalAudio,
        'imageFitMode': imageFitMode.name,
        'blurBackground': blurBackground,
        'kenBurns': kenBurns.name,
        'transition': transition.toJson(),
        'title': title,
        'subtitle': subtitle,
        'bodyText': bodyText,
        'narrationText': narrationText,
        'voiceoverAudioPath': voiceoverAudioPath,
        'voiceoverDurationSeconds': voiceoverDurationSeconds,
        'subtitleSegments': subtitleSegments.map((s) => s.toJson()).toList(),
      };

  factory VideoScene.fromJson(Map<String, dynamic> json) => VideoScene(
        id: json['id'] as String? ?? '',
        projectId: json['projectId'] as String? ?? '',
        index: json['index'] as int? ?? 0,
        durationSeconds: (json['durationSeconds'] as num?)?.toDouble() ?? 5.0,
        backgroundImagePath: json['backgroundImagePath'] as String?,
        videoClipPath: json['videoClipPath'] as String?,
        clipTrimStartSeconds: (json['clipTrimStartSeconds'] as num?)?.toDouble() ?? 0.0,
        clipTrimEndSeconds: (json['clipTrimEndSeconds'] as num?)?.toDouble(),
        clipMuteOriginalAudio: json['clipMuteOriginalAudio'] as bool? ?? false,
        imageFitMode: ImageFitMode.values.firstWhere(
          (m) => m.name == json['imageFitMode'],
          orElse: () => ImageFitMode.fit,
        ),
        blurBackground: json['blurBackground'] as bool? ?? true,
        kenBurns: KenBurnsEffect.values.firstWhere(
          (k) => k.name == json['kenBurns'],
          orElse: () => KenBurnsEffect.none,
        ),
        transition: json['transition'] != null
            ? SceneTransition.fromJson(json['transition'] as Map<String, dynamic>)
            : const SceneTransition(),
        title: json['title'] as String?,
        subtitle: json['subtitle'] as String?,
        bodyText: json['bodyText'] as String?,
        narrationText: json['narrationText'] as String?,
        voiceoverAudioPath: json['voiceoverAudioPath'] as String?,
        voiceoverDurationSeconds: (json['voiceoverDurationSeconds'] as num?)?.toDouble(),
        subtitleSegments: (json['subtitleSegments'] as List<dynamic>?)
                ?.map((s) => TtsTimingSegment.fromJson(s as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}
