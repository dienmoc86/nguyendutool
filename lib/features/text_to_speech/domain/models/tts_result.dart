import 'tts_options.dart';
import 'tts_timing_segment.dart';

/// Result produced after synthesis and assembly of audio.
class TtsResult {
  final String audioPath;
  final TtsAudioFormat format;
  final int durationMs;
  final int fileSize;
  final int sampleRate;
  final int channels;
  final List<TtsTimingSegment> timingSegments;
  final String? srtPath;
  final String? vttPath;

  const TtsResult({
    required this.audioPath,
    required this.format,
    required this.durationMs,
    required this.fileSize,
    this.sampleRate = 22050,
    this.channels = 1,
    this.timingSegments = const [],
    this.srtPath,
    this.vttPath,
  });

  Map<String, dynamic> toJson() => {
        'audioPath': audioPath,
        'format': format.id,
        'durationMs': durationMs,
        'fileSize': fileSize,
        'sampleRate': sampleRate,
        'channels': channels,
        'timingSegments': timingSegments.map((s) => s.toJson()).toList(),
        'srtPath': srtPath,
        'vttPath': vttPath,
      };

  factory TtsResult.fromJson(Map<String, dynamic> json) => TtsResult(
        audioPath: json['audioPath'] as String? ?? '',
        format: TtsAudioFormat.fromString(json['format'] as String? ?? 'wav'),
        durationMs: json['durationMs'] as int? ?? 0,
        fileSize: json['fileSize'] as int? ?? 0,
        sampleRate: json['sampleRate'] as int? ?? 22050,
        channels: json['channels'] as int? ?? 1,
        timingSegments: (json['timingSegments'] as List<dynamic>?)
                ?.map((e) => TtsTimingSegment.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        srtPath: json['srtPath'] as String?,
        vttPath: json['vttPath'] as String?,
      );
}
