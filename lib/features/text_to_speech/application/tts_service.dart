import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/jobs/data/job_repository.dart';
import '../../../core/jobs/domain/job_model.dart';
import '../../../core/jobs/domain/job_status.dart';
import '../../../core/jobs/domain/job_type.dart';
import '../../../core/logging/app_logger.dart';
import '../../file_library/domain/file_entry.dart';
import '../../file_library/infrastructure/file_repository.dart';
import '../domain/models/tts_chunk.dart';
import '../domain/models/tts_options.dart';
import '../domain/models/tts_provider_info.dart';
import '../domain/models/tts_request.dart';
import '../domain/models/tts_result.dart';
import '../domain/models/tts_synthesis_job.dart';
import '../domain/models/tts_voice.dart';
import '../domain/services/text_chunker.dart';
import '../domain/services/text_normalization_service.dart';
import '../domain/services/tts_provider.dart';
import '../infrastructure/audio_assembly_service.dart';
import '../infrastructure/azure_speech_provider.dart';
import '../infrastructure/google_cloud_tts_provider.dart';
import '../infrastructure/pronunciation_dictionary_service.dart';
import '../infrastructure/rule_based_text_chunker.dart';
import '../infrastructure/subtitle_generator.dart';
import '../infrastructure/vietnamese_text_normalization_service.dart';
import '../infrastructure/windows_speech_synthesizer_provider.dart';
import '../infrastructure/natural_vietnamese_tts_provider.dart';
import '../infrastructure/piper_tts_provider.dart';
import 'text_extractor_service.dart';

/// Central application orchestrator for Text to Speech synthesis in NguyenDu Tool.
/// Manages text extraction, Vietnamese normalization, pronunciation dictionary,
/// chunking, multi-provider dispatch, resumable execution, audio assembly,
/// subtitle generation, and Document Library cataloging.
class TtsService {
  final AppDatabase _db;
  final JobRepository _jobRepository;
  final FileRepository _fileRepository;
  final TextExtractorService _textExtractor;
  final TextNormalizationService _normalizationService;
  final PronunciationDictionaryService _pronunciationService;
  final TextChunker _chunker;
  final AudioAssemblyService _assemblyService;
  final SubtitleGenerator _subtitleGenerator;

  final Map<String, TtsProvider> _providers = {};
  final Set<String> _activeJobCancellations = {};

  TtsService({
    AppDatabase? database,
    JobRepository? jobRepository,
    FileRepository? fileRepository,
    TextExtractorService? textExtractor,
    TextNormalizationService? normalizationService,
    PronunciationDictionaryService? pronunciationService,
    TextChunker? chunker,
    AudioAssemblyService? assemblyService,
    SubtitleGenerator? subtitleGenerator,
    List<TtsProvider>? customProviders,
  })  : _db = database ?? AppDatabase(),
        _jobRepository = jobRepository ?? JobRepository(database ?? AppDatabase()),
        _fileRepository = fileRepository ?? FileRepository(database ?? AppDatabase()),
        _textExtractor = textExtractor ?? const TextExtractorService(),
        _normalizationService = normalizationService ?? const VietnameseTextNormalizationService(),
        _pronunciationService = pronunciationService ?? PronunciationDictionaryService(database: database),
        _chunker = chunker ?? const RuleBasedTextChunker(),
        _assemblyService = assemblyService ?? AudioAssemblyService(),
        _subtitleGenerator = subtitleGenerator ?? const SubtitleGenerator() {
    // Register default providers
    if (customProviders != null) {
      for (final p in customProviders) {
        _providers[p.info.id] = p;
      }
    } else {
      final winTts = WindowsSpeechSynthesizerProvider();
      _providers[winTts.info.id] = winTts;

      final naturalViTts = NaturalVietnameseTtsProvider();
      _providers[naturalViTts.info.id] = naturalViTts;

      final piperTts = PiperTtsProvider();
      _providers[piperTts.info.id] = piperTts;

      final googleTts = GoogleCloudTtsProvider();
      _providers[googleTts.info.id] = googleTts;

      final azureTts = AzureSpeechProvider();
      _providers[azureTts.info.id] = azureTts;
    }
  }

