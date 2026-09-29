// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/features/text_to_speech/domain/models/tts_options.dart';
import 'package:nguyendu_tool/features/text_to_speech/domain/models/tts_request.dart';
import 'package:nguyendu_tool/features/text_to_speech/infrastructure/audio_assembly_service.dart';
import 'package:nguyendu_tool/features/text_to_speech/infrastructure/windows_speech_synthesizer_provider.dart';

void main() {
  group('Real Local Windows SpeechSynthesizer Engine Integration Tests', () {
    late Directory tempDir;
    late WindowsSpeechSynthesizerProvider provider;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('tts_real_win_test_');
      provider = WindowsSpeechSynthesizerProvider();
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('Discovers real installed Windows voices on host OS', () async {
      if (!Platform.isWindows) return;

      final isAvailable = await provider.initialize();
      final voices = await provider.getVoices();

      print('Real Windows Voices Discovered: ${voices.length}');
      for (final v in voices) {
        print(' - [${v.providerId}] ${v.name} (${v.language}, ${v.gender}, isLocal=${v.isLocal})');
      }

      expect(isAvailable, isTrue);
      expect(voices, isNotEmpty);

      // Honest verification of Vietnamese voice presence (Req 9, Req 43)
      final hasVi = provider.hasVietnameseVoice;
      if (!hasVi) {
        print('VIETNAMESE_LOCAL_VOICE = NOT_AVAILABLE (Honest host report)');
      } else {
        print('VIETNAMESE_LOCAL_VOICE = AVAILABLE');
      }
    });

    test('Synthesizes real authentic PCM WAV audio using installed Windows voice', () async {
      if (!Platform.isWindows) return;

      await provider.initialize();
      final voices = await provider.getVoices();
      if (voices.isEmpty) {
        markTestSkipped('No installed Windows voice available on host.');
        return;
      }

      // Pick first installed voice (e.g. Microsoft Hazel / Zira)
      final testVoice = voices.first;
      final outPath = '${tempDir.path}/real_synthesized_${testVoice.name.replaceAll(" ", "_")}.wav';

      final request = TtsRequest(
        text: 'Hello, this is a real speech synthesis test from NguyenDu Tool on Windows desktop.',
        voice: testVoice,
        options: const TtsOptions(speed: 1.0, format: TtsAudioFormat.wav),
        outputPath: outPath,
      );

      final generatedPath = await provider.synthesize(request);
      final audioFile = File(generatedPath);

      expect(audioFile.existsSync(), isTrue);
      expect(audioFile.lengthSync(), greaterThan(1000)); // Genuine audio bytes

      // Validate through AudioAssemblyService QA engine
      final assemblyService = AudioAssemblyService();
      final report = await assemblyService.validateAudio(generatedPath, TtsAudioFormat.wav);

      expect(report.isValid, isTrue);
      expect(report.durationSeconds, greaterThan(1.0));
      expect(report.channels, greaterThanOrEqualTo(1));
      print('Real audio synthesized successfully: $generatedPath (${audioFile.lengthSync()} bytes, ${report.durationSeconds?.toStringAsFixed(2)}s)');
    });
  });
}
