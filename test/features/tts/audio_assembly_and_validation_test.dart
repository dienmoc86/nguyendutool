import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/features/text_to_speech/domain/models/tts_options.dart';
import 'package:nguyendu_tool/features/text_to_speech/infrastructure/audio_assembly_service.dart';

void main() {
  group('AudioAssemblyService and Audio QA Validation Tests', () {
    late Directory tempDir;
    late AudioAssemblyService assemblyService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('tts_assembly_test_');
      assemblyService = AudioAssemblyService();
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    Uint8List createSynthesizedPcmWav({
      int sampleRate = 22050,
      int channels = 1,
      int durationMs = 500,
      double frequency = 440.0,
      bool isSilent = false,
    }) {
      final numSamples = (sampleRate * durationMs / 1000).round();
      final pcmBytes = Uint8List(numSamples * 2 * channels);
      final bd = ByteData.sublistView(pcmBytes);

      for (int i = 0; i < numSamples; i++) {
        final sampleVal = isSilent
            ? 0
            : (sin(2 * pi * frequency * i / sampleRate) * 16000).round().clamp(-32768, 32767);
        for (int ch = 0; ch < channels; ch++) {
          bd.setInt16((i * channels + ch) * 2, sampleVal, Endian.little);
        }
      }

      final header = Uint8List(44);
      final hBd = ByteData.sublistView(header);
      final byteRate = sampleRate * channels * 2;
      final blockAlign = channels * 2;
      final dataSize = pcmBytes.length;
      final chunkSize = 36 + dataSize;

      header.setRange(0, 4, 'RIFF'.codeUnits);
      hBd.setUint32(4, chunkSize, Endian.little);
      header.setRange(8, 12, 'WAVE'.codeUnits);
      header.setRange(12, 16, 'fmt '.codeUnits);
      hBd.setUint32(16, 16, Endian.little); // Subchunk1Size
      hBd.setUint16(20, 1, Endian.little); // PCM
      hBd.setUint16(22, channels, Endian.little);
      hBd.setUint32(24, sampleRate, Endian.little);
      hBd.setUint32(28, byteRate, Endian.little);
      hBd.setUint16(32, blockAlign, Endian.little);
      hBd.setUint16(34, 16, Endian.little); // 16-bit
      header.setRange(36, 40, 'data'.codeUnits);
      hBd.setUint32(40, dataSize, Endian.little);

      final fullWav = BytesBuilder();
      fullWav.add(header);
      fullWav.add(pcmBytes);
      return fullWav.toBytes();
    }

    test('Validates legitimate PCM WAV audio successfully', () async {
      final wavFile = File('${tempDir.path}/valid.wav');
      await wavFile.writeAsBytes(createSynthesizedPcmWav(durationMs: 400));

      final report = await assemblyService.validateAudio(wavFile.path, TtsAudioFormat.wav);
      expect(report.isValid, isTrue);
      expect(report.sampleRate, equals(22050));
      expect(report.channels, equals(1));
      expect(report.durationSeconds, greaterThan(0.3));
    });

    test('Detects and rejects all-silence audio (Silence QA check)', () async {
      final silentFile = File('${tempDir.path}/silent.wav');
      await silentFile.writeAsBytes(createSynthesizedPcmWav(isSilent: true, durationMs: 400));

      final report = await assemblyService.validateAudio(silentFile.path, TtsAudioFormat.wav);
      expect(report.isValid, isFalse);
      expect(report.errorMessage, contains('All-silence'));
    });

    test('Assembles multiple WAV chunks with pause insertion and valid timing', () async {
      final chunk1 = File('${tempDir.path}/chunk1.wav');
      final chunk2 = File('${tempDir.path}/chunk2.wav');
      await chunk1.writeAsBytes(createSynthesizedPcmWav(durationMs: 500, frequency: 440));
      await chunk2.writeAsBytes(createSynthesizedPcmWav(durationMs: 500, frequency: 554));

      final outputPath = '${tempDir.path}/output_assembled.wav';

      final result = await assemblyService.assembleAudio(
        chunkAudioPaths: [chunk1.path, chunk2.path],
        chunkTexts: ['Đoạn 1', 'Đoạn 2'],
        isParagraphBoundaries: [true, true],
        outputAudioPath: outputPath,
        options: const TtsOptions(format: TtsAudioFormat.wav, paragraphPauseMs: 300),
      );

      expect(File(outputPath).existsSync(), isTrue);
      expect(result.durationMs, greaterThan(1200)); // 500 + 300 + 500 = ~1300ms
      expect(result.timingSegments.length, equals(2));
      expect(result.timingSegments[0].startMs, equals(0));
      expect(result.timingSegments[1].startMs, greaterThan(result.timingSegments[0].endMs));
    });

    test('Validates MP3 with ID3 header correctly', () async {
      final mp3File = File('${tempDir.path}/sample.mp3');
      final mp3Bytes = BytesBuilder();
      // ID3v2 tag header: 'ID3' + version + flags + size
      mp3Bytes.add('ID3'.codeUnits);
      mp3Bytes.add([0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0A]);
      mp3Bytes.add(List.filled(500, 0xFF)); // Padding

      await mp3File.writeAsBytes(mp3Bytes.toBytes());

      final report = await assemblyService.validateAudio(mp3File.path, TtsAudioFormat.mp3);
      expect(report.isValid, isTrue);
    });
  });
}
