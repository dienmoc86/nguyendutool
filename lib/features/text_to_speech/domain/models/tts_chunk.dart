/// Status of an individual chunk during synthesis.
enum TtsChunkStatus {
  pending,
  synthesizing,
  completed,
  failed,
  disabled;

  String get label {
    switch (this) {
      case TtsChunkStatus.pending:
        return 'Chờ tổng hợp';
      case TtsChunkStatus.synthesizing:
        return 'Đang đọc...';
      case TtsChunkStatus.completed:
        return 'Hoàn thành';
      case TtsChunkStatus.failed:
        return 'Thất bại';
      case TtsChunkStatus.disabled:
        return 'Bỏ qua';
    }
  }
}

/// Represents an atomic chunk of text for synthesis, enabling resumable jobs and selective retries.
class TtsChunk {
  final String id;
  final String jobId;
  final int index;
  final String text;
  final int characterCount;
  final String? audioPath;
  final int durationMs;
  final int startMs;
  final int endMs;
  final TtsChunkStatus status;
  final int retryCount;
  final String? errorMessage;
  final bool isParagraphBoundary;

  const TtsChunk({
    required this.id,
    required this.jobId,
    required this.index,
    required this.text,
    required this.characterCount,
    this.audioPath,
    this.durationMs = 0,
    this.startMs = 0,
    this.endMs = 0,
    this.status = TtsChunkStatus.pending,
    this.retryCount = 0,
    this.errorMessage,
    this.isParagraphBoundary = false,
  });

  TtsChunk copyWith({
    String? id,
    String? jobId,
    int? index,
    String? text,
    int? characterCount,
    String? audioPath,
    int? durationMs,
    int? startMs,
    int? endMs,
    TtsChunkStatus? status,
    int? retryCount,
    String? errorMessage,
    bool? isParagraphBoundary,
  }) {
    return TtsChunk(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      index: index ?? this.index,
      text: text ?? this.text,
      characterCount: characterCount ?? this.characterCount,
      audioPath: audioPath ?? this.audioPath,
      durationMs: durationMs ?? this.durationMs,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: errorMessage ?? this.errorMessage,
      isParagraphBoundary: isParagraphBoundary ?? this.isParagraphBoundary,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'jobId': jobId,
        'index': index,
        'text': text,
        'characterCount': characterCount,
        'audioPath': audioPath,
        'durationMs': durationMs,
        'startMs': startMs,
        'endMs': endMs,
        'status': status.name,
        'retryCount': retryCount,
        'errorMessage': errorMessage,
        'isParagraphBoundary': isParagraphBoundary,
      };

  factory TtsChunk.fromJson(Map<String, dynamic> json) => TtsChunk(
        id: json['id'] as String? ?? '',
        jobId: json['jobId'] as String? ?? '',
        index: json['index'] as int? ?? 0,
        text: json['text'] as String? ?? '',
        characterCount: json['characterCount'] as int? ?? 0,
        audioPath: json['audioPath'] as String?,
        durationMs: json['durationMs'] as int? ?? 0,
        startMs: json['startMs'] as int? ?? 0,
        endMs: json['endMs'] as int? ?? 0,
        status: TtsChunkStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => TtsChunkStatus.pending,
        ),
        retryCount: json['retryCount'] as int? ?? 0,
        errorMessage: json['errorMessage'] as String?,
        isParagraphBoundary: json['isParagraphBoundary'] as bool? ?? false,
      );
}
