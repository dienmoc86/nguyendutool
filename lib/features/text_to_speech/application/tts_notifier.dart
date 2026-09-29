import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../core/database/app_database.dart';
import '../../../core/logging/app_logger.dart';
import '../domain/models/tts_options.dart';
import '../domain/models/tts_preset.dart';
import '../domain/models/tts_voice.dart';
import '../domain/services/text_normalization_service.dart';
import '../infrastructure/vietnamese_text_normalization_service.dart';
import '../infrastructure/windows_audio_player_service.dart';
import 'text_extractor_service.dart';
import 'tts_service.dart';
import 'tts_state.dart';

/// Riverpod StateNotifier managing the Text to Speech screen, synthesizer engine,
/// and internal audio player.
class TtsNotifier extends StateNotifier<TtsState> {
  final TtsService _ttsService;
  final TextExtractorService _textExtractor;
  final TextNormalizationService _normalizationService;
  final WindowsAudioPlayerService _audioPlayer;
  final AppDatabase _db;

  StreamSubscription? _playerStatusSub;
  StreamSubscription? _playerPositionSub;
  StreamSubscription? _playerDurationSub;

  TtsNotifier({
    required TtsService ttsService,
    TextExtractorService? textExtractor,
    TextNormalizationService? normalizationService,
    WindowsAudioPlayerService? audioPlayer,
    AppDatabase? database,
  })  : _ttsService = ttsService,
        _textExtractor = textExtractor ?? const TextExtractorService(),
        _normalizationService = normalizationService ?? const VietnameseTextNormalizationService(),
        _audioPlayer = audioPlayer ?? WindowsAudioPlayerService(),
        _db = database ?? AppDatabase(),
        super(const TtsState()) {
    _init();
  }

  Future<void> _init() async {
    _bindPlayerStreams();
    await loadVoices();
    await loadPresets();
  }

  void _bindPlayerStreams() {
    _playerStatusSub = _audioPlayer.statusStream.listen((status) {
      state = state.copyWith(playbackStatus: status);
    });

    _playerPositionSub = _audioPlayer.positionStream.listen((pos) {
      state = state.copyWith(currentPosition: pos);
    });

    _playerDurationSub = _audioPlayer.durationStream.listen((dur) {
      if (dur > Duration.zero) {
        state = state.copyWith(totalDuration: dur);
      }
    });
  }

  /// Loads available voices.
  Future<void> loadVoices() async {
    state = state.copyWith(isLoadingVoices: true, errorMessage: null);
    try {
      final voices = await _ttsService.getVoices(offlineOnly: state.isOfflineOnly);

      // Auto-select Vietnamese voice if available, prioritizing natural AI voices
      TtsVoice? preferred;
      final viVoices = voices.where((v) => v.language.toLowerCase().startsWith('vi')).toList();
      if (viVoices.isNotEmpty) {
        preferred = viVoices.firstWhere(
          (v) => v.id.contains('HoaiMy') || v.id.contains('NamMinh'),
          orElse: () => viVoices.first,
        );
      } else if (voices.isNotEmpty) {
        preferred = voices.first;
      }

      state = state.copyWith(
        availableVoices: voices,
        selectedVoice: preferred,
        isLoadingVoices: false,
      );
    } catch (e, st) {
      AppLogger.error('Failed to load TTS voices', e, st);
      state = state.copyWith(
        isLoadingVoices: false,
        errorMessage: 'Không thể phát hiện giọng đọc hệ thống: $e',
      );
    }
  }

  /// Loads synthesis presets from SQLite.
  Future<void> loadPresets() async {
    try {
      final db = await _db.database;
      final rows = await db.query('tts_presets', orderBy: 'id ASC');
      final presets = rows.map((r) => TtsPreset.fromJson(r)).toList();
      state = state.copyWith(presets: presets);
    } catch (e) {
      AppLogger.warning('Failed to load presets: $e');
    }
  }

  /// Updates text and re-normalizes in the background.
  void setText(String text) {
    final normalized = _normalizationService.normalize(text);
    state = state.copyWith(
      rawText: text,
      normalizedText: normalized,
      errorMessage: null,
      successMessage: null,
    );
  }

  /// Toggles view between raw editor and normalized preview.
  void toggleNormalizedPreview() {
    state = state.copyWith(
      showNormalizedPreview: !state.showNormalizedPreview,
    );
  }

  /// Imports text from a supported file (.txt, .docx, .pdf).
  Future<void> importDocument(String filePath) async {
    try {
      state = state.copyWith(
        currentStage: 'Đang trích xuất văn bản từ tệp...',
        errorMessage: null,
      );

      final text = await _textExtractor.extractTextFromFile(filePath);
      final filename = p.basename(filePath);
      final normalized = _normalizationService.normalize(text);

      state = state.copyWith(
        rawText: text,
        normalizedText: normalized,
        inputSourcePath: filePath,
        inputSourceName: filename,
        currentStage: '',
      );

      AppLogger.info('Imported document for TTS: $filename (${text.length} chars)');
    } catch (e) {
      AppLogger.error('Document import failed for TTS', e);
      state = state.copyWith(
        errorMessage: e.toString().replaceAll('TtsInputException: ', ''),
        currentStage: '',
      );
    }
  }

  /// Clears editor text.
  void clearText() {
    state = state.copyWith(
      rawText: '',
      normalizedText: '',
      clearInputSource: true,
      errorMessage: null,
      successMessage: null,
    );
  }

