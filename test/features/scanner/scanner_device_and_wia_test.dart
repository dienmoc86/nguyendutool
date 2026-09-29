import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/features/scanner/domain/models/scan_profile.dart';
import 'package:nguyendu_tool/features/scanner/domain/models/scanner_device.dart';
import 'package:nguyendu_tool/features/scanner/infrastructure/windows_wia_scanner_provider.dart';

void main() {
  group('ScannerDevice & Capabilities', () {
    test('ScannerCapability parses DPIs, color modes and ADF flags accurately', () {
      const cap = ScannerCapability(
        supportedDpis: [150, 300, 600],
        supportedColorModes: ['color', 'grayscale', 'bw'],
        supportsFlatbed: true,
        supportsAdf: true,
        supportsDuplex: false,
        supportedPaperSizes: ['A4', 'Letter'],
      );

      final json = cap.toJson();
      final restored = ScannerCapability.fromJson(json);

      expect(restored.supportedDpis, equals([150, 300, 600]));
      expect(restored.supportsAdf, isTrue);
      expect(restored.supportsDuplex, isFalse);
      expect(restored.supportedPaperSizes, equals(['A4', 'Letter']));
    });

    test('ScannerDevice serializes and formats toString correctly', () {
      const dev = ScannerDevice(
        id: 'wia_{1234}',
        name: 'HP LaserJet Pro MFP',
        manufacturer: 'HP',
        connectionType: 'USB',
      );

      expect(dev.toString(), contains('HP LaserJet Pro MFP'));
      expect(dev.toString(), contains('USB'));

      final json = dev.toJson();
      final restored = ScannerDevice.fromJson(json);
      expect(restored.id, equals('wia_{1234}'));
      expect(restored.manufacturer, equals('HP'));
    });
  });

  group('ScanProfile Presets', () {
    test('Default presets conform to specification requirements', () {
      expect(ScanProfile.defaultProfiles.length, equals(5));

      const ocrOpt = ScanProfile.ocrOptimized;
      expect(ocrOpt.dpi, equals(300));
      expect(ocrOpt.colorMode, equals('grayscale'));
      expect(ocrOpt.autoCrop, isTrue);
      expect(ocrOpt.deskew, isTrue);
      expect(ocrOpt.contrastNormalize, isTrue);

      const photo = ScanProfile.photo;
      expect(photo.dpi, equals(600));
      expect(photo.colorMode, equals('color'));
      expect(photo.autoCrop, isFalse);
      expect(photo.deskew, isFalse);
    });

    test('Custom profile JSON round-trip', () {
      const custom = ScanProfile(
        id: 'prof_test',
        name: 'Hồ sơ thử nghiệm',
        dpi: 200,
        colorMode: 'bw',
        source: 'adf',
        paperSize: 'letter',
        autoCrop: false,
        deskew: true,
        contrastNormalize: true,
      );

      final json = custom.toJson();
      final restored = ScanProfile.fromJson(json);
      expect(restored.id, equals('prof_test'));
      expect(restored.dpi, equals(200));
      expect(restored.source, equals('adf'));
    });
  });

  group('WindowsWiaScannerProvider - Discovery & No-Device handling', () {
    test('getAvailableScanners returns list without throwing even when no scanner attached', () async {
      final provider = WindowsWiaScannerProvider();
      final scanners = await provider.getAvailableScanners();

      // On this machine, 0 scanners connected. Result must be a list, never null or throwing.
      expect(scanners, isA<List<ScannerDevice>>());
    });

    test('queryCapabilities returns fallback capability for unknown device without crashing', () async {
      final provider = WindowsWiaScannerProvider();
      final cap = await provider.queryCapabilities('non_existent_device_id');
      expect(cap.supportedDpis, contains(300));
    });
  });
}