  /// Lists all registered TTS providers and their status.
  List<TtsProviderInfo> getProviders() {
    return _providers.values.map((p) => p.info).toList();
  }

  /// Gets a specific provider by ID.
  TtsProvider? getProvider(String providerId) => _providers[providerId];

  /// Discovers available voices across providers.
  /// If [offlineOnly] is true, only local Windows voices are returned.
  Future<List<TtsVoice>> getVoices({bool offlineOnly = false}) async {
    final allVoices = <TtsVoice>[];

    for (final provider in _providers.values) {
      if (offlineOnly && !provider.info.isOffline) {
        continue;
      }

      // Initialize provider to discover voices if not already initialized
      if (!provider.isAvailable) {
        try {
          await provider.initialize();
        } catch (e) {
          AppLogger.warning('Failed to initialize provider ${provider.info.id}: $e');
        }
      }

      if (!provider.isAvailable) {
        continue;
      }

      try {
        final voices = await provider.getVoices();
        allVoices.addAll(voices);
      } catch (e) {
        AppLogger.warning('Failed to get voices from provider ${provider.info.id}: $e');
      }
    }

    return allVoices;
  }

  /// Synthesizes a short voice preview sample ("Nghe thử").
  Future<String> previewVoice({
    required TtsVoice voice,
    String? previewText,
    double speed = 1.0,
    double pitch = 1.0,
  }) async {
    final provider = _providers[voice.providerId];
    if (provider == null) {
      throw TtsEngineUnavailableException('Nhà cung cấp giọng nói không khả dụng: ${voice.providerId}');
    }

    final sampleText = previewText ??
        (voice.language.startsWith('vi')
            ? 'Xin chào, đây là giọng đọc thử của NguyenDu Tool.'
            : 'Hello, this is a speech preview from NguyenDu Tool.');

    final tempDir = Directory(p.join(Directory.systemTemp.path, 'nguyendu_tts_previews'));
    if (!tempDir.existsSync()) {
      tempDir.createSync(recursive: true);
    }

    final previewAudioPath = p.join(
      tempDir.path,
      'preview_${voice.id.replaceAll(RegExp(r'[^\w]'), '_')}_${DateTime.now().millisecondsSinceEpoch}.wav',
    );

    final request = TtsRequest(
      text: sampleText,
      voice: voice,
      options: TtsOptions(speed: speed, pitch: pitch),
      outputPath: previewAudioPath,
      isPreview: true,
    );

    final audioPath = await provider.synthesize(request);
    return audioPath;
  }

  /// Synthesizes a text segment directly using the specified voice and returns the generated WAV/MP3 path.
  Future<String> synthesizeDirect({
    required String text,
    required TtsVoice voice,
    required String outputPath,
    TtsOptions options = const TtsOptions(speed: 1.0, format: TtsAudioFormat.wav),
  }) async {
    final provider = _providers[voice.providerId];
    if (provider == null) {
      throw TtsEngineUnavailableException('Nhà cung cấp giọng nói không khả dụng: ${voice.providerId}');
    }
    final req = TtsRequest(
      text: text,
      voice: voice,
      options: options,
      outputPath: outputPath,
    );
    return await provider.synthesize(req);
  }

  /// Extracts text from a document or returns raw text.
  Future<String> extractText(String input, {String? filePath}) async {
    if (filePath != null && filePath.isNotEmpty) {
      return await _textExtractor.extractTextFromFile(filePath);
    }
    return input;
  }

