import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/ai/ai_model_config.dart';
import 'package:nguyendu_tool/core/capabilities/app_capability.dart';
import 'package:nguyendu_tool/core/capabilities/capability_availability.dart';
import 'package:nguyendu_tool/core/capabilities/capability_registry.dart';
import 'package:path/path.dart' as p;

void main() {
  group('AI Capability & Model Source Audit Tests (Phase 6B-R)', () {
    test('OpenAI capability is explicitly marked unavailable (no false availability)', () {
      final reg = CapabilityRegistry.instance;
      final openAiCap = reg.getCapability(CapabilityRegistry.capAiOpenAiTextGenerate);

      expect(openAiCap, isNotNull);
      expect(openAiCap!.availability, equals(CapabilityAvailability.unavailable));
      expect(openAiCap.isAvailable, isFalse);
      expect(openAiCap.reason, contains('Chưa hỗ trợ kết nối OpenAI'));
    });

    test('ai.text.generate capability is NOT available when Gemini is not configured', () {
      final reg = CapabilityRegistry.instance;
      reg.setCapability(const AppCapability(
        id: CapabilityRegistry.capAiGeminiTextGenerate,
        displayName: 'Google Gemini AI',
        description: 'Gemini',
        availability: CapabilityAvailability.notConfigured,
      ));
      reg.setCapability(const AppCapability(
        id: CapabilityRegistry.capAiOpenAiTextGenerate,
        displayName: 'OpenAI',
        description: 'OpenAI',
        availability: CapabilityAvailability.unavailable,
      ));
      reg.setCapability(const AppCapability(
        id: CapabilityRegistry.capAiTextGenerate,
        displayName: 'AI Text Generate',
        description: 'AI Text Generate',
        availability: CapabilityAvailability.notConfigured,
      ));

      expect(reg.isAvailable(CapabilityRegistry.capAiOpenAiTextGenerate), isFalse);
      expect(reg.isAvailable(CapabilityRegistry.capAiTextGenerate), isFalse);
    });

    test('ai.text.generate capability becomes available only when implemented Gemini is available', () {
      final reg = CapabilityRegistry.instance;
      reg.setCapability(const AppCapability(
        id: CapabilityRegistry.capAiGeminiTextGenerate,
        displayName: 'Google Gemini AI',
        description: 'Gemini',
        availability: CapabilityAvailability.available,
      ));
      reg.setCapability(const AppCapability(
        id: CapabilityRegistry.capAiTextGenerate,
        displayName: 'AI Text Generate',
        description: 'AI Text Generate',
        availability: CapabilityAvailability.available,
      ));

      expect(reg.isAvailable(CapabilityRegistry.capAiGeminiTextGenerate), isTrue);
      expect(reg.isAvailable(CapabilityRegistry.capAiTextGenerate), isTrue);
      expect(reg.isAvailable(CapabilityRegistry.capAiOpenAiTextGenerate), isFalse);
    });

    test('Automated Audit: Production lib/ contains NO hardcoded Gemini model IDs outside AiModelConfig', () {
      final libDir = Directory(p.join(Directory.current.path, 'lib'));
      expect(libDir.existsSync(), isTrue);

      final modelNames = ['gemini-1.5-flash', 'gemini-1.5-pro', 'gemini-2.0-flash'];
      final violations = <String>[];

      for (final file in libDir.listSync(recursive: true)) {
        if (file is File && file.path.endsWith('.dart')) {
          final normalizedPath = p.normalize(file.path);
          if (normalizedPath.endsWith('ai_model_config.dart')) {
            continue; // AiModelConfig is the single source of truth
          }

          final content = file.readAsStringSync();
          for (final model in modelNames) {
            if (content.contains("'$model'") || content.contains('"$model"')) {
              violations.add('${file.path} contains hardcoded literal "$model"');
            }
          }
        }
      }

      expect(violations, isEmpty, reason: 'Found hardcoded AI model strings in lib/: \n${violations.join('\n')}');
    });

    test('AiModelConfig provides defaultModel and availableModels', () {
      expect(AiModelConfig.defaultModel, equals('gemini-1.5-flash'));
      expect(AiModelConfig.availableModels, contains('gemini-1.5-flash'));
      expect(AiModelConfig.availableModels, contains('gemini-1.5-pro'));
      expect(AiModelConfig.supportedModels, contains('gemini-1.5-flash'));
    });
  });
}
