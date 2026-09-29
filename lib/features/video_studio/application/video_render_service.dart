import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../core/database/app_database.dart';
import '../../../core/jobs/data/job_repository.dart';
import '../../../core/jobs/domain/job_model.dart';
import '../../../core/jobs/domain/job_status.dart';
import '../../../core/jobs/domain/job_type.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/media/ffmpeg_service.dart';
import '../../../core/media/media_probe_result.dart';
import '../../file_library/domain/file_entry.dart';
import '../../file_library/infrastructure/file_repository.dart';
import '../../text_to_speech/application/tts_service.dart';
import '../../text_to_speech/domain/models/tts_options.dart';
import '../../text_to_speech/domain/models/tts_timing_segment.dart';
import '../../text_to_speech/infrastructure/subtitle_generator.dart';
import '../domain/models/video_project.dart';
import '../domain/models/video_scene.dart';
import '../infrastructure/project_repository.dart';

/// Result report returned upon video render completion.
class VideoRenderResult {
  final bool isSuccess;
  final String outputPath;
  final String projectId;
  final int fileSizeBytes;
  final double durationSeconds;
  final int width;
  final int height;
  final int fps;
  final Duration renderWallTime;
  final String? errorMessage;
  final MediaProbeResult? probeResult;

  const VideoRenderResult({
    required this.isSuccess,
    required this.outputPath,
    required this.projectId,
    required this.fileSizeBytes,
    required this.durationSeconds,
    required this.width,
    required this.height,
    required this.fps,
    required this.renderWallTime,
    this.errorMessage,
    this.probeResult,
  });
}

/// Orchestrates the entire local-first Video Production pipeline:
/// Content -> Scenes -> TTS Voiceover -> Audio Ducking -> Transitions -> Subtitle Burn -> MP4 Render.
class VideoRenderService {
  final FfmpegService _ffmpegService;
  final TtsService _ttsService;
  final ProjectRepository projectRepository;
  final FileRepository _fileRepository;
  final JobRepository _jobRepository;
  final AppDatabase _appDatabase;

  bool _isCancelled = false;

  VideoRenderService({
    FfmpegService? ffmpegService,
    required TtsService ttsService,
    required this.projectRepository,
    required FileRepository fileRepository,
    required JobRepository jobRepository,
    required AppDatabase appDatabase,
  })  : _ffmpegService = ffmpegService ?? FfmpegService.instance,
        _ttsService = ttsService,
        _fileRepository = fileRepository,
        _jobRepository = jobRepository,
        _appDatabase = appDatabase;

  /// Cancels currently executing render pipeline and cleans temporary files.
  Future<void> cancelRender() async {
    _isCancelled = true;
    await _ffmpegService.cancelActiveOperation();
    AppLogger.info('VideoRenderService: render cancelled by user.');
  }

