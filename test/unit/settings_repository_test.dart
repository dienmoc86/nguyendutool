import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/database/app_database.dart';
import 'package:nguyendu_tool/core/settings/data/settings_repository.dart';
import 'package:nguyendu_tool/core/settings/domain/app_settings_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  late SettingsRepository settingsRepository;

  setUp(() async {
    database = AppDatabase(inMemory: true);
    await database.init();
    settingsRepository = SettingsRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('SettingsRepository Tests', () {
    test('Loads default settings when database table is initially empty', () async {
      final settings = await settingsRepository.loadSettings();

      expect(settings.language, 'vi');
      expect(settings.themeMode, 'dark');
      expect(settings.autoStartWithWindows, isFalse);
      expect(settings.developerMode, isFalse);
    });

    test('Saves and loads individual setting', () async {
      await settingsRepository.saveSetting('theme_mode', 'light');
      await settingsRepository.saveSetting('language', 'en');

      final settings = await settingsRepository.loadSettings();
      expect(settings.themeMode, 'light');
      expect(settings.language, 'en');
    });

    test('Saves all settings model and reloads them accurately', () async {
      const newSettings = AppSettingsModel(
        language: 'en',
        themeMode: 'light',
        autoStartWithWindows: true,
        customWorkspacePath: 'D:\\TestWorkspace',
        developerMode: true,
        telemetryEnabled: false,
      );

      await settingsRepository.saveAllSettings(newSettings);
      final loaded = await settingsRepository.loadSettings();

      expect(loaded.language, 'en');
      expect(loaded.themeMode, 'light');
      expect(loaded.autoStartWithWindows, isTrue);
      expect(loaded.customWorkspacePath, 'D:\\TestWorkspace');
      expect(loaded.developerMode, isTrue);
    });

    test('Resets settings to defaults', () async {
      await settingsRepository.saveSetting('theme_mode', 'light');
      await settingsRepository.resetSettings();

      final reloaded = await settingsRepository.loadSettings();
      expect(reloaded.themeMode, 'dark');
    });
  });
}
