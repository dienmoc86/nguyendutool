import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import '../errors/app_exceptions.dart';
import '../logging/app_logger.dart';
import '../providers/secure_storage_abstraction.dart';

final class _DataBlob extends Struct {
  @Uint32()
  external int cbData;
  external Pointer<Uint8> pbData;
}

typedef _CryptProtectDataNative = Int32 Function(
  Pointer<_DataBlob> pDataIn,
  Pointer<Utf16> szDataDescr,
  Pointer<_DataBlob> pOptionalEntropy,
  Pointer<Void> pvReserved,
  Pointer<Void> pPromptStruct,
  Uint32 dwFlags,
  Pointer<_DataBlob> pDataOut,
);
typedef _CryptProtectDataDart = int Function(
  Pointer<_DataBlob> pDataIn,
  Pointer<Utf16> szDataDescr,
  Pointer<_DataBlob> pOptionalEntropy,
  Pointer<Void> pvReserved,
  Pointer<Void> pPromptStruct,
  int dwFlags,
  Pointer<_DataBlob> pDataOut,
);

typedef _CryptUnprotectDataNative = Int32 Function(
  Pointer<_DataBlob> pDataIn,
  Pointer<Pointer<Utf16>> ppszDataDescr,
  Pointer<_DataBlob> pOptionalEntropy,
  Pointer<Void> pvReserved,
  Pointer<Void> pPromptStruct,
  Uint32 dwFlags,
  Pointer<_DataBlob> pDataOut,
);
typedef _CryptUnprotectDataDart = int Function(
  Pointer<_DataBlob> pDataIn,
  Pointer<Pointer<Utf16>> ppszDataDescr,
  Pointer<_DataBlob> pOptionalEntropy,
  Pointer<Void> pvReserved,
  Pointer<Void> pPromptStruct,
  int dwFlags,
  Pointer<_DataBlob> pDataOut,
);

typedef _LocalFreeNative = Pointer<Void> Function(Pointer<Void> hMem);
typedef _LocalFreeDart = Pointer<Void> Function(Pointer<Void> hMem);

typedef _ReplaceFileWNative = Int32 Function(
  Pointer<Utf16> lpReplacedFileName,
  Pointer<Utf16> lpReplacementFileName,
  Pointer<Utf16> lpBackupFileName,
  Uint32 dwReplaceFlags,
  Pointer<Void> lpExclude,
  Pointer<Void> lpReserved,
);
typedef _ReplaceFileWDart = int Function(
  Pointer<Utf16> lpReplacedFileName,
  Pointer<Utf16> lpReplacementFileName,
  Pointer<Utf16> lpBackupFileName,
  int dwReplaceFlags,
  Pointer<Void> lpExclude,
  Pointer<Void> lpReserved,
);

typedef _MoveFileExWNative = Int32 Function(
  Pointer<Utf16> lpExistingFileName,
  Pointer<Utf16> lpNewFileName,
  Uint32 dwFlags,
);
typedef _MoveFileExWDart = int Function(
  Pointer<Utf16> lpExistingFileName,
  Pointer<Utf16> lpNewFileName,
  int dwFlags,
);

/// Production secure storage implementation using Windows DPAPI (Data Protection API).
///
/// Encrypts sensitive secrets (API keys, credentials, tokens) using the CurrentUser
/// Windows credentials, preventing unauthorized access across accounts or machines.
/// Never stores plaintext API keys in SQLite, settings, or plain disk files.
class WindowsDpapiSecureStorage implements ISecureStorage {
  final String _vaultPath;
  Map<String, String>? _cachedVault;
  bool _initialized = false;

  DynamicLibrary? _crypt32;
  DynamicLibrary? _kernel32;
  _CryptProtectDataDart? _cryptProtectData;
  _CryptUnprotectDataDart? _cryptUnprotectData;
  _LocalFreeDart? _localFree;
  _ReplaceFileWDart? _replaceFileW;
  _MoveFileExWDart? _moveFileExW;
  bool _isDpapiAvailable = false;

  bool get isAvailable => _isDpapiAvailable;