  /// Creates and initializes a synthesis job with normalized text and pre-computed chunks.
  Future<TtsSynthesisJob> prepareJob({
    required String title,
    required String rawText,
    required String inputSource,
    String? inputPath,
    required TtsVoice voice,
    TtsOptions options = const TtsOptions(),
  }) async {
    final jobId = const Uuid().v4();
    final now = DateTime.now();

    // 1. Vietnamese normalization
    String normalized = _normalizationService.normalize(rawText);

    // 2. Apply local pronunciation dictionary overrides
    normalized = await _pronunciationService.applyDictionary(normalized);

    // 3. Chunk text respecting provider limit
    final provider = _providers[voice.providerId];
    final maxChars = provider?.info.maxCharactersPerRequest ?? 2000;
    final chunks = _chunker.chunkText(
      text: normalized,
      jobId: jobId,
      maxCharactersPerChunk: maxChars,
    );

    final job = TtsSynthesisJob(
      id: jobId,
      title: title.isEmpty ? 'Tài liệu âm thanh ${now.day}/${now.month}' : title,
      inputSource: inputSource,
      inputPath: inputPath,
      rawText: rawText,
      normalizedText: normalized,
      providerId: voice.providerId,
      voiceId: voice.id,
      voiceName: voice.name,
      language: voice.language,
      audioFormat: options.format,
      speed: options.speed,
      pitch: options.pitch,
      volume: options.volume,
      totalChunks: chunks.length,
      completedChunks: 0,
      status: TtsJobStatus.queued,
      progress: 0.0,
      createdAt: now,
      updatedAt: now,
    );

    // Persist job in SQLite
    final db = await _db.database;
    await db.insert('tts_jobs', job.toMap());

    // Persist chunks in SQLite
    final batch = db.batch();
    for (final c in chunks) {
      batch.insert('tts_chunks', {
        'id': c.id,
        'job_id': c.jobId,
        'chunk_index': c.index,
        'text': c.text,
        'character_count': c.characterCount,
        'audio_path': c.audioPath,
        'duration_ms': c.durationMs,
        'start_ms': c.startMs,
        'end_ms': c.endMs,
        'status': c.status.name,
        'retry_count': c.retryCount,
        'error_message': c.errorMessage,
        'created_at': now.toIso8601String(),
      });
    }
    await batch.commit(noResult: true);

    // Register with App Job System
    await _jobRepository.createJob(JobModel(
      id: jobId,
      jobType: JobType.ttsGenerate,
      moduleType: 'tts',
      status: JobStatus.queued,
      progress: 0.0,
      inputJson: '{"title":"${job.title}","voice":"${job.voiceName}","chunks":${chunks.length}}',
      createdAt: now,
    ));

    AppLogger.info('Prepared TTS job: $jobId with ${chunks.length} chunks.');
    return job;
  }

  /// Cancels an ongoing or queued job.
  void cancelJob(String jobId) {
    _activeJobCancellations.add(jobId);
    AppLogger.warning('Requested cancellation for TTS job: $jobId');
  }

