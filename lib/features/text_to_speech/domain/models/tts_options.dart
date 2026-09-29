/// Supported audio formats for synthesized speech output.
enum TtsAudioFormat {
  wav('wav', 'WAV không nén (PCM 16-bit, chất lượng cao nhất)', '.wav', 'audio/wav'),
  mp3('mp3', 'MP3 nén chuẩn (Dung lượng nhỏ, chuẩn web & video)', '.mp3', 'audio/mpeg');

  final String id;
  final String label;
  final String extension;
  final String mimeType;

  const TtsAudioFormat(this.id, this.label, this.extension, this.mimeType);

  static TtsAudioFormat fromString(String val) {
    return val.toLowerCase() == 'mp3' ? TtsAudioFormat.mp3 : TtsAudioFormat.wav;
  }
}

/// Options controlling speech synthesis audio generation.
class TtsOptions {
  final TtsAudioFormat format;
  final double speed; // 0.5 to 2.0 (1.0 = normal)
  final double pitch; // 0.5 to 1.5 (1.0 = normal)
  final double volume; // 0.0 to 1.0 (1.0 = 100%)
  final int paragraphPauseMs; // Silence duration between paragraphs in ms
  final int sentencePauseMs; // Silence duration between sentences in ms
  final bool preserveParagraphs;
  final bool generateSubtitles;
  final bool offlineOnly;

  const TtsOptions({
    this.format = TtsAudioFormat.wav,
    this.speed = 1.0,
    this.pitch = 1.0,
    this.volume = 1.0,
    this.paragraphPauseMs = 500,
    this.sentencePauseMs = 250,
    this.preserveParagraphs = true,
    this.generateSubtitles = true,
    this.offlineOnly = false,
  });

  TtsOptions copyWith({
    TtsAudioFormat? format,
    double? speed,
    double? pitch,
    double? volume,
    int? paragraphPauseMs,
    int? sentencePauseMs,
    bool? preserveParagraphs,
    bool? generateSubtitles,
    bool? offlineOnly,
  }) {
    return TtsOptions(
      format: format ?? this.format,
      speed: speed ?? this.speed,
      pitch: pitch ?? this.pitch,
      volume: volume ?? this.volume,
      paragraphPauseMs: paragraphPauseMs ?? this.paragraphPauseMs,
      sentencePauseMs: sentencePauseMs ?? this.sentencePauseMs,
      preserveParagraphs: preserveParagraphs ?? this.preserveParagraphs,
      generateSubtitles: generateSubtitles ?? this.generateSubtitles,
      offlineOnly: offlineOnly ?? this.offlineOnly,
    );
  }

  Map<String, dynamic> toJson() => {
        'format': format.id,
        'speed': speed,
        'pitch': pitch,
        'volume': volume,
        'paragraphPauseMs': paragraphPauseMs,
        'sentencePauseMs': sentencePauseMs,
        'preserveParagraphs': preserveParagraphs,
        'generateSubtitles': generateSubtitles,
        'offlineOnly': offlineOnly,
      };

  factory TtsOptions.fromJson(Map<String, dynamic> json) => TtsOptions(
        format: TtsAudioFormat.fromString(json['format'] as String? ?? 'wav'),
        speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
        pitch: (json['pitch'] as num?)?.toDouble() ?? 1.0,
        volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
        paragraphPauseMs: json['paragraphPauseMs'] as int? ?? 500,
        sentencePauseMs: json['sentencePauseMs'] as int? ?? 250,
        preserveParagraphs: json['preserveParagraphs'] as bool? ?? true,
        generateSubtitles: json['generateSubtitles'] as bool? ?? true,
        offlineOnly: json['offlineOnly'] as bool? ?? false,
      );
}
