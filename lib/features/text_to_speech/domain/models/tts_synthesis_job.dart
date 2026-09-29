import 'tts_options.dart';

/// Status lifecycle for a TTS Synthesis Job.
enum TtsJobStatus {
  queued('Chờ xử lý'),
  preparingText('Chuẩn hóa & phân đoạn văn bản'),
  synthesizing('Đang đọc âm thanh từng đoạn'),
  assembling('Ghép nối tệp âm thanh'),
  encoding('Mã hóa tệp MP3'),
  completed('Hoàn thành'),
  failed('Thất bại'),
  cancelled('Đã hủy');

  final String label;
  const TtsJobStatus(this.label);

  static TtsJobStatus fromString(String val) {
    return TtsJobStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => TtsJobStatus.queued,
    );
  }
}

/// Represents a persistent TTS Synthesis Job for synthesizing audio documents.
class TtsSynthesisJob {
  final String id;
  final String title;
  final String inputSource; // manual, txt, docx, pdf, ocr, library
  final String? inputPath;
  final String rawText;
  final String normalizedText;
  final String providerId;
  final String voiceId;
  final String voiceName;
  final String language;
  final TtsAudioFormat audioFormat;
  final double speed;
  final double pitch;
  final double volume;
  final int totalChunks;
  final int completedChunks;
  final int totalDurationMs;
  final String? outputAudioPath;
  final String? outputSrtPath;
  final String? outputVttPath;
  final TtsJobStatus status;
  final double progress; // 0.0 to 1.0
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TtsSynthesisJob({
    required this.id,
    required this.title,
    required this.inputSource,
    this.inputPath,
    required this.rawText,
    required this.normalizedText,
    required this.providerId,
    required this.voiceId,
    required this.voiceName,
    required this.language,
    this.audioFormat = TtsAudioFormat.wav,
    this.speed = 1.0,
    this.pitch = 1.0,
    this.volume = 1.0,
    this.totalChunks = 0,
    this.completedChunks = 0,
    this.totalDurationMs = 0,
    this.outputAudioPath,
    this.outputSrtPath,
    this.outputVttPath,
    this.status = TtsJobStatus.queued,
    this.progress = 0.0,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  TtsSynthesisJob copyWith({
    String? id,
    String? title,
    String? inputSource,
    String? inputPath,
    String? rawText,
    String? normalizedText,
    String? providerId,
    String? voiceId,
    String? voiceName,
    String? language,
    TtsAudioFormat? audioFormat,
    double? speed,
    double? pitch,
    double? volume,
    int? totalChunks,
    int? completedChunks,
    int? totalDurationMs,
    String? outputAudioPath,
    String? outputSrtPath,
    String? outputVttPath,
    TtsJobStatus? status,
    double? progress,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TtsSynthesisJob(
      id: id ?? this.id,
      title: title ?? this.title,
      inputSource: inputSource ?? this.inputSource,
      inputPath: inputPath ?? this.inputPath,
      rawText: rawText ?? this.rawText,
      normalizedText: normalizedText ?? this.normalizedText,
      providerId: providerId ?? this.providerId,
      voiceId: voiceId ?? this.voiceId,
      voiceName: voiceName ?? this.voiceName,
      language: language ?? this.language,
      audioFormat: audioFormat ?? this.audioFormat,
      speed: speed ?? this.speed,
      pitch: pitch ?? this.pitch,
      volume: volume ?? this.volume,
      totalChunks: totalChunks ?? this.totalChunks,
      completedChunks: completedChunks ?? this.completedChunks,
      totalDurationMs: totalDurationMs ?? this.totalDurationMs,
      outputAudioPath: outputAudioPath ?? this.outputAudioPath,
      outputSrtPath: outputSrtPath ?? this.outputSrtPath,
      outputVttPath: outputVttPath ?? this.outputVttPath,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'input_source': inputSource,
      'input_path': inputPath,
      'raw_text': rawText,
      'normalized_text': normalizedText,
      'provider_id': providerId,
      'voice_id': voiceId,
      'voice_name': voiceName,
      'language': language,
      'audio_format': audioFormat.name,
      'speed': speed,
      'pitch': pitch,
      'volume': volume,
      'total_chunks': totalChunks,
      'completed_chunks': completedChunks,
      'total_duration_ms': totalDurationMs,
      'output_audio_path': outputAudioPath,
      'output_srt_path': outputSrtPath,
      'output_vtt_path': outputVttPath,
      'status': status.name,
      'progress': progress,
      'error_message': errorMessage,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory TtsSynthesisJob.fromMap(Map<String, dynamic> map) {
    return TtsSynthesisJob(
      id: map['id'] as String,
      title: map['title'] as String,
      inputSource: map['input_source'] as String,
      inputPath: map['input_path'] as String?,
      rawText: map['raw_text'] as String,
      normalizedText: map['normalized_text'] as String,
      providerId: map['provider_id'] as String,
      voiceId: map['voice_id'] as String,
      voiceName: map['voice_name'] as String,
      language: map['language'] as String,
      audioFormat: TtsAudioFormat.fromString(map['audio_format'] as String? ?? 'wav'),
      speed: (map['speed'] as num?)?.toDouble() ?? 1.0,
      pitch: (map['pitch'] as num?)?.toDouble() ?? 1.0,
      volume: (map['volume'] as num?)?.toDouble() ?? 1.0,
      totalChunks: (map['total_chunks'] as num?)?.toInt() ?? 0,
      completedChunks: (map['completed_chunks'] as num?)?.toInt() ?? 0,
      totalDurationMs: (map['total_duration_ms'] as num?)?.toInt() ?? 0,
      outputAudioPath: map['output_audio_path'] as String?,
      outputSrtPath: map['output_srt_path'] as String?,
      outputVttPath: map['output_vtt_path'] as String?,
      status: TtsJobStatus.fromString(map['status'] as String? ?? 'queued'),
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
      errorMessage: map['error_message'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