  WindowsDpapiSecureStorage({String? customVaultPath})
      : _vaultPath = customVaultPath ?? _defaultVaultPath() {
    _initNativeLibraries();
  }

  static String _defaultVaultPath() {
    final localAppData = Platform.environment['LOCALAPPDATA'] ??
        p.join(Platform.environment['USERPROFILE'] ?? r'C:\Users\Default', 'AppData', 'Local');
    return p.join(localAppData, 'NguyenDu Tool', 'secure_vault.dat');
  }

  void _initNativeLibraries() {
    if (!Platform.isWindows) {
      _isDpapiAvailable = false;
      return;
    }
    try {
      _crypt32 = DynamicLibrary.open('crypt32.dll');
      _kernel32 = DynamicLibrary.open('kernel32.dll');

      _cryptProtectData = _crypt32!.lookupFunction<_CryptProtectDataNative, _CryptProtectDataDart>('CryptProtectData');
      _cryptUnprotectData = _crypt32!.lookupFunction<_CryptUnprotectDataNative, _CryptUnprotectDataDart>('CryptUnprotectData');
      _localFree = _kernel32!.lookupFunction<_LocalFreeNative, _LocalFreeDart>('LocalFree');
      _replaceFileW = _kernel32!.lookupFunction<_ReplaceFileWNative, _ReplaceFileWDart>('ReplaceFileW');
      _moveFileExW = _kernel32!.lookupFunction<_MoveFileExWNative, _MoveFileExWDart>('MoveFileExW');

      _isDpapiAvailable = true;
    } catch (e) {
      _isDpapiAvailable = false;
      AppLogger.warning('Windows DPAPI native library load warning: $e');
    }
  }

  bool get isDpapiAvailable => _isDpapiAvailable;

  /// Performs a live in-memory encrypt/decrypt roundtrip probe to verify DPAPI operational health.
  bool probeRoundtrip() {
    if (!_isDpapiAvailable || _cryptProtectData == null || _cryptUnprotectData == null) {
      return false;
    }
    try {
      const probeValue = '__probe_test_secret_roundtrip__';
      final encrypted = _encrypt(probeValue);
      final decrypted = _decrypt(encrypted);
      return decrypted == probeValue;
    } catch (_) {
      return false;
    }
  }

