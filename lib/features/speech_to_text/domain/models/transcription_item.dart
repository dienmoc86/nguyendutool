import '../../../../core/ai/ai_model_config.dart';

/// Status of the speech-to-text / media transcription pipeline.
enum TranscribeStatus {
  idle,
  extractingAudio,
  uploading,
  transcribing,
  completed,
  failed,
}

extension TranscribeStatusExtension on TranscribeStatus {
  String get label {
    switch (this) {
      case TranscribeStatus.idle:
        return 'Sẵn sàng';
      case TranscribeStatus.extractingAudio:
        return 'Đang tối ưu tệp âm thanh qua FFmpeg...';
      case TranscribeStatus.uploading:
        return 'Đang tải dữ liệu lên Google Gemini AI...';
      case TranscribeStatus.transcribing:
        return 'Google Gemini đang phân tích giọng nói tiếng Việt...';
      case TranscribeStatus.completed:
        return 'Gỡ băng hoàn tất';
      case TranscribeStatus.failed:
        return 'Thất bại';
    }
  }

  bool get isProcessing =>
      this == TranscribeStatus.extractingAudio ||
      this == TranscribeStatus.uploading ||
      this == TranscribeStatus.transcribing;
}

/// Options configured by teacher for transcription.
class TranscribeOptions {
  final bool includeTimestamps;
  final bool identifySpeakers;
  final bool generateSummary;
  final String model;

  const TranscribeOptions({
    this.includeTimestamps = true,
    this.identifySpeakers = true,
    this.generateSummary = true,
    this.model = AiModelConfig.defaultModel,
  });

  TranscribeOptions copyWith({
    bool? includeTimestamps,
    bool? identifySpeakers,
    bool? generateSummary,
    String? model,
  }) {
    return TranscribeOptions(
      includeTimestamps: includeTimestamps ?? this.includeTimestamps,
      identifySpeakers: identifySpeakers ?? this.identifySpeakers,
      generateSummary: generateSummary ?? this.generateSummary,
      model: model ?? this.model,
    );
  }
}

/// Individual dialogue segment with timestamp & speaker.
class TranscriptionSegment {
  final String timestamp;
  final String speaker;
  final String text;

  const TranscriptionSegment({
    required this.timestamp,
    required this.speaker,
    required this.text,
  });
}

/// Complete output result from Gemini Speech-to-Text transcription.
class TranscriptionResult {
  final String rawResponse;
  final String fullTranscript;
  final String? summary;
  final List<TranscriptionSegment> segments;
  final String sourceFilePath;
  final String sourceFileName;
  final int sourceFileSize;
  final String modelUsed;
  final int? durationSeconds;
  final DateTime createdAt;

  const TranscriptionResult({
    required this.rawResponse,
    required this.fullTranscript,
    this.summary,
    this.segments = const [],
    required this.sourceFilePath,
    required this.sourceFileName,
    required this.sourceFileSize,
    required this.modelUsed,
    this.durationSeconds,
    required this.createdAt,
  });

  /// Formatted duration string e.g. "04:35" or "01:12:40"
  String get formattedDuration {
    if (durationSeconds == null || durationSeconds! <= 0) return 'Tự động';
    final d = Duration(seconds: durationSeconds!);
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Formatted file size string e.g. "14.2 MB"
  String get formattedFileSize {
    if (sourceFileSize < 1024) return '$sourceFileSize B';
    if (sourceFileSize < 1024 * 1024) {
      return '${(sourceFileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sourceFileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
