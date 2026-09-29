import 'dart:convert';
import 'dart:io';
import '../domain/models/tts_timing_segment.dart';
import '../../../core/logging/app_logger.dart';

/// Service for generating and exporting Subtitle files (SRT and WebVTT)
/// compliant with Vietnamese UTF-8 text and standard video player formats.
class SubtitleGenerator {
  const SubtitleGenerator();

  /// Generates SRT (SubRip) subtitle format string from timing segments.
  /// Format:
  /// 1
  /// 00:00:01,000 --> 00:00:04,500
  /// Chào mừng các bạn đến với trường Nguyễn Du
  String generateSrt(List<TtsTimingSegment> segments) {
    if (segments.isEmpty) return '';

    final buffer = StringBuffer();
    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final itemIndex = i + 1;
      final startStr = _formatSrtTimestamp(seg.startMs);
      final endStr = _formatSrtTimestamp(seg.endMs);

      buffer.writeln(itemIndex);
      buffer.writeln('$startStr --> $endStr');
      buffer.writeln(seg.text.trim());
      buffer.writeln(); // Blank line between subtitles
    }

    return '${buffer.toString().trimRight()}\n';
  }

  /// Generates WebVTT (.vtt) subtitle format string from timing segments.
  /// Format:
  /// WEBVTT
  ///
  /// 1
  /// 00:00:01.000 --> 00:00:04.500
  /// Chào mừng các bạn đến với trường Nguyễn Du
  String generateVtt(List<TtsTimingSegment> segments) {
    final buffer = StringBuffer();
    buffer.writeln('WEBVTT');
    buffer.writeln();

    if (segments.isEmpty) return buffer.toString();

    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final itemIndex = i + 1;
      final startStr = _formatVttTimestamp(seg.startMs);
      final endStr = _formatVttTimestamp(seg.endMs);

      buffer.writeln(itemIndex);
      buffer.writeln('$startStr --> $endStr');
      buffer.writeln(seg.text.trim());
      buffer.writeln();
    }

    return '${buffer.toString().trimRight()}\n';
  }

  /// Exports SRT to file using UTF-8 encoding.
  Future<File> exportSrtToFile(List<TtsTimingSegment> segments, String outputPath) async {
    final content = generateSrt(segments);
    final file = File(outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(content, encoding: utf8);
    AppLogger.info('Exported SRT subtitle: $outputPath (${segments.length} segments)');
    return file;
  }

  /// Exports WebVTT to file using UTF-8 encoding.
  Future<File> exportVttToFile(List<TtsTimingSegment> segments, String outputPath) async {
    final content = generateVtt(segments);
    final file = File(outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(content, encoding: utf8);
    AppLogger.info('Exported VTT subtitle: $outputPath (${segments.length} segments)');
    return file;
  }

  /// Converts milliseconds to SRT format: HH:MM:SS,mmm
  String _formatSrtTimestamp(int milliseconds) {
    if (milliseconds < 0) milliseconds = 0;
    final int hours = milliseconds ~/ 3600000;
    final int minutes = (milliseconds % 3600000) ~/ 60000;
    final int seconds = (milliseconds % 60000) ~/ 1000;
    final int ms = milliseconds % 1000;

    final hh = hours.toString().padLeft(2, '0');
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    final mmm = ms.toString().padLeft(3, '0');

    return '$hh:$mm:$ss,$mmm';
  }

  /// Converts milliseconds to VTT format: HH:MM:SS.mmm
  String _formatVttTimestamp(int milliseconds) {
    if (milliseconds < 0) milliseconds = 0;
    final int hours = milliseconds ~/ 3600000;
    final int minutes = (milliseconds % 3600000) ~/ 60000;
    final int seconds = (milliseconds % 60000) ~/ 1000;
    final int ms = milliseconds % 1000;

    final hh = hours.toString().padLeft(2, '0');
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    final mmm = ms.toString().padLeft(3, '0');

    return '$hh:$mm:$ss.$mmm';
  }
}