  /// Renders a complete Video Project into a broadcast-quality MP4 file.
  Future<VideoRenderResult> renderProject({
    required VideoProject project,
    void Function(double progress, String stageMessage)? onProgress,
  }) async {
    _isCancelled = false;
    final stopwatch = Stopwatch()..start();
    final settings = project.exportSettings;

    // 0. Ensure FFmpeg is available
    final isAvail = await _ffmpegService.initialize();
    if (!isAvail) {
      throw Exception('FFmpeg không khả dụng trên hệ thống này. Quá trình render video bị chặn.');
    }

    if (project.scenes.isEmpty) {
      throw Exception('Dự án video không có phân cảnh nào để kết xuất.');
    }

    final jobId = 'render_${DateTime.now().millisecondsSinceEpoch}';

    // Register job in JobRepository
    await _jobRepository.createJob(JobModel(
      id: jobId,
      jobType: JobType.videoRender,
      moduleType: 'video_studio',
      status: JobStatus.running,
      progress: 0.05,
      createdAt: DateTime.now(),
      startedAt: DateTime.now(),
    ));

    // Create isolated job temp directory: temp/video/<jobId>/
    final tempDir = Directory(p.join(Directory.systemTemp.path, 'nguyendu_video_render_$jobId'));
    tempDir.createSync(recursive: true);

    try {
      // Stage 1: Preparing & Resolving Settings
      onProgress?.call(0.05, 'Đang chuẩn bị thông số kết xuất...');
      AppLogger.info('Stage 1 [Preparing]: $jobId for project "${project.name}"');

      final (targetWidth, targetHeight) = settings.resolution.getDimensionsFor(project.aspectRatio);
      final fps = settings.fps;

      // Stage 2: Probing Assets & Voiceover Synthesis
      onProgress?.call(0.15, 'Đang chuẩn bị âm thanh và phân cảnh...');
      AppLogger.info('Stage 2 [Voiceover & Assets]: Probing and generating narration voiceovers...');

      final updatedScenes = <VideoScene>[];
      final voiceoverAudioPaths = <String>[];

      for (int i = 0; i < project.scenes.length; i++) {
        if (_isCancelled) throw Exception('CANCELLED');

        var scene = project.scenes[i];

        // Check if scene has narration text that needs TTS synthesis
        if ((scene.voiceoverAudioPath == null || !File(scene.voiceoverAudioPath!).existsSync()) &&
            scene.narrationText != null &&
            scene.narrationText!.trim().isNotEmpty) {
          onProgress?.call(0.20 + (i / project.scenes.length) * 0.15, 'Đang tạo giọng đọc cảnh ${i + 1}/${project.scenes.length}...');

          final voices = await _ttsService.getVoices(offlineOnly: true);
          if (voices.isNotEmpty) {
            final activeVoice = voices.first;
            final sceneAudioPath = p.join(tempDir.path, 'scene_voice_${i + 1}.wav');

            final ttsResult = await _ttsService.synthesizeDirect(
              text: scene.narrationText!,
              voice: activeVoice,
              outputPath: sceneAudioPath,
              options: const TtsOptions(speed: 1.0, format: TtsAudioFormat.wav),
            );

            final probe = await _ffmpegService.probeMedia(ttsResult);
            final durSec = probe.durationSeconds > 0 ? probe.durationSeconds : 5.0;

            // Auto scene duration from voice: voice duration + 0.8s tail padding
            final autoDuration = (durSec + 0.8).clamp(3.0, 300.0);

            scene = scene.copyWith(
              voiceoverAudioPath: ttsResult,
              voiceoverDurationSeconds: durSec,
              durationSeconds: autoDuration,
            );
          }
        }

        updatedScenes.add(scene);
        if (scene.voiceoverAudioPath != null && File(scene.voiceoverAudioPath!).existsSync()) {
          voiceoverAudioPaths.add(scene.voiceoverAudioPath!);
        }
      }

      if (_isCancelled) throw Exception('CANCELLED');

      // Stage 3: Building Individual Scene Video Clips
      onProgress?.call(0.40, 'Đang tạo các phân cảnh video...');
      AppLogger.info('Stage 3 [BuildingScenes]: Rendering ${updatedScenes.length} individual scene clips...');

      final sceneVideoPaths = <String>[];
      for (int i = 0; i < updatedScenes.length; i++) {
        if (_isCancelled) throw Exception('CANCELLED');

        final scene = updatedScenes[i];
        final sceneOutPath = p.join(tempDir.path, 'scene_video_${i + 1}.mp4');
        final pct = 0.40 + (i / updatedScenes.length) * 0.20;
        onProgress?.call(pct, 'Đang kết xuất cảnh ${i + 1}/${updatedScenes.length}...');

        if (scene.hasVideoClip && File(scene.videoClipPath!).existsSync()) {
          // Process existing video clip
          await _ffmpegService.trimAndScaleVideo(
            inputVideoPath: scene.videoClipPath!,
            outputPath: sceneOutPath,
            startSeconds: scene.clipTrimStartSeconds,
            endSeconds: scene.clipTrimEndSeconds,
            width: targetWidth,
            height: targetHeight,
            fps: fps,
            muteAudio: scene.clipMuteOriginalAudio,
          );
        } else if (scene.hasImage && File(scene.backgroundImagePath!).existsSync()) {
          // Process still image to video with framing & Ken Burns motion
          await _ffmpegService.imageToVideo(
            imagePath: scene.backgroundImagePath!,
            outputPath: sceneOutPath,
            durationSeconds: scene.durationSeconds,
            width: targetWidth,
            height: targetHeight,
            fps: fps,
            fitMode: scene.imageFitMode,
            blurBackground: scene.blurBackground,
            kenBurns: scene.kenBurns,
          );
        } else {
          // Generate solid title card / graphic card if no media attached
          final solidImage = File(p.join(tempDir.path, 'solid_card_$i.png'));
          _generateSolidCard(solidImage, targetWidth, targetHeight);
          await _ffmpegService.imageToVideo(
            imagePath: solidImage.path,
            outputPath: sceneOutPath,
            durationSeconds: scene.durationSeconds,
            width: targetWidth,
            height: targetHeight,
            fps: fps,
          );
        }

        // Overlay Title and Subtitle text on the scene if present
        if (scene.title != null && scene.title!.trim().isNotEmpty) {
          final titledScenePath = p.join(tempDir.path, 'scene_titled_${i + 1}.mp4');
          final overlayRes = await _ffmpegService.overlayTextAndTitles(
            inputVideoPath: sceneOutPath,
            outputPath: titledScenePath,
            title: scene.title!,
            subtitle: scene.subtitle,
            durationSeconds: scene.durationSeconds,
          );
          if (overlayRes.isSuccess && File(titledScenePath).existsSync() && File(titledScenePath).lengthSync() > 100) {
            sceneVideoPaths.add(titledScenePath);
          } else {
            // Graceful fallback to sceneOutPath without breaking render pipeline
            AppLogger.warning('Overlay title failed, falling back to clean scene clip: ${overlayRes.stderr}');
            sceneVideoPaths.add(sceneOutPath);
          }
        } else {
          sceneVideoPaths.add(sceneOutPath);
        }
      }

      if (_isCancelled) throw Exception('CANCELLED');

      // Stage 4: Transitions & Scene Stitching
      onProgress?.call(0.65, 'Đang xử lý hiệu ứng chuyển cảnh...');
      AppLogger.info('Stage 4 [Transitions]: Stitching scenes with transitions...');

      final stitchedVideoPath = p.join(tempDir.path, 'stitched_video.mp4');
      final transitions = updatedScenes.map((s) => s.transition).toList();
      final totalSceneDur = updatedScenes.fold(0.0, (sum, s) => sum + s.durationSeconds);

      final stitchRes = await _ffmpegService.renderScenesWithTransitions(
        sceneVideoPaths: sceneVideoPaths,
        transitions: transitions,
        outputPath: stitchedVideoPath,
        width: targetWidth,
        height: targetHeight,
        totalDurationSeconds: totalSceneDur,
        onProgress: (p) {
          final scaled = 0.65 + (p.progressPercent * 0.10);
          onProgress?.call(scaled, 'Đang ghép nối chuyển cảnh (${(p.progressPercent * 100).toStringAsFixed(0)}%)...');
        },
      );

      if (!stitchRes.isSuccess || !File(stitchedVideoPath).existsSync() || File(stitchedVideoPath).lengthSync() < 100) {
        throw Exception('Ghép nối phân cảnh video thất bại: ${stitchRes.stderr}');
      }

      if (_isCancelled) throw Exception('CANCELLED');

      // Stage 5: Audio Mixing & Ducking
      onProgress?.call(0.75, 'Đang xử lý hòa âm và Audio Ducking...');
      AppLogger.info('Stage 5 [AudioMix]: Mixing voiceover, background music, and ducking...');

      // Combine voiceovers into a single timeline audio track if multiple scenes have voiceover
      String? combinedVoicePath;
      if (voiceoverAudioPaths.isNotEmpty) {
        if (voiceoverAudioPaths.length == 1) {
          combinedVoicePath = voiceoverAudioPaths.first;
        } else {
          combinedVoicePath = p.join(tempDir.path, 'combined_voiceovers.wav');
          await _ffmpegService.concatAudio(
            inputAudioPaths: voiceoverAudioPaths,
            outputAudioPath: combinedVoicePath,
          );
        }
      }

      final mixedAudioPath = p.join(tempDir.path, 'mixed_audio.aac');
      await _ffmpegService.mixAudioWithDucking(
        voiceoverAudioPath: combinedVoicePath,
        musicAudioPath: project.backgroundMusicPath,
        outputPath: mixedAudioPath,
        totalDurationSeconds: totalSceneDur,
        duckingLevel: settings.duckingLevel,
        voiceoverVolume: settings.voiceoverVolume,
        musicVolume: settings.backgroundMusicVolume,
        loopMusic: project.backgroundMusicLoop,
      );

      if (_isCancelled) throw Exception('CANCELLED');

      // Stage 6: Multiplexing Video and Audio
      onProgress?.call(0.85, 'Đang kết hợp luồng hình ảnh và âm thanh...');
      AppLogger.info('Stage 6 [Multiplex]: Combining video and audio...');

      final muxedPath = p.join(tempDir.path, 'muxed_preview.mp4');
      final muxRes = await _ffmpegService.combineVideoAndAudio(
        videoPath: stitchedVideoPath,
        audioPath: mixedAudioPath,
        outputPath: muxedPath,
        totalDurationSeconds: totalSceneDur,
      );
      if (!muxRes.isSuccess || !File(muxedPath).existsSync() || File(muxedPath).lengthSync() < 100) {
        AppLogger.warning('Muxing audio failed (${muxRes.stderr}), falling back to stitched video without audio');
        File(stitchedVideoPath).copySync(muxedPath);
      }

      // Stage 7: Subtitle Burn-In (If enabled)
      var finalRenderedPath = muxedPath;
      if (settings.burnSubtitles) {
        // Collect subtitles from scenes or generate SRT
        final allSegments = <TtsTimingSegment>[];
        var runningMs = 0;

        for (int i = 0; i < updatedScenes.length; i++) {
          final sc = updatedScenes[i];
          final scDurMs = (sc.durationSeconds * 1000).round();
          if (sc.subtitle != null && sc.subtitle!.trim().isNotEmpty) {
            allSegments.add(TtsTimingSegment(
              index: allSegments.length,
              startMs: runningMs,
              endMs: runningMs + scDurMs,
              text: sc.subtitle!,
              isEstimated: true,
            ));
          } else if (sc.narrationText != null && sc.narrationText!.trim().isNotEmpty) {
            allSegments.add(TtsTimingSegment(
              index: allSegments.length,
              startMs: runningMs,
              endMs: runningMs + scDurMs,
              text: sc.narrationText!,
              isEstimated: true,
            ));
          }
          runningMs += scDurMs;
        }

        if (allSegments.isNotEmpty) {
          onProgress?.call(0.90, 'Đang khắc phụ đề tiếng Việt (Burn-in Subtitles)...');
          AppLogger.info('Stage 7 [Subtitles]: Burning ${allSegments.length} subtitle segments...');

          final srtPath = p.join(tempDir.path, 'subtitles.srt');
          const subGen = SubtitleGenerator();
          await subGen.exportSrtToFile(allSegments, srtPath);

          final burnedPath = p.join(tempDir.path, 'burned_subtitles.mp4');
          final burnRes = await _ffmpegService.burnSubtitles(
            inputVideoPath: muxedPath,
            srtPath: srtPath,
            outputPath: burnedPath,
            totalDurationSeconds: totalSceneDur,
          );

          if (burnRes.isSuccess && File(burnedPath).existsSync() && File(burnedPath).lengthSync() > 100) {
            finalRenderedPath = burnedPath;
          } else {
            AppLogger.warning('Burn subtitles warning (${burnRes.stderr}), falling back to muxed video.');
            finalRenderedPath = muxedPath;
          }
        }
      }

      if (_isCancelled) throw Exception('CANCELLED');

      // Stage 8: Final Validation via ffprobe (Section 46, 47)
      onProgress?.call(0.95, 'Đang thẩm định chất lượng video qua FFprobe...');
      AppLogger.info('Stage 8 [Validation]: Probing final MP4...');

      final probe = await _ffmpegService.probeMedia(finalRenderedPath);

      if (!probe.hasVideo || probe.durationSeconds <= 0.1 || probe.fileSizeBytes < 1000) {
        throw Exception(
          'Thẩm định video thất bại: Tệp xuất rỗng hoặc thiếu luồng video hợp lệ. Duration: ${probe.durationSeconds}s, Size: ${probe.fileSizeBytes} bytes.',
        );
      }

      // Stage 9: Export to Destination & Catalog to Document Library
      onProgress?.call(0.98, 'Đang lưu tệp video hoàn chỉnh...');
      final exportDir = Directory(settings.customOutputDirectory ??
          p.join(Directory.current.path, 'exports', 'video'));
      if (!exportDir.existsSync()) exportDir.createSync(recursive: true);

      final safeName = _sanitizeFileName(project.name.isNotEmpty ? project.name : 'Video_NguyenDu');
      final finalDestination = p.join(exportDir.path, '${safeName}_$jobId.mp4');

      File(finalRenderedPath).copySync(finalDestination);
      final finalFile = File(finalDestination);

      // Save render record to database
      try {
        final db = await _appDatabase.database;
        await db.insert('video_renders', {
          'id': jobId,
          'project_id': project.id,
          'output_mp4_path': finalDestination,
          'resolution': '${targetWidth}x$targetHeight',
          'fps': fps,
          'duration_seconds': probe.durationSeconds,
          'file_size_bytes': finalFile.lengthSync(),
          'render_time_seconds': stopwatch.elapsedMilliseconds / 1000.0,
          'hardware_encoder': settings.hardwareEncoder.name,
          'created_at': DateTime.now().toIso8601String(),
        });

        // Ingest into Document Library
        await _fileRepository.addFile(FileEntry(
          id: jobId,
          projectId: project.id,
          originalName: p.basename(finalDestination),
          localPath: finalDestination,
          size: finalFile.lengthSync(),
          mimeType: 'video/mp4',
          createdAt: DateTime.now(),
        ));
      } catch (e) {
        AppLogger.warning('Database render cataloging warning: $e');
      }

      stopwatch.stop();
      onProgress?.call(1.0, 'Kết xuất hoàn tất!');
      await _jobRepository.completeJob(jobId, outputJson: finalDestination);

      AppLogger.info(
        'Video Studio Render PASS: "$finalDestination" (${finalFile.lengthSync()} bytes, ${probe.durationSeconds}s, ${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2)}s wall time)',
      );

      return VideoRenderResult(
        isSuccess: true,
        outputPath: finalDestination,
        projectId: project.id,
        fileSizeBytes: finalFile.lengthSync(),
        durationSeconds: probe.durationSeconds,
        width: targetWidth,
        height: targetHeight,
        fps: fps,
        renderWallTime: stopwatch.elapsed,
        probeResult: probe,
      );
    } catch (e, st) {
      stopwatch.stop();
      if (_isCancelled) {
        await _jobRepository.cancelJob(jobId);
        return VideoRenderResult(
          isSuccess: false,
          outputPath: '',
          projectId: project.id,
          fileSizeBytes: 0,
          durationSeconds: 0,
          width: 0,
          height: 0,
          fps: settings.fps,
          renderWallTime: stopwatch.elapsed,
          errorMessage: 'Quá trình render đã bị hủy bởi người dùng.',
        );
      }

      AppLogger.error('Lỗi trong quá trình render video studio', e, st);
      await _jobRepository.failJob(jobId, e.toString());

      return VideoRenderResult(
        isSuccess: false,
        outputPath: '',
        projectId: project.id,
        fileSizeBytes: 0,
        durationSeconds: 0,
        width: 0,
        height: 0,
        fps: settings.fps,
        renderWallTime: stopwatch.elapsed,
        errorMessage: e.toString(),
      );
    } finally {
      // Clean up temporary render folder
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    }
  }