  /// Executes or resumes synthesis for a prepared job.
  Future<TtsResult> executeJob({
    required String jobId,
    void Function(TtsSynthesisJob updatedJob, double progress, String stage)? onProgress,
  }) async {
    final db = await _db.database;
    final jobRows = await db.query('tts_jobs', where: 'id = ?', whereArgs: [jobId]);
    if (jobRows.isEmpty) {
      throw TtsSynthesisException('Không tìm thấy bản ghi tác vụ: $jobId');
    }

    var job = TtsSynthesisJob.fromMap(jobRows.first);

    if (_activeJobCancellations.contains(jobId)) {
      await _cancelJobRecord(job);
      _activeJobCancellations.remove(jobId);
      throw const TtsCancelledException('Tác vụ đọc đã bị hủy bởi người dùng.');
    }

    final provider = _providers[job.providerId];
    if (provider == null || !provider.isAvailable) {
      await _failJob(job, 'Bộ máy TTS không khả dụng hoặc chưa được cấu hình: ${job.providerId}');
      throw TtsEngineUnavailableException('Bộ máy TTS không khả dụng: ${job.providerId}');
    }

    // Voice verification
    final voices = await provider.getVoices();
    final voice = voices.firstWhere(
      (v) => v.id == job.voiceId,
      orElse: () => TtsVoice(
        id: job.voiceId,
        name: job.voiceName,
        language: job.language,
        locale: job.language,
        providerId: job.providerId,
        isOffline: provider.info.isOffline,
      ),
    );

    // Update job status to synthesizing
    job = job.copyWith(
      status: TtsJobStatus.synthesizing,
      updatedAt: DateTime.now(),
    );
    await _updateJob(job);
    await _jobRepository.updateJobStatus(jobId, JobStatus.running);

    // Working directory for chunks
    final appTempDir = Directory(p.join(Directory.systemTemp.path, 'nguyendu_tts', jobId));
    if (!appTempDir.existsSync()) {
      appTempDir.createSync(recursive: true);
    }

    // Load chunks
    final chunkRows = await db.query(
      'tts_chunks',
      where: 'job_id = ?',
      whereArgs: [jobId],
      orderBy: 'chunk_index ASC',
    );
    var chunks = chunkRows.map((r) => _mapToChunk(r)).toList();

    int completedCount = chunks.where((c) => c.status == TtsChunkStatus.completed).length;

    // 2. Synthesize each chunk
    final options = TtsOptions(
      format: job.audioFormat,
      speed: job.speed,
      pitch: job.pitch,
      volume: job.volume,
    );

    for (int i = 0; i < chunks.length; i++) {
      if (_activeJobCancellations.contains(jobId)) {
        await _cancelJobRecord(job);
        throw const TtsCancelledException('Tác vụ đọc đã bị hủy bởi người dùng.');
      }

      var chunk = chunks[i];
      if (chunk.status == TtsChunkStatus.completed &&
          chunk.audioPath != null &&
          File(chunk.audioPath!).existsSync()) {
        continue; // Already synthesized
      }

      if (chunk.status == TtsChunkStatus.disabled) {
        continue;
      }

      final chunkAudioPath = p.join(
        appTempDir.path,
        'chunk_${chunk.index.toString().padLeft(4, '0')}.wav',
      );

      // Bounded retry (max 3 tries)
      bool success = false;
      String? lastError;
      int retries = 0;

      while (!success && retries < 3) {
        if (_activeJobCancellations.contains(jobId)) {
          await _cancelJobRecord(job);
          throw const TtsCancelledException('Tác vụ đọc đã bị hủy bởi người dùng.');
        }

        try {
          chunk = chunk.copyWith(status: TtsChunkStatus.synthesizing);
          await _updateChunk(chunk);

          final req = TtsRequest(
            text: chunk.text,
            voice: voice,
            options: options,
            chunkIndex: chunk.index,
            outputPath: chunkAudioPath,
          );

          final synthesizedPath = await provider.synthesize(req);
          final audioFile = File(synthesizedPath);

          if (!audioFile.existsSync() || audioFile.lengthSync() < 44) {
            throw TtsSynthesisException('Tệp âm thanh đoạn ${chunk.index} rỗng hoặc không hợp lệ.');
          }

          final wavInfo = await _assemblyService.validateAudio(synthesizedPath, TtsAudioFormat.wav);
          final durationMs = ((wavInfo.durationSeconds ?? 0.0) * 1000).round();

          chunk = chunk.copyWith(
            status: TtsChunkStatus.completed,
            audioPath: synthesizedPath,
            durationMs: durationMs,
            errorMessage: null,
          );
          await _updateChunk(chunk);
          chunks[i] = chunk;
          success = true;
          completedCount++;
        } catch (e) {
          retries++;
          lastError = e.toString();
          AppLogger.warning('Chunk ${chunk.index} synthesis attempt $retries failed: $e');
          await Future.delayed(Duration(milliseconds: 200 * retries));
        }
      }

      if (!success) {
        chunk = chunk.copyWith(
          status: TtsChunkStatus.failed,
          retryCount: retries,
          errorMessage: lastError,
        );
        await _updateChunk(chunk);
        chunks[i] = chunk;

        await _failJob(job, 'Lỗi tổng hợp tại đoạn ${chunk.index}: $lastError');
        throw TtsSynthesisException('Tổng hợp thất bại tại đoạn ${chunk.index}: $lastError');
      }

      final chunkProgress = (completedCount / chunks.length) * 0.7; // 0 to 70%
      job = job.copyWith(
        completedChunks: completedCount,
        progress: chunkProgress,
        updatedAt: DateTime.now(),
      );
      await _updateJob(job);
      onProgress?.call(job, chunkProgress, 'Đang đọc đoạn $completedCount / ${chunks.length}...');
    }

    // 3. Audio Assembly (70% -> 85%)
    job = job.copyWith(
      status: TtsJobStatus.assembling,
      progress: 0.75,
      updatedAt: DateTime.now(),
    );
    await _updateJob(job);
    onProgress?.call(job, 0.75, 'Đang ghép nối các đoạn âm thanh...');

    final validChunks = chunks
        .where((c) => c.status == TtsChunkStatus.completed && c.audioPath != null)
        .toList();

    final targetExtension = job.audioFormat == TtsAudioFormat.mp3 ? '.mp3' : '.wav';
    final intermediateAudioPath = p.join(appTempDir.path, '${jobId}_output$targetExtension');

    final assemblyResult = await _assemblyService.assembleAudio(
      chunkAudioPaths: validChunks.map((c) => c.audioPath!).toList(),
      chunkTexts: validChunks.map((c) => c.text).toList(),
      isParagraphBoundaries: validChunks.map((c) => c.isParagraphBoundary).toList(),
      outputAudioPath: intermediateAudioPath,
      options: options,
      onProgress: (prog, stage) {
        final scaled = 0.7 + (prog * 0.25);
        job = job.copyWith(progress: scaled, updatedAt: DateTime.now());
        onProgress?.call(job, scaled, stage);
      },
    );

    final timingSegments = assemblyResult.timingSegments;

    // 4. Subtitle Export (SRT / VTT)
    String? srtPath;
    String? vttPath;
    if (options.generateSubtitles) {
      srtPath = p.join(appTempDir.path, '${jobId}_subtitles.srt');
      vttPath = p.join(appTempDir.path, '${jobId}_subtitles.vtt');
      await _subtitleGenerator.exportSrtToFile(timingSegments, srtPath);
      await _subtitleGenerator.exportVttToFile(timingSegments, vttPath);
    }

    // 5. Move output to user Document / Export folder
    final exportDir = Directory(p.join(Directory.current.path, 'exports', 'audio'));
    if (!exportDir.existsSync()) {
      exportDir.createSync(recursive: true);
    }

    final safeTitle = job.title.replaceAll(RegExp(r'[^\w\s\-]'), '_').trim().replaceAll(' ', '_');
    final permanentAudioPath = p.join(exportDir.path, '${safeTitle}_${job.voiceName}$targetExtension');

    final finalAudioFile = File(intermediateAudioPath);
    final movedAudio = await finalAudioFile.copy(permanentAudioPath);

    String? permanentSrtPath;
    String? permanentVttPath;
    if (srtPath != null && File(srtPath).existsSync()) {
      permanentSrtPath = p.join(exportDir.path, '${safeTitle}_${job.voiceName}.srt');
      await File(srtPath).copy(permanentSrtPath);
    }
    if (vttPath != null && File(vttPath).existsSync()) {
      permanentVttPath = p.join(exportDir.path, '${safeTitle}_${job.voiceName}.vtt');
      await File(vttPath).copy(permanentVttPath);
    }

    // 6. Add to Document Library (Req 52)
    final fileEntry = FileEntry(
      id: const Uuid().v4(),
      originalName: p.basename(permanentAudioPath),
      localPath: permanentAudioPath,
      mimeType: job.audioFormat.mimeType,
      size: movedAudio.lengthSync(),
      createdAt: DateTime.now(),
    );
    await _fileRepository.addFile(fileEntry);

    // 7. Clean up temp chunks
    try {
      if (appTempDir.existsSync()) {
        appTempDir.deleteSync(recursive: true);
      }
    } catch (_) {}

    // 8. Update final job status
    job = job.copyWith(
      status: TtsJobStatus.completed,
      progress: 1.0,
      totalDurationMs: assemblyResult.durationMs,
      outputAudioPath: permanentAudioPath,
      outputSrtPath: permanentSrtPath,
      outputVttPath: permanentVttPath,
      updatedAt: DateTime.now(),
    );
    await _updateJob(job);
    await _jobRepository.updateJobStatus(jobId, JobStatus.completed);

    onProgress?.call(job, 1.0, 'Đã hoàn thành xuất âm thanh.');

    return TtsResult(
      audioPath: permanentAudioPath,
      format: job.audioFormat,
      durationMs: assemblyResult.durationMs,
      fileSize: movedAudio.lengthSync(),
      timingSegments: timingSegments,
      srtPath: permanentSrtPath,
      vttPath: permanentVttPath,
    );

  }

