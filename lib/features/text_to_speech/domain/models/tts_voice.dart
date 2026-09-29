import 'tts_voice_engine.dart';

/// Represents an available Text-to-Speech voice from local Windows or cloud provider.
class TtsVoice {
  final String id;
  final String name;
  final String language; // e.g., 'vi-VN', 'en-US', 'en-GB'
  final String locale;
  final String gender; // 'Female', 'Male', 'Neutral', 'Unknown'
  final String providerId; // 'windows_local', 'google_cloud', 'azure_speech'
  final bool isOffline;
  final String? accent; // Documented accent only if explicitly reported
  final TtsVoiceEngine engine;

  const TtsVoice({
    required this.id,
    required this.name,
    required this.language,
    required this.locale,
    this.gender = 'Unknown',
    required this.providerId,
    this.isOffline = true,
    this.accent,
    this.engine = TtsVoiceEngine.sapi,
  });

  bool get isVietnamese =>
      language.toLowerCase().startsWith('vi') ||
      locale.toLowerCase().startsWith('vi') ||
      name.toLowerCase().contains('vietnam');

  bool get isLocal => isOffline;

  String get displayName {
    final offlineTag = isOffline ? '[Cục bộ]' : '[Đám mây]';
    final engineTag = engine == TtsVoiceEngine.oneCore
        ? ' (OneCore)'
        : (engine == TtsVoiceEngine.sapi ? ' (SAPI)' : '');
    return '$name ($language, $gender)$engineTag $offlineTag';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'language': language,
        'locale': locale,
        'gender': gender,
        'providerId': providerId,
        'isOffline': isOffline,
        'accent': accent,
        'engine': engine.name,
      };

  factory TtsVoice.fromJson(Map<String, dynamic> json) => TtsVoice(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Voice',
        language: json['language'] as String? ?? 'vi-VN',
        locale: json['locale'] as String? ?? 'vi-VN',
        gender: json['gender'] as String? ?? 'Unknown',
        providerId: json['providerId'] as String? ?? 'windows_local',
        isOffline: json['isOffline'] as bool? ?? true,
        accent: json['accent'] as String?,
        engine: TtsVoiceEngine.values.firstWhere(
          (e) => e.name == json['engine'],
          orElse: () => TtsVoiceEngine.sapi,
        ),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TtsVoice &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          providerId == other.providerId;

  @override
  int get hashCode => id.hashCode ^ providerId.hashCode;

  @override
  String toString() => '$name ($language)';
}
