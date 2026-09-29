/// Information and capabilities reported by a TTS provider engine.
class TtsProviderInfo {
  final String id;
  final String name;
  final String description;
  final bool isOffline;
  final bool isConfigured;
  final bool supportsPitch;
  final bool supportsRate;
  final bool supportsSsml;
  final bool supportsWav;
  final bool supportsMp3;
  final bool supportsTiming;
  final bool supportsChunkTiming;
  final bool supportsWordTiming;
  final bool supportsSentenceTiming;
  final int maxCharactersPerRequest;
  final double minSpeed;
  final double maxSpeed;
  final double minPitch;
  final double maxPitch;

  const TtsProviderInfo({
    required this.id,
    required this.name,
    required this.description,
    this.isOffline = true,
    this.isConfigured = true,
    this.supportsPitch = true,
    this.supportsRate = true,
    this.supportsSsml = false,
    this.supportsWav = true,
    this.supportsMp3 = true,
    this.supportsTiming = true,
    this.supportsChunkTiming = true,
    this.supportsWordTiming = false,
    this.supportsSentenceTiming = false,
    this.maxCharactersPerRequest = 2000,
    this.minSpeed = 0.5,
    this.maxSpeed = 2.0,
    this.minPitch = 0.5,
    this.maxPitch = 1.5,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'isOffline': isOffline,
        'isConfigured': isConfigured,
        'supportsPitch': supportsPitch,
        'supportsRate': supportsRate,
        'supportsSsml': supportsSsml,
        'supportsWav': supportsWav,
        'supportsMp3': supportsMp3,
        'supportsTiming': supportsTiming,
        'supportsChunkTiming': supportsChunkTiming,
        'supportsWordTiming': supportsWordTiming,
        'supportsSentenceTiming': supportsSentenceTiming,
        'maxCharactersPerRequest': maxCharactersPerRequest,
        'minSpeed': minSpeed,
        'maxSpeed': maxSpeed,
        'minPitch': minPitch,
        'maxPitch': maxPitch,
      };

  factory TtsProviderInfo.fromJson(Map<String, dynamic> json) => TtsProviderInfo(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'TTS Provider',
        description: json['description'] as String? ?? '',
        isOffline: json['isOffline'] as bool? ?? true,
        isConfigured: json['isConfigured'] as bool? ?? true,
        supportsPitch: json['supportsPitch'] as bool? ?? true,
        supportsRate: json['supportsRate'] as bool? ?? true,
        supportsSsml: json['supportsSsml'] as bool? ?? false,
        supportsWav: json['supportsWav'] as bool? ?? true,
        supportsMp3: json['supportsMp3'] as bool? ?? true,
        supportsTiming: json['supportsTiming'] as bool? ?? true,
        supportsChunkTiming: json['supportsChunkTiming'] as bool? ?? true,
        supportsWordTiming: json['supportsWordTiming'] as bool? ?? false,
        supportsSentenceTiming: json['supportsSentenceTiming'] as bool? ?? false,
        maxCharactersPerRequest: json['maxCharactersPerRequest'] as int? ?? 2000,
        minSpeed: (json['minSpeed'] as num?)?.toDouble() ?? 0.5,
        maxSpeed: (json['maxSpeed'] as num?)?.toDouble() ?? 2.0,
        minPitch: (json['minPitch'] as num?)?.toDouble() ?? 0.5,
        maxPitch: (json['maxPitch'] as num?)?.toDouble() ?? 1.5,
      );
}