  /// Retries a specific chunk within a job.
  Future<void> retryChunk(String jobId, int chunkIndex) async {
    final db = await _db.database;
    await db.update(
      'tts_chunks',
      {
        'status': TtsChunkStatus.pending.name,
        'error_message': null,
      },
      where: 'job_id = ? AND chunk_index = ?',
      whereArgs: [jobId, chunkIndex],
    );
  }

  /// Processes a batch of TTS requests sequentially (Req 31).
  Future<List<TtsResult>> processBatch({
    required List<TtsRequest> requests,
    void Function(int completed, int total, String currentItem)? onBatchProgress,
  }) async {
    final results = <TtsResult>[];

    for (int i = 0; i < requests.length; i++) {
      final req = requests[i];
      onBatchProgress?.call(i, requests.length, 'Tài liệu ${i + 1}/${requests.length}');

      final job = await prepareJob(
        title: 'Tài liệu batch ${i + 1}',
        rawText: req.text,
        inputSource: 'batch',
        voice: req.voice,
        options: req.options,
      );

      final result = await executeJob(jobId: job.id);
      results.add(result);
    }

    onBatchProgress?.call(requests.length, requests.length, 'Hoàn thành toàn bộ');
    return results;
  }

  Future<void> _updateJob(TtsSynthesisJob job) async {
    final db = await _db.database;
    await db.update('tts_jobs', job.toMap(), where: 'id = ?', whereArgs: [job.id]);
  }

