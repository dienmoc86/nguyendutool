import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/update/update_notifier.dart';
import 'package:nguyendu_tool/core/update/update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UpdateNotifier Tests', () {
    late Directory tempDir;
    late UpdateService updateService;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('update_notifier_test_');
      updateService = UpdateService(
        currentVersion: '1.5.1',
        currentBuild: 8,
        isTestMode: true,
      );
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('Initial state is idle', () {
      final notifier = UpdateNotifier(updateService);
      expect(notifier.state.status, equals(UpdateStatus.initial));
      expect(notifier.state.isAvailable, isFalse);
      expect(notifier.state.isDownloading, isFalse);
    });

    test('Dismiss updates userDismissed flag', () {
      final notifier = UpdateNotifier(updateService);
      expect(notifier.state.userDismissed, isFalse);
      notifier.dismiss();
      expect(notifier.state.userDismissed, isTrue);
    });

    test('SemVer compare accurately identifies upgrades', () {
      expect(UpdateService.compareSemVer('1.5.2', '1.5.1'), greaterThan(0));
      expect(UpdateService.compareSemVer('1.5.1', '1.5.1'), equals(0));
      expect(UpdateService.compareSemVer('1.5.0', '1.5.1'), lessThan(0));
      expect(UpdateService.compareSemVer('2.0.0', '1.9.9'), greaterThan(0));
    });

    test('Handles update check with mock manifest successfully', () async {
      final notifier = UpdateNotifier(updateService);

      final manifestJson = jsonEncode({
        'version': '1.5.2',
        'build': 9,
        'installerUrl': 'https://github.com/dienmoc86/nguyendutool/releases/download/v1.5.2/NguyenDuTool_Setup_1.5.2.exe',
        'sha256': 'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855',
        'releaseNotes': 'Bản cập nhật tính năng tự động cập nhật phần mềm.',
      });

      final checkResult = await updateService.checkForUpdates(manifestJsonString: manifestJson);
      expect(checkResult.isUpdateAvailable, isTrue);
      expect(checkResult.manifest!.version, equals('1.5.2'));
    });
  });
}
