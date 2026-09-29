/// Encapsulates an FFmpeg command execution specification and result.
class FfmpegCommand {
  final List<String> arguments;
  final String description;
  final Duration timeout;

  const FfmpegCommand({
    required this.arguments,
    required this.description,
    this.timeout = const Duration(minutes: 10),
  });

  @override
  String toString() => 'ffmpeg ${arguments.join(" ")}';
}

/// Result of an executed FFmpeg command.
class FfmpegResult {
  final bool isSuccess;
  final int exitCode;
  final String stdout;
  final String stderr;
  final String? outputPath;
  final Duration elapsed;
  final bool wasCancelled;

  const FfmpegResult({
    required this.isSuccess,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    this.outputPath,
    required this.elapsed,
    this.wasCancelled = false,
  });

  factory FfmpegResult.cancelled() => const FfmpegResult(
        isSuccess: false,
        exitCode: -1,
        stdout: '',
        stderr: 'Quá trình render đã bị hủy bởi người dùng.',
        elapsed: Duration.zero,
        wasCancelled: true,
      );

  factory FfmpegResult.failed({
    required int exitCode,
    required String stderr,
    Duration elapsed = Duration.zero,
  }) =>
      FfmpegResult(
        isSuccess: false,
        exitCode: exitCode,
        stdout: '',
        stderr: stderr,
        elapsed: elapsed,
      );
}
