import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import '../logging/app_logger.dart';

/// Win32 Native FFI Bridge for core system operations:
/// - Windows Named Mutex (Single Instance Guard)
/// - Accurate Disk Free Space (GetDiskFreeSpaceExW)
/// - Native Open File Dialog (comdlg32.dll GetOpenFileNameW fallback)
class Win32SystemBridge {
  static DynamicLibrary? _kernel32;
  static DynamicLibrary? _comdlg32;

  static DynamicLibrary get kernel32 {
    _kernel32 ??= DynamicLibrary.open('kernel32.dll');
    return _kernel32!;
  }

  static DynamicLibrary get comdlg32 {
    _comdlg32 ??= DynamicLibrary.open('comdlg32.dll');
    return _comdlg32!;
  }

  // --- 1. SINGLE INSTANCE NAMED MUTEX (Requirements 24 & 25) ---

  static int _mutexHandle = 0;
  // ignore: constant_identifier_names
  static const int ERROR_ALREADY_EXISTS = 183;

  /// Attempts to create or open a process-isolated named mutex.
  /// Returns `true` if this is the ONLY running primary instance.
  /// Returns `false` if another instance already owns the named mutex.
  static bool acquireSingleInstanceMutex({String mutexName = r'Local\NguyenDuTool_SingleInstanceMutex_v151'}) {
    if (!Platform.isWindows) return true;

    try {
      final createMutexW = kernel32.lookupFunction<
          IntPtr Function(Pointer<Void>, Int32, Pointer<Utf16>),
          int Function(Pointer<Void>, int, Pointer<Utf16>)>('CreateMutexW');
      final getLastError = kernel32.lookupFunction<Uint32 Function(), int Function()>('GetLastError');

      final namePtr = mutexName.toNativeUtf16();
      try {
        final handle = createMutexW(nullptr, 1, namePtr);
        final err = getLastError();

        if (handle == 0) {
          AppLogger.error('Failed to create Win32 Mutex (Error code: $err)');
          return true; // Don't block app if mutex creation itself fails for unprivileged user
        }

        if (err == ERROR_ALREADY_EXISTS) {
          AppLogger.warning('Another instance of NguyenDu Tool is already running (Named Mutex: $mutexName).');
          // Close our duplicate handle
          _closeHandle(handle);
          return false;
        }

        _mutexHandle = handle;
        AppLogger.info('Acquired exclusive Win32 Named Mutex: $mutexName (Handle: $handle)');
        return true;
      } finally {
        calloc.free(namePtr);
      }
    } catch (e, st) {
      AppLogger.error('Win32 single instance mutex acquisition failed: $e', e, st);
      return true; // Fallback to allowing execution if FFI fails
    }
  }

  /// Releases the Win32 Named Mutex on normal application exit.
  static void releaseSingleInstanceMutex() {
    if (_mutexHandle != 0) {
      _closeHandle(_mutexHandle);
      AppLogger.info('Released Win32 Named Mutex (Handle: $_mutexHandle)');
      _mutexHandle = 0;
    }
  }

  static void _closeHandle(int handle) {
    try {
      final closeHandle = kernel32.lookupFunction<Int32 Function(IntPtr), int Function(int)>('CloseHandle');
      closeHandle(handle);
    } catch (_) {}
  }

  // --- 2. ACCURATE DISK FREE SPACE (Requirement 19) ---

  /// Queries exact free space and total capacity for the drive containing [path].
  static ({int freeBytes, int totalBytes, double freeGb, double totalGb})? getDiskFreeSpace(String path) {
    if (!Platform.isWindows) return null;

    try {
      final getDiskFreeSpaceExW = kernel32.lookupFunction<
          Int32 Function(Pointer<Utf16>, Pointer<Uint64>, Pointer<Uint64>, Pointer<Uint64>),
          int Function(Pointer<Utf16>, Pointer<Uint64>, Pointer<Uint64>, Pointer<Uint64>)>('GetDiskFreeSpaceExW');

      final pathPtr = path.toNativeUtf16();
      final freeBytesAvailable = calloc<Uint64>();
      final totalNumberOfBytes = calloc<Uint64>();
      final totalNumberOfFreeBytes = calloc<Uint64>();

      try {
        final result = getDiskFreeSpaceExW(pathPtr, freeBytesAvailable, totalNumberOfBytes, totalNumberOfFreeBytes);
        if (result != 0) {
          final free = freeBytesAvailable.value;
          final total = totalNumberOfBytes.value;
          final freeGb = free / (1024 * 1024 * 1024);
          final totalGb = total / (1024 * 1024 * 1024);
          return (freeBytes: free, totalBytes: total, freeGb: freeGb, totalGb: totalGb);
        }
      } finally {
        calloc.free(pathPtr);
        calloc.free(freeBytesAvailable);
        calloc.free(totalNumberOfBytes);
        calloc.free(totalNumberOfFreeBytes);
      }
    } catch (e) {
      AppLogger.warning('Failed to query disk free space via Win32: $e');
    }
    return null;
  }
}
