import 'dart:convert';
import 'dart:io';
import '../logging/app_logger.dart';
import '../providers/secure_storage_abstraction.dart';

class GoogleUserProfile {
  final String email;
  final String displayName;
  final String apiKey;
  final DateTime connectedAt;

  const GoogleUserProfile({
    required this.email,
    required this.displayName,
    required this.apiKey,
    required this.connectedAt,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'displayName': displayName,
        'connectedAt': connectedAt.toIso8601String(),
      };
}

/// Service managing Google Account authentication and Google Gemini AI token storage
/// with Windows DPAPI hardware-level encryption.
class GoogleAuthService {
  static const String keyGoogleApiKey = 'google_gemini_api_key';
  static const String keyGoogleUser = 'google_user_profile';

  final ISecureStorage secureStorage;

  GoogleAuthService(this.secureStorage);

  /// Checks if a valid Google Gemini connection is available.
  Future<bool> isAuthenticated() async {
    final key = await secureStorage.readSecret(keyGoogleApiKey);
    return key != null && key.trim().isNotEmpty;
  }

  /// Gets the stored Google API Key.
  Future<String?> getApiKey() async {
    return await secureStorage.readSecret(keyGoogleApiKey);
  }

  /// Gets the connected Google User Profile if available.
  Future<GoogleUserProfile?> getUserProfile() async {
    final key = await getApiKey();
    if (key == null) return null;

    final userJsonStr = await secureStorage.readSecret(keyGoogleUser);
    if (userJsonStr != null) {
      try {
        final map = jsonDecode(userJsonStr) as Map<String, dynamic>;
        return GoogleUserProfile(
          email: map['email'] as String? ?? 'giaovien@edu.vn',
          displayName: map['displayName'] as String? ?? 'Thầy/Cô Giáo viên',
          apiKey: key,
          connectedAt: DateTime.tryParse(map['connectedAt']?.toString() ?? '') ?? DateTime.now(),
        );
      } catch (_) {}
    }

    return GoogleUserProfile(
      email: 'giaovien.google@edu.vn',
      displayName: 'Tài khoản Google (Gemini AI)',
      apiKey: key,
      connectedAt: DateTime.now(),
    );
  }

  /// Saves the Google Gemini API Key and Profile securely into Windows DPAPI.
  Future<void> saveCredentials({
    required String apiKey,
    String? email,
    String? displayName,
  }) async {
    final trimmedKey = apiKey.trim();
    if (trimmedKey.isEmpty) {
      throw ArgumentError('Mã khóa Google Gemini không được để trống.');
    }

    await secureStorage.writeSecret(keyGoogleApiKey, trimmedKey);

    final profile = GoogleUserProfile(
      email: email?.trim().isNotEmpty == true ? email!.trim() : 'giaovien.google@edu.vn',
      displayName: displayName?.trim().isNotEmpty == true ? displayName!.trim() : 'Giáo viên (Google Gemini)',
      apiKey: trimmedKey,
      connectedAt: DateTime.now(),
    );

    await secureStorage.writeSecret(keyGoogleUser, jsonEncode(profile.toJson()));
    AppLogger.info('Google credentials saved securely with DPAPI encryption.');
  }

  /// Sign out and delete stored Google credentials.
  Future<void> signOut() async {
    await secureStorage.deleteSecret(keyGoogleApiKey);
    await secureStorage.deleteSecret(keyGoogleUser);
    AppLogger.info('Signed out of Google Gemini.');
  }

  /// Opens Google AI Studio portal in user's default browser so they can create/copy their API key with 1 click.
  static Future<void> openGoogleKeyPortal() async {
    const url = 'https://aistudio.google.com/app/apikey';
    if (Platform.isWindows) {
      await Process.start('cmd.exe', ['/c', 'start', '', url]);
    }
  }
}
