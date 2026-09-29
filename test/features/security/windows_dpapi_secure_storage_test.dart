import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:nguyendu_tool/core/security/windows_dpapi_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String vaultPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('dpapi_test_');
    vaultPath = p.join(tempDir.path, 'secure_vault.dat');
  });

  tearDown(() {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('Windows DPAPI Secure Storage Tests', () {
    test('Encrypts, stores, reads, and deletes a secret key successfully', () async {
      final storage = WindowsDpapiSecureStorage(customVaultPath: vaultPath);

      // Verify empty initially
      expect(await storage.containsSecret('google_tts_api_key'), isFalse);
      expect(await storage.readSecret('google_tts_api_key'), isNull);

      // Write secret
      const sampleKey = 'AIzaSyA_Sample_Secret_Token_NguyenDu_12345';
      await storage.writeSecret('google_tts_api_key', sampleKey);

      // Verify secret is stored
      expect(await storage.containsSecret('google_tts_api_key'), isTrue);
      expect(await storage.hasSecret('google_tts_api_key'), isTrue);

      // Read secret and verify it matches original plaintext
      final retrieved = await storage.readSecret('google_tts_api_key');
      expect(retrieved, equals(sampleKey));

      // Verify that raw vault file does NOT contain the plaintext secret
      final vaultContent = File(vaultPath).readAsStringSync();
      expect(vaultContent.contains(sampleKey), isFalse, reason: 'Plaintext secret must never be stored on disk');

      final decoded = jsonDecode(vaultContent) as Map<String, dynamic>;
      final cipherText = decoded['google_tts_api_key'] as String;
      expect(cipherText.startsWith('DPAPI:'), isTrue, reason: 'Windows production storage must strictly use DPAPI: prefix');

      // Delete secret
      await storage.deleteSecret('google_tts_api_key');
      expect(await storage.containsSecret('google_tts_api_key'), isFalse);
      expect(await storage.readSecret('google_tts_api_key'), isNull);
    });

    test('Persists encrypted secrets across new storage instances', () async {
      final storage1 = WindowsDpapiSecureStorage(customVaultPath: vaultPath);
      await storage1.writeSecret('secret_a', 'val_alpha');
      await storage1.writeSecret('secret_b', 'val_beta');

      // Create a completely separate instance pointing to the same vault file
      final storage2 = WindowsDpapiSecureStorage(customVaultPath: vaultPath);
      expect(await storage2.containsSecret('secret_a'), isTrue);
      expect(await storage2.containsSecret('secret_b'), isTrue);
      expect(await storage2.readSecret('secret_a'), equals('val_alpha'));
      expect(await storage2.readSecret('secret_b'), equals('val_beta'));
    });

    test('Detects legacy plaintext secret in vault and securely migrates to DPAPI on read', () async {
      // Manually create a vault file containing raw plaintext
      final rawVault = {
        'legacy_key': 'my_raw_plain_secret_123',
      };
      File(vaultPath).writeAsStringSync(jsonEncode(rawVault));

      final storage = WindowsDpapiSecureStorage(customVaultPath: vaultPath);
      final value = await storage.readSecret('legacy_key');
      expect(value, equals('my_raw_plain_secret_123'));

      // Check that vault on disk is now encrypted with DPAPI
      final updatedVault = jsonDecode(File(vaultPath).readAsStringSync()) as Map<String, dynamic>;
      expect(updatedVault['legacy_key'].toString().startsWith('DPAPI:'), isTrue);
    });

    test('Migrates legacy plaintext secrets into DPAPI storage cleanly without duplication', () async {
      final storage = WindowsDpapiSecureStorage(customVaultPath: vaultPath);

      final legacyPlaintext = <String, String>{
        'legacy_openai_key': 'sk-test-12345-legacy-plain',
        'legacy_tts_key': 'AIzaSyLegacyKey999',
      };

      final migratedKeys = <String>[];
      final count = await storage.migrateLegacySecrets(
        legacyPlaintext,
        onSecretMigrated: (key) => migratedKeys.add(key),
      );

      expect(count, equals(2));
      expect(migratedKeys, containsAll(['legacy_openai_key', 'legacy_tts_key']));

      // Verify both secrets now readable from DPAPI
      expect(await storage.readSecret('legacy_openai_key'), equals('sk-test-12345-legacy-plain'));
      expect(await storage.readSecret('legacy_tts_key'), equals('AIzaSyLegacyKey999'));

      // Re-running migration does not duplicate or re-encrypt existing keys
      final secondRunCount = await storage.migrateLegacySecrets(legacyPlaintext);
      expect(secondRunCount, equals(0), reason: 'Already migrated secrets must not be re-processed');
    });
  });
}
