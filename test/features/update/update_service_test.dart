import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:nguyendu_tool/core/update/update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late UpdateService updateService;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('update_test_');
    updateService = UpdateService(
      currentVersion: '1.5.0',
      currentBuild: 7,
    );
  });

  tearDown(() {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('Secure Update Service Tests', () {
    test('Correctly identifies when newer version is available', () async {
      final manifestJson = jsonEncode({
        'version': '1.5.1',
        'build': 8,
        'installerUrl': 'https://updates.nguyendu.edu.vn/releases/NguyenDuTool_Setup_1.5.1.exe',
        'sha256': 'ABC123DEF456',
        'releaseNotes': 'Bản cập nhật tối ưu hóa hiệu năng.',
      });

      final result = await updateService.checkForUpdates(manifestJsonString: manifestJson);
      expect(result.isUpdateAvailable, isTrue);
      expect(result.manifest, isNotNull);
      expect(result.manifest!.version, equals('1.5.1'));
    });

    test('Reports no update when manifest version is equal or older', () async {
      // Same version
      final sameJson = jsonEncode({
        'version': '1.5.0',
        'build': 7,
        'installerUrl': 'https://updates.nguyendu.edu.vn/releases/NguyenDuTool_Setup_1.5.0.exe',
        'sha256': 'ABC123DEF456',
      });
      final sameResult = await updateService.checkForUpdates(manifestJsonString: sameJson);
      expect(sameResult.isUpdateAvailable, isFalse);

      // Older version
      final olderJson = jsonEncode({
        'version': '1.4.0',
        'build': 6,
        'installerUrl': 'https://updates.nguyendu.edu.vn/releases/NguyenDuTool_Setup_1.4.0.exe',
        'sha256': 'ABC123DEF456',
      });
      final olderResult = await updateService.checkForUpdates(manifestJsonString: olderJson);
      expect(olderResult.isUpdateAvailable, isFalse);
    });

    test('Handles malformed manifest gracefully with typed error message', () async {
      const malformedJson = '{ "version": "1.5.1", invalid_json }';
      final result = await updateService.checkForUpdates(manifestJsonString: malformedJson);
      expect(result.isUpdateAvailable, isFalse);
      expect(result.errorMessage, isNotNull);
      expect(result.errorMessage!.contains('Lỗi kiểm tra cập nhật'), isTrue);
    });

    test('Rejects non-HTTPS remote manifest URL for security', () async {
      final result = await updateService.checkForUpdates(manifestUrl: 'http://insecure.example.com/manifest.json');
      expect(result.isUpdateAvailable, isFalse);
      expect(result.errorMessage!.contains('HTTPS'), isTrue);
    });

    test('Verifies valid binary SHA256 successfully', () async {
      final mockData = utf8.encode('GENUINE_WINDOWS_SETUP_BINARY_CONTENT_1.5.1');
      final expectedHash = crypto.sha256.convert(mockData).toString().toUpperCase();

      final manifest = UpdateManifest(
        version: '1.5.1',
        build: 8,
        installerUrl: 'https://updates.nguyendu.edu.vn/releases/NguyenDuTool_Setup_1.5.1.exe',
        sha256: expectedHash,
        releaseNotesUrl: '',
        releaseDate: DateTime.now(),
      );

      final downloadResult = await updateService.downloadAndVerifyInstaller(
        manifest,
        destinationDirectory: tempDir,
        mockDownloadedBytes: mockData,
      );

      expect(downloadResult.isSuccess, isTrue);
      expect(downloadResult.hashMismatch, isFalse);
      expect(downloadResult.actualSha256, equals(expectedHash));
      expect(downloadResult.downloadedInstaller, isNotNull);
      expect(await downloadResult.downloadedInstaller!.exists(), isTrue);
    });

    test('Detects SHA256 mismatch, immediately deletes file, and emits security warning', () async {
      final tamperedData = utf8.encode('TAMPERED_MALICIOUS_OR_CORRUPTED_BYTES');
      const expectedHash = 'FEEDFACECAFE1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234';

      final manifest = UpdateManifest(
        version: '1.5.1',
        build: 8,
        installerUrl: 'https://updates.nguyendu.edu.vn/releases/NguyenDuTool_Setup_1.5.1.exe',
        sha256: expectedHash,
        releaseNotesUrl: '',
        releaseDate: DateTime.now(),
      );

      final downloadResult = await updateService.downloadAndVerifyInstaller(
        manifest,
        destinationDirectory: tempDir,
        mockDownloadedBytes: tamperedData,
      );

      expect(downloadResult.isSuccess, isFalse);
      expect(downloadResult.hashMismatch, isTrue);
      expect(downloadResult.errorMessage!.contains('CẢNH BÁO BẢO MẬT'), isTrue);

      // Verify the file was completely deleted from disk
      final targetFile = File(p.join(tempDir.path, 'NguyenDuTool_Setup_1.5.1.exe'));
      expect(await targetFile.exists(), isFalse, reason: 'Tampered file must be immediately deleted');
    });
  });
}
