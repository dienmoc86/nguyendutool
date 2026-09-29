import 'dart:convert';
import '../logging/app_logger.dart';

/// Contract for protecting API keys, secrets and credentials securely.
/// In Phase 0, provides safe obfuscated in-memory/isolated storage without
/// writing plain text to SQLite or unprotected disk files.
abstract class ISecureStorage {
  Future<void> writeSecret(String key, String value);
  Future<String?> readSecret(String key);
  Future<void> deleteSecret(String key);
  Future<bool> hasSecret(String key);
  Future<bool> containsSecret(String key);
}

/// Phase 0 secure storage implementation.
/// Designed for easy plug-in of Windows DPAPI / Credential Manager in Phase 5.
class SecureStorageService implements ISecureStorage {
  final Map<String, String> _memoryVault = {};

  @override
  Future<void> writeSecret(String key, String value) async {
    // Obfuscate in memory to prevent raw string dumps
    final bytes = utf8.encode(value);
    _memoryVault[key] = base64.encode(bytes);
    AppLogger.debug('SecureStorage: Stored secret key [$key] (protected)');
  }

  @override
  Future<String?> readSecret(String key) async {
    final encoded = _memoryVault[key];
    if (encoded == null) return null;
    final bytes = base64.decode(encoded);
    return utf8.decode(bytes);
  }

  @override
  Future<void> deleteSecret(String key) async {
    _memoryVault.remove(key);
    AppLogger.debug('SecureStorage: Deleted secret key [$key]');
  }

  @override
  Future<bool> hasSecret(String key) async {
    return containsSecret(key);
  }

  @override
  Future<bool> containsSecret(String key) async {
    return _memoryVault.containsKey(key);
  }
}
