import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../logging/app_logger.dart';
import '../data/settings_repository.dart';
import '../domain/app_settings_model.dart';

/// StateNotifier managing current AppSettings and saving updates.
class SettingsNotifier extends StateNotifier<AppSettingsModel> {
  final SettingsRepository _repository;

  SettingsNotifier(this._repository, [AppSettingsModel? initial])
      : super(initial ?? const AppSettingsModel());

  Future<void> updateTheme(String theme) async {
    state = state.copyWith(themeMode: theme);
    await _repository.saveSetting('theme_mode', theme);
    AppLogger.info('Theme mode updated to: $theme');
  }

  Future<void> updateLanguage(String lang) async {
    state = state.copyWith(language: lang);
    await _repository.saveSetting('language', lang);
    AppLogger.info('Language updated to: $lang');
  }

  Future<void> updateAutoStart(bool autoStart) async {
    state = state.copyWith(autoStartWithWindows: autoStart);
    await _repository.saveSetting('auto_start_with_windows', autoStart ? '1' : '0');
  }

  Future<void> updateWorkspacePath(String path) async {
    state = state.copyWith(customWorkspacePath: path);
    await _repository.saveSetting('custom_workspace_path', path);
    AppLogger.info('Custom workspace path updated to: $path');
  }

  Future<void> updateDeveloperMode(bool devMode) async {
    state = state.copyWith(developerMode: devMode);
    await _repository.saveSetting('developer_mode', devMode ? '1' : '0');
  }

  Future<void> completeFirstRun() async {
    state = state.copyWith(firstRunCompleted: true);
    await _repository.saveSetting('first_run_completed', '1');
    AppLogger.info('First run setup marked completed.');
  }

  Future<void> resetToDefaults() async {
    await _repository.resetSettings();
    state = const AppSettingsModel();
    AppLogger.info('Settings reset to defaults');
  }
}
