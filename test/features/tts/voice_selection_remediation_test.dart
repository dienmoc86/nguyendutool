import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/errors/app_exceptions.dart';
import 'package:nguyendu_tool/features/text_to_speech/domain/models/tts_options.dart';
import 'package:nguyendu_tool/features/text_to_speech/domain/models/tts_request.dart';
import 'package:nguyendu_tool/features/text_to_speech/domain/models/tts_voice.dart';
import 'package:nguyendu_tool/features/text_to_speech/domain/models/tts_voice_engine.dart';
import 'package:nguyendu_tool/features/text_to_speech/infrastructure/windows_speech_synthesizer_provider.dart';

void main() {
  group('TTS Voice Selection Remediation Tests', () {
    late WindowsSpeechSynthesizerProvider provider;

    setUp(() {
      provider = WindowsSpeechSynthesizerProvider();
    });

    tearDown(() async {
      await provider.dispose();
    });

    test('Discovers both SAPI and OneCore voices with explicit TtsVoiceEngine tag', () async {
      if (!Platform.isWindows) return;

      final isAvail = await provider.initialize();
      expect(isAvail, isTrue);

      final voices = await provider.getVoices();
      expect(voices, isNotEmpty);

      // Verify that every voice has explicit engine tag
      for (final v in voices) {
        expect(v.engine, isNotNull);
        expect(
          v.engine == TtsVoiceEngine.sapi || v.engine == TtsVoiceEngine.oneCore,
          isTrue,
          reason: 'Voice ${v.name} must have explicit engine sapi or oneCore',
        );
      }

      final sapiVoices = voices.where((v) => v.engine == TtsVoiceEngine.sapi).toList();
      final oneCoreVoices = voices.where((v) => v.engine == TtsVoiceEngine.oneCore).toList();

      expect(sapiVoices, isNotEmpty, reason: 'Must discover SAPI desktop voices');
      expect(oneCoreVoices, isNotEmpty, reason: 'Must discover OneCore voices');
    });

    test('Synthesizes audio using SAPI voice when SAPI voice is requested', () async {
      if (!Platform.isWindows) return;

      await provider.initialize();
      final voices = await provider.getVoices();
      final sapiVoice = voices.firstWhere((v) => v.engine == TtsVoiceEngine.sapi);

      final tempDir = await Directory.systemTemp.createTemp('sapi_sel_test_');
      try {
        final outPath = '${tempDir.path}/sapi_output.wav';
        final result = await provider.synthesize(
          TtsRequest(
            text: 'Testing SAPI voice synthesis selection strictly.',
            voice: sapiVoice,
            options: const TtsOptions(speed: 1.0, volume: 1.0),
            outputPath: outPath,
          ),
        );

        final file = File(result);
        expect(file.existsSync(), isTrue);
        expect(file.lengthSync(), greaterThan(1000));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('Synthesizes audio using OneCore voice when OneCore voice is requested', () async {
      if (!Platform.isWindows) return;

      await provider.initialize();
      final voices = await provider.getVoices();
      final oneCoreVoice = voices.firstWhere((v) => v.engine == TtsVoiceEngine.oneCore);

      final tempDir = await Directory.systemTemp.createTemp('onecore_sel_test_');
      try {
        final outPath = '${tempDir.path}/onecore_output.wav';
        final result = await provider.synthesize(
          TtsRequest(
            text: 'Testing genuine OneCore voice synthesis selection strictly.',
            voice: oneCoreVoice,
            options: const TtsOptions(speed: 1.0, volume: 1.0),
            outputPath: outPath,
          ),
        );

        final file = File(result);
        expect(file.existsSync(), isTrue);
        expect(file.lengthSync(), greaterThan(1000));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('Throws TtsVoiceUnavailableException when requested voice does not exist on system', () async {
      if (!Platform.isWindows) return;

      await provider.initialize();

      const nonExistentVoice = TtsVoice(
        id: 'NonExistent_Ghost_Voice_12345',
        name: 'NonExistent_Ghost_Voice_12345',
        language: 'vi-VN',
        locale: 'vi-VN',
        gender: 'Female',
        providerId: 'windows_local',
        engine: TtsVoiceEngine.sapi,
      );

      final tempDir = await Directory.systemTemp.createTemp('ghost_voice_test_');
      try {
        final outPath = '${tempDir.path}/ghost_output.wav';

        expect(
          () => provider.synthesize(
            TtsRequest(
              text: 'This should fail immediately without silent fallback.',
              voice: nonExistentVoice,
              options: const TtsOptions(speed: 1.0, volume: 1.0),
              outputPath: outPath,
            ),
          ),
          throwsA(
            isA<TtsVoiceUnavailableException>().having(
              (e) => e.message,
              'message',
              contains('Không thể sử dụng giọng đã chọn trên máy này.'),
            ),
          ),
        );
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('Provider capabilities accurately report timing and SSML flags', () {
      final info = provider.info;
      expect(info.supportsSsml, isFalse, reason: 'supportsSsml must be false because local engine processes plain text');
      expect(info.supportsWordTiming, isFalse, reason: 'supportsWordTiming must be false because exact engine word boundaries are not streamed');
      expect(info.supportsSentenceTiming, isFalse);
      expect(info.supportsChunkTiming, isTrue, reason: 'supportsChunkTiming is true from chunk PCM duration');
    });
  });
}
