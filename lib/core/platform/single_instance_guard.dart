import 'dart:io';
import 'win32_system_bridge.dart';

/// Single-instance guard utility ensuring database and workspace safety (Requirements 24 & 25).
/// Uses reliable Windows Named Mutex via Win32 API (CreateMutexW), preventing
/// concurrent execution and database corruptions.
class SingleInstanceGuard {
  static bool _isPrimaryInstance = true;

  static bool get isPrimaryInstance => _isPrimaryInstance;

  /// Tries to acquire exclusive Windows Named Mutex.
  /// Returns `true` if this instance successfully obtained the lock.
  /// Returns `false` if another instance of NguyenDu Tool is already running.
  static Future<bool> acquireLock([String? _]) async {
    if (!Platform.isWindows) {
      _isPrimaryInstance = true;
      return true;
    }

    final acquired = Win32SystemBridge.acquireSingleInstanceMutex();
    _isPrimaryInstance = acquired;
    return acquired;
  }

  /// Releases the single-instance mutex upon normal application shutdown.
  static Future<void> releaseLock() async {
    if (Platform.isWindows) {
      Win32SystemBridge.releaseSingleInstanceMutex();
    }
  }
}