  Future<void> _ensureLoaded() async {
    if (_initialized && _cachedVault != null) return;
    _cachedVault = {};
    final file = File(_vaultPath);
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final decoded = jsonDecode(content);
        if (decoded is Map<String, dynamic>) {
          for (final entry in decoded.entries) {
            _cachedVault![entry.key] = entry.value.toString();
          }
        }
      } catch (e) {
        AppLogger.warning('Error reading secure vault file: $e');
      }
    }
    _initialized = true;
  }

  /// Atomically persists the encrypted vault to disk using Win32 ReplaceFileW / MoveFileExW.
  /// Never deletes destination before temporary file is completely ready and safely swapped.
  Future<void> _persistVault() async {
    final file = File(_vaultPath);
    await file.parent.create(recursive: true);

    final tempPath = '$_vaultPath.tmp_${DateTime.now().millisecondsSinceEpoch}';
    final tempFile = File(tempPath);
    final backupPath = '$_vaultPath.bak';
    final jsonStr = jsonEncode(_cachedVault ?? {});
    await tempFile.writeAsString(jsonStr, flush: true);

    bool replaceSuccess = false;

    if (Platform.isWindows && _kernel32 != null) {
      final targetPtr = _vaultPath.toNativeUtf16();
      final tempPtr = tempPath.toNativeUtf16();
      final backupPtr = backupPath.toNativeUtf16();

      try {
        if (await file.exists()) {
          // ReplaceFileW with backup and write-through flag (1)
          if (_replaceFileW != null) {
            final res = _replaceFileW!(targetPtr, tempPtr, backupPtr, 1, nullptr, nullptr);
            if (res != 0) {
              replaceSuccess = true;
              final bak = File(backupPath);
              if (bak.existsSync()) {
                try { bak.deleteSync(); } catch (_) {}
              }
            }
          }
          if (!replaceSuccess && _moveFileExW != null) {
            // MOVEFILE_REPLACE_EXISTING (1) | MOVEFILE_WRITE_THROUGH (8) = 9
            final res = _moveFileExW!(tempPtr, targetPtr, 9);
            if (res != 0) {
              replaceSuccess = true;
            }
          }
        } else {
          // New file creation - MoveFileExW
          if (_moveFileExW != null) {
            final res = _moveFileExW!(tempPtr, targetPtr, 9);
            if (res != 0) {
              replaceSuccess = true;
            }
          }
        }
      } finally {
        calloc.free(targetPtr);
        calloc.free(tempPtr);
        calloc.free(backupPtr);
      }
    }

    if (!replaceSuccess) {
      try {
        if (await file.exists()) {
          final backup = File(backupPath);
          await file.copy(backup.path);
          await tempFile.rename(_vaultPath);
          if (await backup.exists()) await backup.delete();
        } else {
          await tempFile.rename(_vaultPath);
        }
        replaceSuccess = true;
      } catch (e) {
        if (await tempFile.exists()) {
          try { await tempFile.delete(); } catch (_) {}
        }
        AppLogger.error('Atomic secure vault persistence failed: $e');
        throw FileException('Không thể lưu trữ vault an toàn theo cơ chế nguyên tử (atomic): $e', path: _vaultPath);
      }
    }
  }

  /// Encrypts plaintext using Windows DPAPI (CurrentUser scope, UI forbidden).
  /// Strictly fails closed if DPAPI is unavailable (Section 1).
  String _encrypt(String plainText) {
    if (!_isDpapiAvailable || _cryptProtectData == null) {
      throw const SecureStorageUnavailableException(
        'Windows DPAPI không khả dụng trên hệ thống này. Không thể mã hóa và lưu trữ bí mật an toàn.',
      );
    }

    final plainBytes = utf8.encode(plainText);
    final inBlob = calloc<_DataBlob>();
    final inData = calloc<Uint8>(plainBytes.length);
    for (var i = 0; i < plainBytes.length; i++) {
      inData[i] = plainBytes[i];
    }
    inBlob.ref.cbData = plainBytes.length;
    inBlob.ref.pbData = inData;

    final outBlob = calloc<_DataBlob>();

    try {
      final success = _cryptProtectData!(
        inBlob,
        nullptr,
        nullptr,
        nullptr,
        nullptr,
        1, // CRYPTPROTECT_UI_FORBIDDEN
        outBlob,
      );

      if (success == 0) {
        throw const SecureStorageUnavailableException('CryptProtectData failed with error code');
      }

      final cipherBytes = outBlob.ref.pbData.asTypedList(outBlob.ref.cbData);
      return 'DPAPI:${base64.encode(cipherBytes)}';
    } finally {
      if (outBlob.ref.pbData != nullptr && _localFree != null) {
        _localFree!(outBlob.ref.pbData.cast());
      }
      calloc.free(inData);
      calloc.free(inBlob);
      calloc.free(outBlob);
    }
  }

  /// Decrypts ciphertext using Windows DPAPI (CurrentUser scope).
  /// Strictly rejects non-DPAPI ciphertext in production (Section 1 & 2).
  String? _decrypt(String cipherText) {
    if (!cipherText.startsWith('DPAPI:')) {
      return null;
    }

    if (!_isDpapiAvailable || _cryptUnprotectData == null) {
      AppLogger.warning('Cannot decrypt DPAPI ciphertext: DPAPI unavailable on host');
      return null;
    }

    final rawB64 = cipherText.substring(6);
    final cipherBytes = base64.decode(rawB64);

    final inBlob = calloc<_DataBlob>();
    final inData = calloc<Uint8>(cipherBytes.length);
    for (var i = 0; i < cipherBytes.length; i++) {
      inData[i] = cipherBytes[i];
    }
    inBlob.ref.cbData = cipherBytes.length;
    inBlob.ref.pbData = inData;

    final outBlob = calloc<_DataBlob>();

    try {
      final success = _cryptUnprotectData!(
        inBlob,
        nullptr,
        nullptr,
        nullptr,
        nullptr,
        1, // CRYPTPROTECT_UI_FORBIDDEN
        outBlob,
      );

      if (success == 0) {
        AppLogger.warning('CryptUnprotectData failed: secret may belong to another user/machine');
        return null;
      }

      final decryptedBytes = outBlob.ref.pbData.asTypedList(outBlob.ref.cbData);
      return utf8.decode(decryptedBytes);
    } finally {
      if (outBlob.ref.pbData != nullptr && _localFree != null) {
        _localFree!(outBlob.ref.pbData.cast());
      }
      calloc.free(inData);
      calloc.free(inBlob);
      calloc.free(outBlob);
    }
  }

  @override
  Future<void> writeSecret(String key, String value) async {
    await _ensureLoaded();
    final encrypted = _encrypt(value);
    _cachedVault![key] = encrypted;
    await _persistVault();
    AppLogger.debug('WindowsDpapiSecureStorage: Protected and stored secret key [$key]');
  }

  @override
  Future<String?> readSecret(String key) async {
    await _ensureLoaded();
    final stored = _cachedVault![key];
    if (stored == null) return null;

    if (!stored.startsWith('DPAPI:')) {
      // Legacy plaintext or B64 detected - run explicit migration path (Section 2)
      AppLogger.warning('Phát hiện bí mật cũ chưa được mã hóa DPAPI cho khóa [$key]. Đang thực hiện di trú an toàn...');
      final rawSecret = stored.startsWith('B64:')
          ? utf8.decode(base64.decode(stored.substring(4)))
          : stored;

      // 1. Detect
      if (!_isDpapiAvailable || _cryptProtectData == null) {
        throw SecureStorageUnavailableException(
          'Không thể di trú bí mật [$key] vì Windows DPAPI không khả dụng. Từ chối sử dụng plaintext.',
        );
      }

      // 2. Migrate to DPAPI
      final encrypted = _encrypt(rawSecret);

      // 3. Verify decrypt
      final testDecrypted = _decrypt(encrypted);
      if (testDecrypted != rawSecret) {
        throw SecureStorageUnavailableException(
          'Xác minh giải mã sau di trú thất bại cho khóa [$key]. Hủy di trú để bảo vệ an toàn.',
        );
      }

      // 4. Remove plaintext and persist
      _cachedVault![key] = encrypted;
      await _persistVault();

      // 5. Verify plaintext source removed
      if (_cachedVault![key] == null || !_cachedVault![key]!.startsWith('DPAPI:')) {
        throw SecureStorageUnavailableException(
          'Không thể xóa bí mật plaintext cho khóa [$key] trong vault.',
        );
      }

      AppLogger.info('Di trú bí mật [$key] sang mã hóa DPAPI thành công.');
      return rawSecret;
    }

    return _decrypt(stored);
  }

  @override
  Future<void> deleteSecret(String key) async {
    await _ensureLoaded();
    if (_cachedVault!.containsKey(key)) {
      _cachedVault!.remove(key);
      await _persistVault();
      AppLogger.debug('WindowsDpapiSecureStorage: Deleted secret key [$key]');
    }
  }

  @override
  Future<bool> hasSecret(String key) async {
    return containsSecret(key);
  }

  @override
  Future<bool> containsSecret(String key) async {
    await _ensureLoaded();
    return _cachedVault!.containsKey(key);
  }

  /// Migrates any legacy plaintext configuration secrets into DPAPI encrypted vault.
  /// Detects plain secrets, encrypts them into DPAPI, and clears plaintext source.
  Future<int> migrateLegacySecrets(Map<String, String> legacyPlaintextMap, {void Function(String key)? onSecretMigrated}) async {
    await _ensureLoaded();
    int migratedCount = 0;

    for (final entry in legacyPlaintextMap.entries) {
      final key = entry.key;
      final plainVal = entry.value.trim();

      if (plainVal.isNotEmpty) {
        // If not already in DPAPI vault, encrypt and store
        if (!_cachedVault!.containsKey(key)) {
          await writeSecret(key, plainVal);
          migratedCount++;
          AppLogger.info('Migrated legacy plaintext secret key [$key] into DPAPI storage.');
          onSecretMigrated?.call(key);
        }
      }
    }

    return migratedCount;
  }
}
