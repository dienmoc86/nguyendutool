import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/errors/app_exceptions.dart';
import 'package:nguyendu_tool/core/providers/ai_provider.dart';
import 'package:nguyendu_tool/core/providers/base_provider.dart';
import 'package:nguyendu_tool/core/providers/provider_registry.dart';
import 'package:nguyendu_tool/core/providers/tts_provider.dart';

void main() {
  late ProviderRegistry registry;

  setUp(() {
    registry = ProviderRegistry();
  });

  group('ProviderRegistry Tests', () {
    test('Default providers are populated', () {
      final providers = registry.listProviders();
      expect(providers, isNotEmpty);
      expect(providers.any((p) => p.id == 'gemini'), isTrue);
      expect(providers.any((p) => p.id == 'google_tts'), isTrue);
      expect(providers.any((p) => p.id == 'windows_ocr'), isTrue);
    });

    test('Can query providers by category', () {
      final aiProviders = registry.getProvidersByCategory<AiProvider>(ProviderCategory.ai);
      expect(aiProviders, isNotEmpty);
      expect(aiProviders.every((p) => p.category == ProviderCategory.ai), isTrue);

      final ttsProviders = registry.getProvidersByCategory<TtsProvider>(ProviderCategory.tts);
      expect(ttsProviders, isNotEmpty);
      expect(ttsProviders.every((p) => p.category == ProviderCategory.tts), isTrue);
    });

    test('Enables and disables implemented providers correctly', () {
      final initial = registry.getProviderById('google_tts');
      expect(initial, isNotNull);
      // Requirement 7: Cloud providers must default to disabled
      expect(initial!.isEnabled, isFalse);

      registry.enableProvider('google_tts');
      expect(registry.getProviderById('google_tts')!.isEnabled, isTrue);

      registry.disableProvider('google_tts');
      expect(registry.getProviderById('google_tts')!.isEnabled, isFalse);
    });

    test('Prevents enabling unimplemented placeholder providers (Requirement 5)', () {
      expect(() => registry.enableProvider('gemini'), throwsA(isA<ProviderException>()));
      expect(() => registry.enableProvider('openai'), throwsA(isA<ProviderException>()));
      expect(() => registry.enableProvider('google_veo'), throwsA(isA<ProviderException>()));
    });

    test('Filters only active providers', () {
      // Initially local TTS is active, cloud TTS is not
      var activeTts = registry.getActiveProvidersByCategory<TtsProvider>(ProviderCategory.tts);
      expect(activeTts.any((p) => p.id == 'windows_local'), isTrue);
      expect(activeTts.any((p) => p.id == 'google_tts'), isFalse);

      // Enable google_tts and verify it appears in active providers
      registry.enableProvider('google_tts');
      activeTts = registry.getActiveProvidersByCategory<TtsProvider>(ProviderCategory.tts);
      expect(activeTts.any((p) => p.id == 'google_tts'), isTrue);
      expect(activeTts.any((p) => p.id == 'windows_local'), isTrue);
    });
  });
}
