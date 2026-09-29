import '../domain/models/tts_chunk.dart';
import '../domain/models/tts_options.dart';
import '../domain/models/tts_preset.dart';
import '../domain/models/tts_synthesis_job.dart';
import '../domain/models/tts_timing_segment.dart';
import '../domain/models/tts_voice.dart';

/// State of the internal audio player.
enum AudioPlaybackStatus {
  idle,
  loading,
  playing,
  paused,
  stopped,
  completed,
  error;

  String get label {
    switch (this) {
      case AudioPlaybackStatus.idle:
        return 'Chưa sẵn sàng';
      case AudioPlaybackStatus.loading:
        return 'Đang nạp âm thanh...';
      case AudioPlaybackStatus.playing:
        return 'Đang phát';
      case AudioPlaybackStatus.paused:
        return 'Tạm dừng';
      case AudioPlaybackStatus.stopped:
        return 'Đã dừng';
      case AudioPlaybackStatus.completed:
        return 'Đã phát xong';
      case AudioPlaybackStatus.error:
        return 'Lỗi phát âm thanh';
    }
  }
}

/// Comprehensive UI State for the Text to Speech module.
class TtsState {
  final String rawText;
  final String normalizedText;
  final bool showNormalizedPreview;
  final String? inputSourcePath;
  final String? inputSourceName;

  final List<TtsVoice> availableVoices;
  final TtsVoice? selectedVoice;
  final bool isOfflineOnly;
  final bool isLoadingVoices;

  final List<TtsPreset> presets;
  final TtsPreset? selectedPreset;

  final TtsOptions options;

  final bool isSynthesizing;
  final bool isPreviewing;
  final double synthesisProgress; // 0.0 to 1.0
  final String currentStage;
  final TtsSynthesisJob? activeJob;
  final List<TtsChunk> currentChunks;

  // Audio Playback
  final AudioPlaybackStatus playbackStatus;
  final String? currentAudioPath;
  final Duration currentPosition;
  final Duration totalDuration;
  final double playbackVolume;
  final List<TtsTimingSegment> timingSegments;

  final String? errorMessage;
  final String? successMessage;

  const TtsState({
    this.rawText = '',
    this.normalizedText = '',
    this.showNormalizedPreview = false,
    this.inputSourcePath,
    this.inputSourceName,
    this.availableVoices = const [],
    this.selectedVoice,
    this.isOfflineOnly = false,
    this.isLoadingVoices = false,
    this.presets = const [],
    this.selectedPreset,
    this.options = const TtsOptions(),
    this.isSynthesizing = false,
    this.isPreviewing = false,
    this.synthesisProgress = 0.0,
    this.currentStage = '',
    this.activeJob,
    this.currentChunks = const [],
    this.playbackStatus = AudioPlaybackStatus.idle,
    this.currentAudioPath,
    this.currentPosition = Duration.zero,
    this.totalDuration = Duration.zero,
    this.playbackVolume = 1.0,
    this.timingSegments = const [],
    this.errorMessage,
    this.successMessage,
  });

  int get characterCount => rawText.length;
  int get wordCount => rawText.trim().isEmpty ? 0 : rawText.trim().split(RegExp(r'\s+')).length;

  /// Estimated duration based on average Vietnamese speech rate (150 words per minute).
  Duration get estimatedDuration {
    if (wordCount == 0) return Duration.zero;
    final speed = options.speed > 0 ? options.speed : 1.0;
    final seconds = ((wordCount / 150) * 60 / speed).round();
    return Duration(seconds: seconds);
  }

  bool get hasVietnameseVoice => availableVoices.any(
        (v) => v.language.toLowerCase().startsWith('vi'),
      );

  TtsState copyWith({
    String? rawText,
    String? normalizedText,
    bool? showNormalizedPreview,
    String? inputSourcePath,
    String? inputSourceName,
    List<TtsVoice>? availableVoices,
    TtsVoice? selectedVoice,
    bool? isOfflineOnly,
    bool? isLoadingVoices,
    List<TtsPreset>? presets,
    TtsPreset? selectedPreset,
    TtsOptions? options,
    bool? isSynthesizing,
    bool? isPreviewing,
    double? synthesisProgress,
    String? currentStage,
    TtsSynthesisJob? activeJob,
    List<TtsChunk>? currentChunks,
    AudioPlaybackStatus? playbackStatus,
    String? currentAudioPath,
    Duration? currentPosition,
    Duration? totalDuration,
    double? playbackVolume,
    List<TtsTimingSegment>? timingSegments,
    String? errorMessage,
    String? successMessage,
    bool clearInputSource = false,
    bool clearSelectedVoice = false,
  }) {
    return TtsState(
      rawText: rawText ?? this.rawText,
      normalizedText: normalizedText ?? this.normalizedText,
      showNormalizedPreview: showNormalizedPreview ?? this.showNormalizedPreview,
      inputSourcePath: clearInputSource ? null : (inputSourcePath ?? this.inputSourcePath),
      inputSourceName: clearInputSource ? null : (inputSourceName ?? this.inputSourceName),
      availableVoices: availableVoices ?? this.availableVoices,
      selectedVoice: clearSelectedVoice ? null : (selectedVoice ?? this.selectedVoice),
      isOfflineOnly: isOfflineOnly ?? this.isOfflineOnly,
      isLoadingVoices: isLoadingVoices ?? this.isLoadingVoices,
      presets: presets ?? this.presets,
      selectedPreset: selectedPreset ?? this.selectedPreset,
      options: options ?? this.options,
      isSynthesizing: isSynthesizing ?? this.isSynthesizing,
      isPreviewing: isPreviewing ?? this.isPreviewing,
      synthesisProgress: synthesisProgress ?? this.synthesisProgress,
      currentStage: currentStage ?? this.currentStage,
      activeJob: activeJob ?? this.activeJob,
      currentChunks: currentChunks ?? this.currentChunks,
      playbackStatus: playbackStatus ?? this.playbackStatus,
      currentAudioPath: currentAudioPath ?? this.currentAudioPath,
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration: totalDuration ?? this.totalDuration,
      playbackVolume: playbackVolume ?? this.playbackVolume,
      timingSegments: timingSegments ?? this.timingSegments,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}
