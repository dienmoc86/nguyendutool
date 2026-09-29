import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/features/text_to_speech/domain/models/tts_timing_segment.dart';
import 'package:nguyendu_tool/features/text_to_speech/infrastructure/subtitle_generator.dart';

void main() {
  group('SubtitleGenerator (SRT & VTT) Tests', () {
    const generator = SubtitleGenerator();
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('tts_subtitles_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    final testSegments = [
      const TtsTimingSegment(
        index: 1,
        startMs: 1000,
        endMs: 3500,
        text: 'Kính chào quý thầy cô và các em học sinh.',
      ),
      const TtsTimingSegment(
        index: 2,
        startMs: 4000,
        endMs: 7250,
        text: 'Hôm nay chúng ta cùng tìm hiểu về nhà thơ Nguyễn Du.',
      ),
    ];

    test('Generates valid SRT format with comma millisecond separator', () {
      final srt = generator.generateSrt(testSegments);

      expect(srt, contains('1\n00:00:01,000 --> 00:00:03,500\nKính chào quý thầy cô và các em học sinh.'));
      expect(srt, contains('2\n00:00:04,000 --> 00:00:07,250\nHôm nay chúng ta cùng tìm hiểu về nhà thơ Nguyễn Du.'));
    });

    test('Generates valid WebVTT format with WEBVTT header and dot separator', () {
      final vtt = generator.generateVtt(testSegments);

      expect(vtt, startsWith('WEBVTT\n\n'));
      expect(vtt, contains('1\n00:00:01.000 --> 00:00:03.500\nKính chào quý thầy cô và các em học sinh.'));
      expect(vtt, contains('2\n00:00:04.000 --> 00:00:07.250\nHôm nay chúng ta cùng tìm hiểu về nhà thơ Nguyễn Du.'));
    });

    test('Exports SRT and VTT to files in UTF-8 encoding', () async {
      final srtFile = '${tempDir.path}/test.srt';
      final vttFile = '${tempDir.path}/test.vtt';

      await generator.exportSrtToFile(testSegments, srtFile);
      await generator.exportVttToFile(testSegments, vttFile);

      expect(File(srtFile).existsSync(), isTrue);
      expect(File(vttFile).existsSync(), isTrue);

      final readSrt = await File(srtFile).readAsString();
      expect(readSrt, contains('Nguyễn Du'));

      final readVtt = await File(vttFile).readAsString();
      expect(readVtt, startsWith('WEBVTT'));
    });

    test('Handles empty segments gracefully', () {
      expect(generator.generateSrt([]), equals(''));
      expect(generator.generateVtt([]), equals('WEBVTT\n\n'));
    });
  });
}
