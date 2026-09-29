/// Structured media metadata returned by ffprobe / ffmpeg inspection.
class MediaProbeResult {
  final String filePath;
  final int fileSizeBytes;
  final double durationSeconds;
  final int durationMs;
  final int? width;
  final int? height;
  final double? fps;
  final String? videoCodec;
  final String? audioCodec;
  final int? sampleRate;
  final int? channels;
  final int? bitRate;
  final bool hasVideo;
  final bool hasAudio;
  final String? containerFormat;
  final Map<String, dynamic> rawJson;

  const MediaProbeResult({
    required this.filePath,
    required this.fileSizeBytes,
    required this.durationSeconds,
    required this.durationMs,
    this.width,
    this.height,
    this.fps,
    this.videoCodec,
    this.audioCodec,
    this.sampleRate,
    this.channels,
    this.bitRate,
    required this.hasVideo,
    required this.hasAudio,
    this.containerFormat,
    this.rawJson = const {},
  });

  double get aspectRatio => (width != null && height != null && height! > 0)
      ? width! / height!
      : 16 / 9;

  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'fileSizeBytes': fileSizeBytes,
        'durationSeconds': durationSeconds,
        'durationMs': durationMs,
        'width': width,
        'height': height,
        'fps': fps,
        'videoCodec': videoCodec,
        'audioCodec': audioCodec,
        'sampleRate': sampleRate,
        'channels': channels,
        'bitRate': bitRate,
        'hasVideo': hasVideo,
        'hasAudio': hasAudio,
        'containerFormat': containerFormat,
      };

  factory MediaProbeResult.empty(String path) => MediaProbeResult(
        filePath: path,
        fileSizeBytes: 0,
        durationSeconds: 0,
        durationMs: 0,
        hasVideo: false,
        hasAudio: false,
      );
}
