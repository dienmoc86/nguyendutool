import 'tts_options.dart';

/// Predefined voice & audio setting preset for educational workflows.
class TtsPreset {
  final String id;
  final String name;
  final String description;
  final String? voiceId;
  final double speed;
  final double pitch;
  final double volume;
  final int paragraphPauseMs;
  final int sentencePauseMs;
  final TtsAudioFormat format;
  final bool isPreset;

  const TtsPreset({
    required this.id,
    required this.name,
    required this.description,
    this.voiceId,
    this.speed = 1.0,
    this.pitch = 1.0,
    this.volume = 1.0,
    this.paragraphPauseMs = 500,
    this.sentencePauseMs = 250,
    this.format = TtsAudioFormat.wav,
    this.isPreset = false,
  });

  TtsOptions toOptions() => TtsOptions(
        speed: speed,
        pitch: pitch,
        volume: volume,
        paragraphPauseMs: paragraphPauseMs,
        sentencePauseMs: sentencePauseMs,
        format: format,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'voiceId': voiceId,
        'speed': speed,
        'pitch': pitch,
        'volume': volume,
        'paragraphPauseMs': paragraphPauseMs,
        'sentencePauseMs': sentencePauseMs,
        'format': format.id,
        'isPreset': isPreset,
      };

  factory TtsPreset.fromJson(Map<String, dynamic> json) => TtsPreset(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Preset',
        description: json['description'] as String? ?? '',
        voiceId: json['voiceId'] as String?,
        speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
        pitch: (json['pitch'] as num?)?.toDouble() ?? 1.0,
        volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
        paragraphPauseMs: json['paragraphPauseMs'] as int? ?? 500,
        sentencePauseMs: json['sentencePauseMs'] as int? ?? 250,
        format: TtsAudioFormat.fromString(json['format'] as String? ?? 'wav'),
        isPreset: json['isPreset'] == 1 || json['isPreset'] == true,
      );
}
