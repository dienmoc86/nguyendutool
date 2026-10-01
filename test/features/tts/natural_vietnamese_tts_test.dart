import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/providers/provider_registry.dart';
import 'package:nguyendu_tool/features/text_to_speech/application/tts_service.dart';
import 'package:nguyendu_tool/features/text_to_speech/infrastructure/natural_vietnamese_tts_provider.dart';

void main() {
  group('NaturalVietnameseTtsProvider Unit Tests', () {
    late NaturalVietnameseTtsProvider provider;

    setUp(() {
      provider = NaturalVietnameseTtsProvider();
    });

    test('Provider information and capabilities are correctly defined', () {
      expect(provider.id, equals('natural_vietnamese'));
      expect(provider.info.name, contains('AI Tiếng Việt'));
      expect(provider.info.isOffline, isFalse);
      expect(provider.info.isConfigured, isTrue);
      expect(provider.info.supportsMp3, isTrue);
      expect(provider.info.supportsWav, isTrue);
    });

    test('Discovers default high quality Vietnamese voices', () async {
      final voices = await provider.getVoices();
      expect(voices.length, equals(3));

      final hoaiMy = voices.firstWhere((v) => v.id == 'vi-VN-HoaiMyNeural');
      expect(hoaiMy.name, contains('Hoài My'));
      expect(hoaiMy.language, equals('vi-VN'));
      expect(hoaiMy.gender, equals('Female'));

      final namMinh = voices.firstWhere((v) => v.id == 'vi-VN-NamMinhNeural');
      expect(namMinh.name, contains('Nam Minh'));
      expect(namMinh.language, equals('vi-VN'));
      expect(namMinh.gender, equals('Male'));

      final banMai = voices.firstWhere((v) => v.id == 'vi-VN-BanMai');
      expect(banMai.name, contains('Ban Mai'));
      expect(banMai.language, equals('vi-VN'));
    });

    test('TtsService discovers Natural Vietnamese voices by default', () async {
      final ttsService = TtsService();
      final voices = await ttsService.getVoices(offlineOnly: false);

      final hasViVoice = voices.any((v) => v.language.toLowerCase().startsWith('vi'));
      expect(hasViVoice, isTrue);

      final viVoices = voices.where((v) => v.providerId == 'natural_vietnamese').toList();
      expect(viVoices.isNotEmpty, isTrue);
      expect(viVoices.any((v) => v.id == 'vi-VN-HoaiMyNeural'), isTrue);
      expect(viVoices.any((v) => v.id == 'vi-VN-NamMinhNeural'), isTrue);
    });

    test('NaturalVietnameseCoreTtsProvider is registered in ProviderRegistry', () {
      final registry = ProviderRegistry();
      final provider = registry.getProviderById('natural_vietnamese');
      expect(provider, isNotNull);
      expect(provider!.name, contains('AI Tiếng Việt'));
      expect(provider.isEnabled, isTrue);
    });
  });
}
