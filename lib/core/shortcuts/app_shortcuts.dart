import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OpenCommandPaletteIntent extends Intent {
  const OpenCommandPaletteIntent();
}

class GoToDashboardIntent extends Intent {
  const GoToDashboardIntent();
}

class GoToSettingsIntent extends Intent {
  const GoToSettingsIntent();
}

class GoToLibraryIntent extends Intent {
  const GoToLibraryIntent();
}

/// Central definition of global application shortcuts.
class AppShortcuts {
  static final Map<ShortcutActivator, Intent> defaultShortcuts = {
    // Ctrl+K -> Command Palette
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK):
        const OpenCommandPaletteIntent(),
    // Ctrl+1 -> Dashboard
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit1):
        const GoToDashboardIntent(),
    // Ctrl+, -> Settings
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.comma):
        const GoToSettingsIntent(),
    // Ctrl+L -> Library
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyL):
        const GoToLibraryIntent(),
  };
}
