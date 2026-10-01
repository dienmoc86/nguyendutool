import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Local-only feature flag service for controlling experimental modules and features.
/// Strictly local, zero telemetry, zero remote network calls.
class FeatureFlagService {
  static final FeatureFlagService instance = FeatureFlagService._internal();

  static const String flagExperimentalModules = 'enable_experimental_modules';
  static const String flagDeveloperMode = 'enable_developer_mode';
  static const String flagRoadmapPreview = 'enable_roadmap_preview';
  static const String flagCommandPalette = 'enable_command_palette';

  final Map<String, bool> _flags = {
    flagExperimentalModules: false,
    flagDeveloperMode: false,
    flagRoadmapPreview: true,
    flagCommandPalette: true,
  };

  FeatureFlagService._internal();

  bool isEnabled(String flag) => _flags[flag] ?? false;

  void setFlag(String flag, bool enabled) {
    _flags[flag] = enabled;
  }

  Map<String, bool> getAllFlags() => Map.unmodifiable(_flags);
}

final featureFlagServiceProvider = Provider<FeatureFlagService>((ref) {
  return FeatureFlagService.instance;
});
