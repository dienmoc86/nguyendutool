import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/features/text_to_speech/domain/models/tts_voice_engine.dart';
import 'package:nguyendu_tool/features/text_to_speech/infrastructure/piper_tts_provider.dart';
import 'package:nguyendu_tool/features/video_studio/domain/models/ai_video_generation_request.dart';
import 'package:nguyendu_tool/features/video_studio/infrastructure/open_sora_video_service.dart';

void main() {
  group('Piper TTS & Open-Sora Integration Tests', () {
    test('PiperTtsProvider reports correct offline AI capabilities and voices', () async {
      final provider = PiperTtsProvider();
      expect(provider.id, equals('piper_tts'));
      expect(provider.info.isOffline, isTrue);
      expect(provider.info.name, contains('Piper TTS Cục Bộ'));

      final initialized = await provider.initialize();
      expect(initialized, isTrue);

      final voices = await provider.getVoices();
      expect(voices, isNotEmpty);
      expect(voices.length, equals(3));

      final thanhHa = voices.firstWhere((v) => v.id == 'vi_VN-25hours-single');
      expect(thanhHa.isOffline, isTrue);
      expect(thanhHa.engine, equals(TtsVoiceEngine.piper));
      expect(thanhHa.displayName, contains('Piper AI'));
      expect(thanhHa.displayName, contains('[Cục bộ]'));
    });

    test('AiVideoGenerationRequest serializes correctly for Open-Sora backend', () {
      const request = AiVideoGenerationRequest(
        prompt: 'Thí nghiệm Hóa học đổi màu ống nghiệm',
        durationSeconds: 5.0,
        aspectRatio: '16:9',
        resolution: '720p',
      );

      final json = request.toJson();
      expect(json['prompt'], equals('Thí nghiệm Hóa học đổi màu ống nghiệm'));
      expect(json['duration_seconds'], equals(5.0));
      expect(json['backend'], equals('openSora'));
      expect(json['aspect_ratio'], equals('16:9'));
    });

    test('OpenSoraVideoService connection test handles offline endpoint gracefully', () async {
      final service = OpenSoraVideoService.instance;
      // An invalid or offline port should return false and not throw unhandled exception
      final isOnline = await service.testConnection('http://127.0.0.1:59999');
      expect(isOnline, isFalse);
    });
  });
}