  Future<void> _updateChunk(TtsChunk chunk) async {
    final db = await _db.database;
    await db.update(
      'tts_chunks',
      {
        'status': chunk.status.name,
        'audio_path': chunk.audioPath,
        'duration_ms': chunk.durationMs,
        'retry_count': chunk.retryCount,
        'error_message': chunk.errorMessage,
      },
      where: 'id = ?',
      whereArgs: [chunk.id],
    );
  }

  Future<void> _failJob(TtsSynthesisJob job, String message) async {
    job = job.copyWith(
      status: TtsJobStatus.failed,
      errorMessage: message,
      updatedAt: DateTime.now(),
    );
    await _updateJob(job);
    await _jobRepository.updateJobStatus(job.id, JobStatus.failed, errorMessage: message);
  }

  Future<void> _cancelJobRecord(TtsSynthesisJob job) async {
    job = job.copyWith(
      status: TtsJobStatus.cancelled,
      updatedAt: DateTime.now(),
    );
    await _updateJob(job);
    await _jobRepository.updateJobStatus(job.id, JobStatus.cancelled);
  }

  TtsChunk _mapToChunk(Map<String, dynamic> r) {
    return TtsChunk(
      id: r['id'] as String,
      jobId: r['job_id'] as String,
      index: r['chunk_index'] as int,
      text: r['text'] as String,
      characterCount: r['character_count'] as int,
      audioPath: r['audio_path'] as String?,
      durationMs: r['duration_ms'] as int? ?? 0,
      startMs: r['start_ms'] as int? ?? 0,
      endMs: r['end_ms'] as int? ?? 0,
      status: TtsChunkStatus.values.firstWhere(
        (e) => e.name == r['status'],
        orElse: () => TtsChunkStatus.pending,
      ),
      retryCount: r['retry_count'] as int? ?? 0,
      errorMessage: r['error_message'] as String?,
    );
  }
}
