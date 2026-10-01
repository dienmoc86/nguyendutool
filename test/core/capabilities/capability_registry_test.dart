import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/capabilities/app_capability.dart';
import 'package:nguyendu_tool/core/capabilities/capability_availability.dart';
import 'package:nguyendu_tool/core/capabilities/capability_registry.dart';

void main() {
  group('CapabilityRegistry Tests (Phase 6B)', () {
    late CapabilityRegistry registry;

    setUp(() {
      registry = CapabilityRegistry.instance;
    });

    test('Initial states reflect honest static vs runtime probes (Remediation 0.2)', () {
      // Bundled offline static engines are available immediately
      expect(registry.isAvailable('document.pdf.read'), isTrue);
      expect(registry.isAvailable('document.pdf.write'), isTrue);
      expect(registry.isAvailable('document.docx.write'), isTrue);
      expect(registry.isAvailable('document.xlsx.write'), isTrue);

      // Dynamic / hardware / system capabilities start as unknown or notConfigured
      final ocrCap = registry.getCapability('document.ocr');
      final ttsCap = registry.getCapability('media.tts');
      final wiaCap = registry.getCapability('scanner.wia');
      final dpapiCap = registry.getCapability('security.dpapi');
      final ffmpegCap = registry.getCapability('media.ffmpeg');
      final aiCap = registry.getCapability('ai.text.generate');

      expect(ocrCap?.availability, equals(CapabilityAvailability.unknown));
      expect(ttsCap?.availability, equals(CapabilityAvailability.unknown));
      expect(wiaCap?.availability, equals(CapabilityAvailability.unknown));
      expect(dpapiCap?.availability, equals(CapabilityAvailability.unknown));
      expect(ffmpegCap?.availability, equals(CapabilityAvailability.unknown));
      expect(aiCap?.availability, equals(CapabilityAvailability.notConfigured));
    });

    test('Granular capabilities exist alongside backward compatible aliases (Remediation 0.4)', () {
      expect(registry.getCapability('scanner.wia.service'), isNotNull);
      expect(registry.getCapability('scanner.wia.device'), isNotNull);
      expect(registry.getCapability('scanner.wia'), isNotNull);

      expect(registry.getCapability('media.tts.engine'), isNotNull);
      expect(registry.getCapability('media.tts.vi_voice'), isNotNull);
      expect(registry.getCapability('media.tts'), isNotNull);

      expect(registry.getCapability('document.ocr.engine'), isNotNull);
      expect(registry.getCapability('document.ocr.vi_language'), isNotNull);
      expect(registry.getCapability('document.ocr'), isNotNull);

      expect(registry.getCapability('security.dpapi'), isNotNull);
    });

    test('AI capability is honestly notConfigured without API key', () {
      final aiCap = registry.getCapability('ai.text.generate');
      expect(aiCap, isNotNull);
      expect(aiCap!.availability, equals(CapabilityAvailability.notConfigured));
      expect(aiCap.isAvailable, isFalse);
      expect(aiCap.reason, contains('Cài đặt'));
    });

    test('Probe enforcement: no scanner device != scanner device available (Section 52)', () {
      // Simulate no scanner device
      registry.setCapability(const AppCapability(
        id: 'scanner.wia.device',
        displayName: 'Thiết bị Máy quét',
        description: 'Máy quét',
        availability: CapabilityAvailability.unavailable,
        provider: 'WIA Device Manager',
        reason: 'Chưa phát hiện thiết bị máy quét',
      ));

      expect(registry.isAvailable('scanner.wia.device'), isFalse);
      expect(registry.getCapability('scanner.wia.device')?.availability,
          equals(CapabilityAvailability.unavailable));
    });

    test('Probe enforcement: no Vietnamese voice != Vietnamese voice available (Section 52)', () {
      // Simulate system with SAPI engine but no Vietnamese voice installed
      registry.setCapability(const AppCapability(
        id: 'media.tts.vi_voice',
        displayName: 'Giọng đọc Tiếng Việt',
        description: 'Giọng tiếng Việt',
        availability: CapabilityAvailability.notConfigured,
        provider: 'Windows SAPI / OneCore Vietnamese Voice',
        reason: 'Chưa cài đặt giọng Tiếng Việt',
      ));

      expect(registry.isAvailable('media.tts.vi_voice'), isFalse);
    });

    test('refreshAll completes asynchronously without throwing', () async {
      await expectLater(registry.refreshAll(), completes);
      final caps = registry.listCapabilities();
      expect(caps.length, greaterThanOrEqualTo(14));

      // On Windows development machine, DPAPI and FFmpeg should probe to available
      if (Platform.isWindows) {
        expect(registry.isAvailable('security.dpapi'), isTrue);
        expect(registry.isAvailable('media.ffmpeg'), isTrue);
      }
    });
  });
}
