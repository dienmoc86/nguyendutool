import '../logging/app_logger.dart';
import '../providers/secure_storage_abstraction.dart';
import 'windows_dpapi_secure_storage.dart';

/// Centralized service orchestrating provider credentials and secret management.
/// Guarantees that ALL API keys, tokens, and authorization credentials flow
/// exclusively through Windows DPAPI [ISecureStorage], never written to SQLite,
/// logs, UI state dumps, or plaintext disk files.
class CredentialService {
  final ISecureStorage _secureStorage;

  static const String keyGoogleTtsApiKey = 'google_tts_api_key';
  static const String keyAzureSpeechKey = 'azure_speech_subscription_key';
  static const String keyAzureSpeechRegion = 'azure_speech_region';
  static const String keyGeminiApiKey = 'gemini_api_key';
  static const String keyOpenAiApiKey = 'openai_api_key';

  CredentialService({ISecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? WindowsDpapiSecureStorage();

  ISecureStorage get secureStorage => _secureStorage;

  /// Retrieves a protected credential by key.
  Future<String?> getCredential(String key) async {
    return await _secureStorage.readSecret(key);
  }

  /// Saves a protected credential via Windows DPAPI.
  Future<void> saveCredential(String key, String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await removeCredential(key);
      return;
    }
    await _secureStorage.writeSecret(key, trimmed);
    AppLogger.info('CredentialService: Encrypted and saved credential for [$key] via DPAPI.');
  }

  /// Removes a credential from secure storage.
  Future<void> removeCredential(String key) async {
    await _secureStorage.deleteSecret(key);
    AppLogger.info('CredentialService: Removed credential for [$key] from DPAPI vault.');
  }

  /// Checks if a credential exists in the vault.
  Future<bool> hasCredential(String key) async {
    return await _secureStorage.hasSecret(key);
  }

  // --- Strongly typed accessors for production providers ---

  Future<String?> getGoogleTtsApiKey() => getCredential(keyGoogleTtsApiKey);
  Future<void> setGoogleTtsApiKey(String key) => saveCredential(keyGoogleTtsApiKey, key);
  Future<void> removeGoogleTtsApiKey() => removeCredential(keyGoogleTtsApiKey);

  Future<String?> getAzureSpeechKey() => getCredential(keyAzureSpeechKey);
  Future<String?> getAzureSpeechRegion() => getCredential(keyAzureSpeechRegion);
  Future<void> setAzureSpeechCredentials({required String key, String region = 'southeastasia'}) async {
    await saveCredential(keyAzureSpeechKey, key);
    await saveCredential(keyAzureSpeechRegion, region);
  }
  Future<void> removeAzureSpeechCredentials() async {
    await removeCredential(keyAzureSpeechKey);
    await removeCredential(keyAzureSpeechRegion);
  }

  /// Utility to mask secret for display in UI (e.g. `AIza...1234`).
  static String maskSecret(String? secret) {
    if (secret == null || secret.isEmpty) return 'Chưa cấu hình';
    if (secret.length <= 8) return '********';
    return '${secret.substring(0, 4)}...${secret.substring(secret.length - 4)}';
  }
}
