/// Holds application settings and user preferences.
class AppSettingsModel {
  final String language; // 'vi' or 'en'
  final String themeMode; // 'system', 'light', 'dark'
  final bool autoStartWithWindows;
  final String customWorkspacePath;
  final bool developerMode;
  final bool telemetryEnabled;
  final bool firstRunCompleted;

  const AppSettingsModel({
    this.language = 'vi',
    this.themeMode = 'dark',
    this.autoStartWithWindows = false,
    this.customWorkspacePath = '',
    this.developerMode = false,
    this.telemetryEnabled = false,
    this.firstRunCompleted = false,
  });

  AppSettingsModel copyWith({
    String? language,
    String? themeMode,
    bool? autoStartWithWindows,
    String? customWorkspacePath,
    bool? developerMode,
    bool? telemetryEnabled,
    bool? firstRunCompleted,
  }) {
    return AppSettingsModel(
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      autoStartWithWindows: autoStartWithWindows ?? this.autoStartWithWindows,
      customWorkspacePath: customWorkspacePath ?? this.customWorkspacePath,
      developerMode: developerMode ?? this.developerMode,
      telemetryEnabled: telemetryEnabled ?? this.telemetryEnabled,
      firstRunCompleted: firstRunCompleted ?? this.firstRunCompleted,
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
    );
  }
}