  /// Selects active voice.
  void selectVoice(TtsVoice voice) {
    state = state.copyWith(selectedVoice: voice);
  }

  /// Toggles Offline Only mode.
  Future<void> setOfflineOnly(bool offline) async {
    state = state.copyWith(
      isOfflineOnly: offline,
      options: state.options.copyWith(offlineOnly: offline),
    );
    await loadVoices();
  }

  void setSpeed(double speed) {
    state = state.copyWith(options: state.options.copyWith(speed: speed));
  }

  void setPitch(double pitch) {
    state = state.copyWith(options: state.options.copyWith(pitch: pitch));
  }

  void setVolume(double volume) {
    state = state.copyWith(options: state.options.copyWith(volume: volume));
  }

  void setAudioFormat(TtsAudioFormat format) {
    state = state.copyWith(options: state.options.copyWith(format: format));
  }

  void setParagraphPause(int ms) {
    state = state.copyWith(options: state.options.copyWith(paragraphPauseMs: ms));
  }

  void setSentencePause(int ms) {
    state = state.copyWith(options: state.options.copyWith(sentencePauseMs: ms));
  }

  /// Applies a preset configuration.
  void applyPreset(TtsPreset preset) {
    state = state.copyWith(
      selectedPreset: preset,
      options: state.options.copyWith(
        speed: preset.speed,
        pitch: preset.pitch,
        volume: preset.volume,
        paragraphPauseMs: preset.paragraphPauseMs,
        sentencePauseMs: preset.sentencePauseMs,
        format: preset.format,
      ),
    );
  }

  /// Synthesizes short preview sample ("Nghe thử") and plays it.
  Future<void> previewVoice() async {
    if (state.selectedVoice == null) {
      state = state.copyWith(errorMessage: 'Vui lòng chọn một giọng đọc.');
      return;
    }

    state = state.copyWith(isPreviewing: true, errorMessage: null);

    try {
      final sampleAudioPath = await _ttsService.previewVoice(
        voice: state.selectedVoice!,
        speed: state.options.speed,
        pitch: state.options.pitch,
      );

      state = state.copyWith(
        isPreviewing: false,
        currentAudioPath: sampleAudioPath,
      );

      // Play preview
      await _audioPlayer.open(sampleAudioPath);
      await _audioPlayer.play();
    } catch (e) {
      AppLogger.error('Voice preview failed', e);
      state = state.copyWith(
        isPreviewing: false,
        errorMessage: 'Lỗi khi nghe thử giọng đọc: $e',
      );
    }
  }

  /// Starts speech synthesis job for the current text.
  Future<void> generateSpeech() async {
    if (state.rawText.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Văn bản rỗng. Vui lòng nhập hoặc mở tài liệu.');
      return;
    }

    if (state.selectedVoice == null) {
      state = state.copyWith(errorMessage: 'Vui lòng chọn giọng đọc.');
      return;
    }

    state = state.copyWith(
      isSynthesizing: true,
      synthesisProgress: 0.0,
      currentStage: 'Chuẩn bị dữ liệu và phân đoạn văn bản...',
      errorMessage: null,
      successMessage: null,
    );

    try {
      final title = state.inputSourceName ??
          (state.rawText.length > 30 ? '${state.rawText.substring(0, 30)}...' : state.rawText);

      final preparedJob = await _ttsService.prepareJob(
        title: title,
        rawText: state.rawText,
        inputSource: state.inputSourcePath != null ? 'file' : 'manual',
        inputPath: state.inputSourcePath,
        voice: state.selectedVoice!,
        options: state.options,
      );

      state = state.copyWith(activeJob: preparedJob);

      final result = await _ttsService.executeJob(
        jobId: preparedJob.id,
        onProgress: (job, progress, stage) {
          state = state.copyWith(
            activeJob: job,
            synthesisProgress: progress,
            currentStage: stage,
          );
        },
      );

      state = state.copyWith(
        isSynthesizing: false,
        synthesisProgress: 1.0,
        currentStage: 'Đã hoàn thành!',
        currentAudioPath: result.audioPath,
        totalDuration: Duration(milliseconds: result.durationMs),
        timingSegments: result.timingSegments,
        successMessage: 'Xuất âm thanh thành công: ${p.basename(result.audioPath)}',
      );

      // Load final audio into player
      await _audioPlayer.open(result.audioPath);
    } catch (e) {
      AppLogger.error('Speech generation failed', e);
      state = state.copyWith(
        isSynthesizing: false,
        errorMessage: 'Quá trình tổng hợp âm thanh thất bại: $e',
      );
    }
  }

  /// Cancels active speech generation.
  void cancelSynthesis() {
    if (state.activeJob != null) {
      _ttsService.cancelJob(state.activeJob!.id);
      state = state.copyWith(
        isSynthesizing: false,
        currentStage: 'Đã hủy tác vụ.',
      );
    }
  }

  /// Audio Player Controls
  Future<void> playAudio() async {
    await _audioPlayer.play();
  }

  Future<void> pauseAudio() async {
    await _audioPlayer.pause();
  }

  Future<void> stopAudio() async {
    await _audioPlayer.stop();
  }

  Future<void> seekAudio(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> setPlaybackVolume(double volume) async {
    state = state.copyWith(playbackVolume: volume);
    await _audioPlayer.setVolume(volume);
  }

  @override
  void dispose() {
    _playerStatusSub?.cancel();
    _playerPositionSub?.cancel();
    _playerDurationSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}
