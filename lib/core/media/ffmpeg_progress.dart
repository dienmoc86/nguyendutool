/// Real-time FFmpeg progress reporting parsed from `-progress pipe:1` or stderr stream.
class FfmpegProgress {
  final int frame;
  final double fps;
  final int outTimeMs;
  final double speed;
  final double progressPercent; // 0.0 to 1.0
  final String stage;
  final String? rawLine;

  const FfmpegProgress({
    this.frame = 0,
    this.fps = 0.0,
    this.outTimeMs = 0,
    this.speed = 1.0,
    this.progressPercent = 0.0,
    this.stage = 'rendering',
    this.rawLine,
  });

  /// Factory parser for key=value lines produced by FFmpeg `-progress pipe:1`
  static FfmpegProgress parseProgressLine({
    required Map<String, String> keyValues,
    required double totalDurationSeconds,
    required String currentStage,
  }) {
    final frame = int.tryParse(keyValues['frame'] ?? '0') ?? 0;
    final fps = double.tryParse(keyValues['fps'] ?? '0') ?? 0.0;
    
    // out_time_ms is in microseconds in FFmpeg `-progress` output
    final outTimeUs = int.tryParse(keyValues['out_time_us'] ?? '0') ?? 0;
    final outTimeMs = outTimeUs > 0 ? (outTimeUs / 1000).round() : 0;

    // speed can be e.g. "1.25x"
    final speedStr = (keyValues['speed'] ?? '1.0x').replaceAll('x', '').trim();
    final speed = double.tryParse(speedStr) ?? 1.0;

    double progressPercent = 0.0;
    if (totalDurationSeconds > 0) {
      progressPercent = (outTimeMs / (totalDurationSeconds * 1000)).clamp(0.0, 1.0);
    }

    return FfmpegProgress(
      frame: frame,
      fps: fps,
      outTimeMs: outTimeMs,
      speed: speed,
      progressPercent: progressPercent,
      stage: currentStage,
    );
  }
}
