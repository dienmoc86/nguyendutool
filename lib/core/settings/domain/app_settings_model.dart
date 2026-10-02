/// Holds application settings and user preferences.
class AppSettingsModel {
  final String language; // 'vi' or 'en'
  final String themeMode; // 'system', 'light', 'dark'
  final bool autoStartWithWindows;
  final String customWorkspacePath;
  final bool developerMode;
  final bool telemetryEnabled;
  final bool firstRunCompleted;
  final bool autoCheckUpdates;
  final bool autoInstallUpdates;
  final String customUpdateManifestUrl;

  const AppSettingsModel({
    this.language = 'vi',
    this.themeMode = 'dark',
    this.autoStartWithWindows = false,
    this.customWorkspacePath = '',
    this.developerMode = false,
    this.telemetryEnabled = false,
    this.firstRunCompleted = false,
    this.autoCheckUpdates = true,
    this.autoInstallUpdates = false,
    this.customUpdateManifestUrl = '',
  });

  AppSettingsModel copyWith({
    String? language,
    String? themeMode,
    bool? autoStartWithWindows,
    String? customWorkspacePath,
    bool? developerMode,
    bool? telemetryEnabled,
    bool? firstRunCompleted,
    bool? autoCheckUpdates,
    bool? autoInstallUpdates,
    String? customUpdateManifestUrl,
  }) {
    return AppSettingsModel(
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      autoStartWithWindows: autoStartWithWindows ?? this.autoStartWithWindows,
      customWorkspacePath: customWorkspacePath ?? this.customWorkspacePath,
      developerMode: developerMode ?? this.developerMode,
      telemetryEnabled: telemetryEnabled ?? this.telemetryEnabled,
      firstRunCompleted: firstRunCompleted ?? this.firstRunCompleted,
      autoCheckUpdates: autoCheckUpdates ?? this.autoCheckUpdates,
      autoInstallUpdates: autoInstallUpdates ?? this.autoInstallUpdates,
      customUpdateManifestUrl: customUpdateManifestUrl ?? this.customUpdateManifestUrl,
    );
  }

  Map<String, String> toKeyValues() {
    return {
      'language': language,
      'theme_mode': themeMode,
      'auto_start_with_windows': autoStartWithWindows ? '1' : '0',
      'custom_workspace_path': customWorkspacePath,
      'developer_mode': developerMode ? '1' : '0',
      'telemetry_enabled': telemetryEnabled ? '1' : '0',
      'first_run_completed': firstRunCompleted ? '1' : '0',
      'auto_check_updates': autoCheckUpdates ? '1' : '0',
      'auto_install_updates': autoInstallUpdates ? '1' : '0',
      'custom_update_manifest_url': customUpdateManifestUrl,
    };
  }

  factory AppSettingsModel.fromKeyValues(Map<String, String> map) {
    return AppSettingsModel(
      language: map['language'] ?? 'vi',
      themeMode: map['theme_mode'] ?? 'dark',
      autoStartWithWindows: map['auto_start_with_windows'] == '1',
      customWorkspacePath: map['custom_workspace_path'] ?? '',
      developerMode: map['developer_mode'] == '1',
      telemetryEnabled: map['telemetry_enabled'] == '1',
      firstRunCompleted: map['first_run_completed'] == '1',
      autoCheckUpdates: map['auto_check_updates'] != '0', // Default true
      autoInstallUpdates: map['auto_install_updates'] == '1',
      customUpdateManifestUrl: map['custom_update_manifest_url'] ?? '',
    );
  }
}