  /// Helper to generate a solid background image for title cards without external image assets.
  void _generateSolidCard(File targetFile, int width, int height) {
    // Generate minimal BMP or PNG header (minimal 1x1 image that FFmpeg can loop and scale)
    // Writing a clean 24-bit BMP image directly:
    final rowBytes = (width * 3 + 3) & ~3;
    final pixelDataSize = rowBytes * height;
    final fileSize = 54 + pixelDataSize;

    final bytes = List<int>.filled(fileSize, 0);
    // BMP Signature 'BM'
    bytes[0] = 0x42;
    bytes[1] = 0x4D;
    // File size
    bytes[2] = fileSize & 0xFF;
    bytes[3] = (fileSize >> 8) & 0xFF;
    bytes[4] = (fileSize >> 16) & 0xFF;
    bytes[5] = (fileSize >> 24) & 0xFF;
    // Data offset = 54
    bytes[10] = 54;
    // DIB Header size = 40
    bytes[14] = 40;
    // Width
    bytes[18] = width & 0xFF;
    bytes[19] = (width >> 8) & 0xFF;
    bytes[20] = (width >> 16) & 0xFF;
    bytes[21] = (width >> 24) & 0xFF;
    // Height
    bytes[22] = height & 0xFF;
    bytes[23] = (height >> 8) & 0xFF;
    bytes[24] = (height >> 16) & 0xFF;
    bytes[25] = (height >> 24) & 0xFF;
    // Color planes = 1
    bytes[26] = 1;
    // Bits per pixel = 24
    bytes[28] = 24;

    // Fill with pleasant educational deep navy blue (RGB: 15, 32, 67)
    for (int y = 0; y < height; y++) {
      final rowOffset = 54 + y * rowBytes;
      for (int x = 0; x < width; x++) {
        final pxOffset = rowOffset + x * 3;
        bytes[pxOffset] = 67; // B
        bytes[pxOffset + 1] = 32; // G
        bytes[pxOffset + 2] = 15; // R
      }
    }

    targetFile.writeAsBytesSync(bytes);
  }

  /// Sanitizes project name into safe Windows file name while preserving Vietnamese Unicode.
  String _sanitizeFileName(String name) {
    var safe = name.trim();
    final invalidChars = RegExp(r'[\\/:*?"<>|]');
    safe = safe.replaceAll(invalidChars, '_');
    if (safe.isEmpty) safe = 'Video';
    if (safe.length > 80) safe = safe.substring(0, 80);
    return safe;
  }
}
