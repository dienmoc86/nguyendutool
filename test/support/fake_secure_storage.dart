import 'dart:convert';
import 'package:nguyendu_tool/core/providers/secure_storage_abstraction.dart';

/// Test-only fake secure storage utilizing in-memory Base64 encoding.
/// This implementation is strictly quarantined inside test/support/ and must never
/// be used in production lib/.
class FakeSecureStorage implements ISecureStorage {
  final Map<String, String> _vault = {};

  @override
  Future<void> writeSecret(String key, String value) async {
    _vault[key] = 'FAKE_B64:${base64.encode(utf8.encode(value))}';
  }

  @override
  Future<String?> readSecret(String key) async {
    final stored = _vault[key];
    if (stored == null) return null;
    if (stored.startsWith('FAKE_B64:')) {
      final raw = stored.substring(9);
      return utf8.decode(base64.decode(raw));
    }
    return stored;
  }

  @override
  Future<void> deleteSecret(String key) async {
    _vault.remove(key);
  }

  @override
  Future<bool> hasSecret(String key) async => _vault.containsKey(key);

  @override
  Future<bool> containsSecret(String key) async => _vault.containsKey(key);

  void clear() => _vault.clear();
}
