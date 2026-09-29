import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import '../../features/video_studio/domain/models/audio_ducking_level.dart';
import '../../features/video_studio/domain/models/ken_burns_effect.dart';
import '../../features/video_studio/domain/models/transition.dart';
import '../../features/video_studio/domain/models/video_scene.dart';
import '../logging/app_logger.dart';
import 'ffmpeg_command.dart';
import 'ffmpeg_progress.dart';
import 'media_probe_result.dart';

/// Centralized FFmpeg and FFprobe service for media processing, video compositing,
/// audio ducking, subtitle burn-in, and transcoding.
/// Local-First pipeline with zero cloud dependencies.
class FfmpegService {
  static FfmpegService? _instance;
  static FfmpegService get instance => _instance ??= FfmpegService();

  bool _initialized = false;
  bool _isAvailable = false;
  String? _ffmpegPath;
  String? _ffprobePath;
  String? _version;
  String? _licenseInfo;
  String? _sha256;
  Process? _activeProcess;
  bool _isCancelled = false;

  bool get isAvailable => _isAvailable;
  String? get binaryPath => _ffmpegPath;
  String? get ffmpegPath => _ffmpegPath;
  String? get ffprobePath => _ffprobePath;
  String? get version => _version;
  String? get licenseInfo => _licenseInfo;
  String? get sha256 => _sha256;

  bool get isBundled =>
      _ffmpegPath != null &&
      (_ffmpegPath!.toLowerCase().contains(r'\bin\ffmpeg.exe') ||
          _ffmpegPath!.toLowerCase().contains('/bin/ffmpeg.exe'));

  String get originLabel => isBundled ? 'Bundled Release FFmpeg' : 'External/System FFmpeg';

  /// Initializes FFmpeg and FFprobe discovery.
  ///
  /// Production Discovery Order:
  /// 1. Bundled application binary (<app>\bin\ffmpeg.exe or <workingDir>\bin\ffmpeg.exe)
  /// 2. User-configured explicit path (settings or test injection)
  /// 3. System PATH (ffmpeg.exe / ffmpeg)
  Future<bool> initialize({
    String? customConfiguredPath,
    String? customFfprobePath,
    bool forceReinitialize = false,
  }) async {
    if (_initialized && _isAvailable && !forceReinitialize) return true;
    if (forceReinitialize) {
      _initialized = false;
      _isAvailable = false;
      _ffmpegPath = null;
      _ffprobePath = null;
    }

    final appDir = p.dirname(Platform.resolvedExecutable);
    final currentDir = Directory.current.path;

    final ffmpegCandidates = <String>[];
    final ffprobeCandidates = <String>[];

    // 1. Bundled application binary
    ffmpegCandidates.addAll([
      p.join(appDir, 'bin', 'ffmpeg.exe'),
      p.join(currentDir, 'bin', 'ffmpeg.exe'),
      p.join(appDir, 'ffmpeg.exe'),
      p.join(currentDir, 'ffmpeg.exe'),
    ]);

    ffprobeCandidates.addAll([
      p.join(appDir, 'bin', 'ffprobe.exe'),
      p.join(currentDir, 'bin', 'ffprobe.exe'),
      p.join(appDir, 'ffprobe.exe'),
      p.join(currentDir, 'ffprobe.exe'),
    ]);

    // 2. User-configured explicit path / test injection
    if (customConfiguredPath != null && customConfiguredPath.trim().isNotEmpty) {
      final trimmed = customConfiguredPath.trim();
      ffmpegCandidates.add(trimmed);
      final customDir = p.dirname(trimmed);
      ffprobeCandidates.add(p.join(customDir, 'ffprobe.exe'));
    }
    if (customFfprobePath != null && customFfprobePath.trim().isNotEmpty) {
      ffprobeCandidates.add(customFfprobePath.trim());
    }

    // 3. System PATH fallback
    ffmpegCandidates.addAll([
      'ffmpeg.exe',
      'ffmpeg',
    ]);

    ffprobeCandidates.addAll([
      'ffprobe.exe',
      'ffprobe',
    ]);

    // Discover FFmpeg
    for (final candidate in ffmpegCandidates) {
      try {
        final result = await Process.run(
          candidate,
          ['-version'],
          runInShell: false,
        ).timeout(const Duration(seconds: 4));

        if (result.exitCode == 0) {
          final stdoutStr = result.stdout.toString();
          if (stdoutStr.toLowerCase().contains('ffmpeg version')) {
            _ffmpegPath = candidate;
            _isAvailable = true;

            final lines = stdoutStr.split('\n');
            _version = lines.first.trim();

            final licenseLine = lines.firstWhere(
              (l) => l.toLowerCase().contains('license') || l.toLowerCase().contains('copyright'),
              orElse: () => 'GPL / LGPL',
            );
            _licenseInfo = licenseLine.trim();

            if (File(candidate).existsSync()) {
              try {
                final bytes = File(candidate).readAsBytesSync();
                _sha256 = crypto.sha256.convert(bytes).toString().toUpperCase();
              } catch (_) {}
            }

            AppLogger.info('FFmpeg discovered: $_version at $_ffmpegPath (SHA256: ${_sha256 ?? "N/A"})');
            break;
          }
        }
      } catch (_) {}
    }

    // Discover FFprobe
    for (final candidate in ffprobeCandidates) {
      try {
        final result = await Process.run(
          candidate,
          ['-version'],
          runInShell: false,
        ).timeout(const Duration(seconds: 4));

        if (result.exitCode == 0 && result.stdout.toString().contains('ffprobe')) {
          _ffprobePath = candidate;
          AppLogger.info('FFprobe discovered: $_ffprobePath');
          break;
        }
      } catch (_) {}
    }

    _initialized = true;
    return _isAvailable;
  }

  /// Cancels any currently executing render process and marks operation cancelled.
  Future<void> cancelActiveOperation() async {
    _isCancelled = true;
    if (_activeProcess != null) {
      try {
        _activeProcess!.kill(ProcessSignal.sigkill);
      } catch (_) {}
      _activeProcess = null;
    }
  }

  /// Probes media file (video, audio, or image) using ffprobe.
  Future<MediaProbeResult> probeMedia(String filePath) async {
    if (!_initialized) await initialize();
    final file = File(filePath);
    if (!file.existsSync()) return MediaProbeResult.empty(filePath);

    final fileSize = file.lengthSync();

    if (_ffprobePath != null) {
      try {
        final res = await Process.run(
          _ffprobePath!,
          [
            '-v', 'quiet',
            '-print_format', 'json',
            '-show_format',
            '-show_streams',
            filePath,
          ],
          runInShell: false,
        ).timeout(const Duration(seconds: 10));

        if (res.exitCode == 0) {
          final jsonMap = jsonDecode(res.stdout.toString()) as Map<String, dynamic>;
          final streams = (jsonMap['streams'] as List<dynamic>?) ?? [];
          final format = (jsonMap['format'] as Map<String, dynamic>?) ?? {};

          Map<String, dynamic>? videoStream;
          Map<String, dynamic>? audioStream;

          for (final s in streams) {
            final m = s as Map<String, dynamic>;
            final type = m['codec_type'];
            if (type == 'video' && videoStream == null) videoStream = m;
            if (type == 'audio' && audioStream == null) audioStream = m;
          }

          final durSecStr = format['duration']?.toString() ??
              videoStream?['duration']?.toString() ??
              audioStream?['duration']?.toString() ??
              '0';
          final durationSec = double.tryParse(durSecStr) ?? 0.0;
          final durationMs = (durationSec * 1000).round();

          int? width;
          int? height;
          double? fps;
          String? videoCodec;
          if (videoStream != null) {
            width = int.tryParse(videoStream['width']?.toString() ?? '');
            height = int.tryParse(videoStream['height']?.toString() ?? '');
            videoCodec = videoStream['codec_name']?.toString();
            final rFrameRate = videoStream['r_frame_rate']?.toString() ?? '';
            if (rFrameRate.contains('/')) {
              final parts = rFrameRate.split('/');
              final num = double.tryParse(parts[0]);
              final den = double.tryParse(parts[1]);
              if (num != null && den != null && den > 0) fps = num / den;
            }
          }

          String? audioCodec;
          int? sampleRate;
          int? channels;
          if (audioStream != null) {
            audioCodec = audioStream['codec_name']?.toString();
            sampleRate = int.tryParse(audioStream['sample_rate']?.toString() ?? '');
            channels = int.tryParse(audioStream['channels']?.toString() ?? '');
          }

          final bitRate = int.tryParse(format['bit_rate']?.toString() ?? '');

          return MediaProbeResult(
            filePath: filePath,
            fileSizeBytes: fileSize,
            durationSeconds: durationSec,
            durationMs: durationMs,
            width: width,
            height: height,
            fps: fps,
            videoCodec: videoCodec,
            audioCodec: audioCodec,
            sampleRate: sampleRate,
            channels: channels,
            bitRate: bitRate,
            hasVideo: videoStream != null,
            hasAudio: audioStream != null,
            containerFormat: format['format_name']?.toString(),
            rawJson: jsonMap,
          );
        }
      } catch (e) {
        AppLogger.warning('ffprobe failed, falling back to basic probe: $e');
      }
    }

    return MediaProbeResult.empty(filePath);
  }

  /// Converts a still image into a video clip with specified duration, framing, and motion effect.
  Future<FfmpegResult> imageToVideo({
    required String imagePath,
    required String outputPath,
    required double durationSeconds,
    required int width,
    required int height,
    int fps = 30,
    ImageFitMode fitMode = ImageFitMode.fit,
    bool blurBackground = true,
    KenBurnsEffect kenBurns = KenBurnsEffect.none,
    void Function(FfmpegProgress)? onProgress,
  }) async {
    if (!_isAvailable || _ffmpegPath == null) {
      return FfmpegResult.failed(exitCode: 1, stderr: 'FFmpeg không khả dụng.');
    }

    _isCancelled = false;
    final outDir = Directory(p.dirname(outputPath));
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    final durStr = durationSeconds.toStringAsFixed(2);
    final totalFrames = (durationSeconds * fps).round();

    // Construct filter graph based on framing and motion
    String filterGraph;

    if (kenBurns != KenBurnsEffect.none) {
      // Ken Burns motion with zoompan filter
      String zoomExpr;
      String xExpr;
      String yExpr;

      switch (kenBurns) {
        case KenBurnsEffect.zoomIn:
          zoomExpr = "'min(zoom+0.0015,1.25)'";
          xExpr = "'(iw-iw/zoom)/2'";
          yExpr = "'(ih-ih/zoom)/2'";
          break;
        case KenBurnsEffect.zoomOut:
          zoomExpr = "'if(lte(zoom,1.0),1.25,max(1.001,zoom-0.0015))'";
          xExpr = "'(iw-iw/zoom)/2'";
          yExpr = "'(ih-ih/zoom)/2'";
          break;
        case KenBurnsEffect.panLeft:
          zoomExpr = "'1.2'";
          xExpr = "'if(lte(on,1),(iw-iw/zoom)/2,min(iw-iw/zoom,x+0.5))'";
          yExpr = "'(ih-ih/zoom)/2'";
          break;
        case KenBurnsEffect.panRight:
          zoomExpr = "'1.2'";
          xExpr = "'if(lte(on,1),(iw-iw/zoom)/2,max(0,x-0.5))'";
          yExpr = "'(ih-ih/zoom)/2'";
          break;
        case KenBurnsEffect.none:
          zoomExpr = "'1.0'";
          xExpr = "'(iw-iw/zoom)/2'";
          yExpr = "'(ih-ih/zoom)/2'";
          break;
      }

      filterGraph = 'zoompan=z=$zoomExpr:x=$xExpr:y=$yExpr:d=$totalFrames:s=${width}x$height:fps=$fps,format=yuv420p';
    } else if (fitMode == ImageFitMode.fit && blurBackground) {
      // Split stream: blurred background + scaled foreground centered
      filterGraph =
          '[0:v]split=2[bg][fg];'
          '[bg]scale=$width:$height:force_original_aspect_ratio=increase,crop=$width:$height,boxblur=20:5[bgblur];'
          '[fg]scale=$width:$height:force_original_aspect_ratio=decrease[fgscaled];'
          '[bgblur][fgscaled]overlay=(W-w)/2:(H-h)/2,format=yuv420p';
    } else if (fitMode == ImageFitMode.fill || fitMode == ImageFitMode.crop) {
      filterGraph = 'scale=$width:$height:force_original_aspect_ratio=increase,crop=$width:$height,format=yuv420p';
    } else {
      // Fit with black background pads
      filterGraph =
          'scale=$width:$height:force_original_aspect_ratio=decrease,pad=$width:$height:(ow-iw)/2:(oh-ih)/2,format=yuv420p';
    }

    final args = [
      '-y',
      if (kenBurns == KenBurnsEffect.none) ...[
        '-loop', '1',
        '-t', durStr,
      ],
      '-i', imagePath,
      '-filter_complex', filterGraph,
      '-c:v', 'libx264',
      '-preset', 'fast',
      '-crf', '22',
      '-r', fps.toString(),
      '-pix_fmt', 'yuv420p',
      '-progress', 'pipe:1',
      outputPath,
    ];

    return _executeWithProgress(
      args: args,
      outputPath: outputPath,
      totalDurationSeconds: durationSeconds,
      stage: 'imageToVideo',
      onProgress: onProgress,
    );
  }

  /// Trims video clip and scales to project target resolution.
  Future<FfmpegResult> trimAndScaleVideo({
    required String inputVideoPath,
    required String outputPath,
    required double startSeconds,
    double? endSeconds,
    required int width,
    required int height,
    int fps = 30,
    bool muteAudio = false,
    void Function(FfmpegProgress)? onProgress,
  }) async {
    if (!_isAvailable || _ffmpegPath == null) {
      return FfmpegResult.failed(exitCode: 1, stderr: 'FFmpeg không khả dụng.');
    }

    _isCancelled = false;
    final outDir = Directory(p.dirname(outputPath));
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    final durationSeconds = endSeconds != null ? max(0.5, endSeconds - startSeconds) : 10.0;

    final args = <String>[
      '-y',
      '-ss', startSeconds.toStringAsFixed(3),
    ];

    if (endSeconds != null) {
      args.addAll(['-t', durationSeconds.toStringAsFixed(3)]);
    }

    args.addAll([
      '-i', inputVideoPath,
      '-vf', 'scale=$width:$height:force_original_aspect_ratio=decrease,pad=$width:$height:(ow-iw)/2:(oh-ih)/2,format=yuv420p',
      '-c:v', 'libx264',
      '-preset', 'fast',
      '-crf', '22',
      '-r', fps.toString(),
    ]);

    if (muteAudio) {
      args.add('-an');
    } else {
      args.addAll(['-c:a', 'aac', '-b:a', '192k']);
    }

    args.addAll(['-progress', 'pipe:1', outputPath]);

    return _executeWithProgress(
      args: args,
      outputPath: outputPath,
      totalDurationSeconds: durationSeconds,
      stage: 'trimAndScale',
      onProgress: onProgress,
    );
  }

  /// Concatenates multiple scenes with transitions (fade, crossfade, slideLeft, slideRight).
  Future<FfmpegResult> renderScenesWithTransitions({
    required List<String> sceneVideoPaths,
    required List<SceneTransition> transitions,
    required String outputPath,
    required int width,
    required int height,
    required double totalDurationSeconds,
    void Function(FfmpegProgress)? onProgress,
  }) async {
    if (!_isAvailable || _ffmpegPath == null || sceneVideoPaths.isEmpty) {
      return FfmpegResult.failed(exitCode: 1, stderr: 'Danh sách cảnh rỗng hoặc FFmpeg không khả dụng.');
    }

    if (sceneVideoPaths.length == 1) {
      // Direct copy/link single scene
      final single = File(sceneVideoPaths.first);
      single.copySync(outputPath);
      return FfmpegResult(
        isSuccess: true,
        exitCode: 0,
        stdout: '',
        stderr: '',
        outputPath: outputPath,
        elapsed: Duration.zero,
      );
    }

    _isCancelled = false;
    final outDir = Directory(p.dirname(outputPath));
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    // Build concat script with filter_complex xfade
    final args = <String>['-y'];

    for (final path in sceneVideoPaths) {
      args.addAll(['-i', path]);
    }

    // Build filter_complex xfade chain
    final filterBuffer = StringBuffer();
    var currentStream = '[0:v]';
    var cumulativeOffset = 0.0;

    // Get durations of scenes for xfade offset calculations
    final sceneDurations = <double>[];
    for (final path in sceneVideoPaths) {
      final probe = await probeMedia(path);
      sceneDurations.add(probe.durationSeconds > 0 ? probe.durationSeconds : 5.0);
    }

    for (int i = 0; i < sceneVideoPaths.length - 1; i++) {
      final nextInput = '[${i + 1}:v]';
      final trans = i < transitions.length ? transitions[i] : const SceneTransition();
      final transDur = trans.durationSeconds;
      final transName = trans.type == TransitionType.none ? 'fade' : trans.type.xfadeName;

      // xfade offset is the point where transition starts
      final sceneDur = sceneDurations[i];
      cumulativeOffset += (sceneDur - transDur);
      final offsetStr = cumulativeOffset.toStringAsFixed(2);
      final outStream = '[v$i]';

      filterBuffer.write('$currentStream$nextInput xfade=transition=$transName:duration=$transDur:offset=$offsetStr');
      if (i < sceneVideoPaths.length - 2) {
        filterBuffer.write('$outStream;');
        currentStream = outStream;
      } else {
        filterBuffer.write(',format=yuv420p[vout]');
      }
    }

    args.addAll([
      '-filter_complex', filterBuffer.toString(),
      '-map', '[vout]',
      '-c:v', 'libx264',
      '-preset', 'medium',
      '-crf', '22',
      '-pix_fmt', 'yuv420p',
      '-progress', 'pipe:1',
      outputPath,
    ]);

    return _executeWithProgress(
      args: args,
      outputPath: outputPath,
      totalDurationSeconds: totalDurationSeconds,
      stage: 'renderTransitions',
      onProgress: onProgress,
    );
  }

  /// Mixes voiceover audio, background music, and original video audio with real sidechain audio ducking.
  Future<FfmpegResult> mixAudioWithDucking({
    String? voiceoverAudioPath,
    String? musicAudioPath,
    String? clipAudioPath,
    required String outputPath,
    required double totalDurationSeconds,
    AudioDuckingLevel duckingLevel = AudioDuckingLevel.medium,
    double voiceoverVolume = 1.0,
    double musicVolume = 0.35,
    bool loopMusic = true,
    void Function(FfmpegProgress)? onProgress,
  }) async {
    if (!_isAvailable || _ffmpegPath == null) {
      return FfmpegResult.failed(exitCode: 1, stderr: 'FFmpeg không khả dụng.');
    }

    _isCancelled = false;
    final outDir = Directory(p.dirname(outputPath));
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    final hasVoice = voiceoverAudioPath != null && File(voiceoverAudioPath).existsSync();
    final hasMusic = musicAudioPath != null && File(musicAudioPath).existsSync();
    final hasClip = clipAudioPath != null && File(clipAudioPath).existsSync();

    // Case 1: Only voiceover
    if (hasVoice && !hasMusic && !hasClip) {
      final args = [
        '-y',
        '-i', voiceoverAudioPath,
        '-filter_complex', 'volume=$voiceoverVolume',
        '-c:a', 'aac',
        '-b:a', '192k',
        outputPath,
      ];
      return _executeWithProgress(
        args: args,
        outputPath: outputPath,
        totalDurationSeconds: totalDurationSeconds,
        stage: 'mixAudio',
        onProgress: onProgress,
      );
    }

    // Case 2: Only music
    if (hasMusic && !hasVoice && !hasClip) {
      final args = [
        '-y',
        if (loopMusic) '-stream_loop', '-1',
        '-i', musicAudioPath,
        '-t', totalDurationSeconds.toStringAsFixed(2),
        '-filter_complex', 'volume=$musicVolume',
        '-c:a', 'aac',
        '-b:a', '192k',
        outputPath,
      ];
      return _executeWithProgress(
        args: args,
        outputPath: outputPath,
        totalDurationSeconds: totalDurationSeconds,
        stage: 'mixAudio',
        onProgress: onProgress,
      );
    }

    // Case 3: Voiceover + Music (Real Audio Ducking)
    if (hasVoice && hasMusic) {
      final args = <String>['-y'];

      // Input 0: Voiceover
      args.addAll(['-i', voiceoverAudioPath]);

      // Input 1: Music (looped or limited to total duration)
      if (loopMusic) {
        args.addAll(['-stream_loop', '-1']);
      }
      args.addAll(['-i', musicAudioPath]);

      String audioFilter;
      if (duckingLevel == AudioDuckingLevel.off) {
        // Plain mix without ducking
        audioFilter =
            '[0:a]volume=$voiceoverVolume[v];'
            '[1:a]volume=$musicVolume,atrim=0:$totalDurationSeconds[m];'
            '[v][m]amix=inputs=2:duration=longest:dropout_transition=2[aout]';
      } else {
        // Real Sidechain Compression Ducking:
        // [1:a] music is compressed by sidechain signal [0:a] voice!
        // When voice is active, music drops by attenuationDb!
        final ratio = duckingLevel == AudioDuckingLevel.light
            ? 3.0
            : (duckingLevel == AudioDuckingLevel.medium ? 6.0 : 12.0);
        const threshold = 0.05;

        audioFilter =
            '[0:a]volume=$voiceoverVolume,asplit=2[v_play][v_sc];'
            '[1:a]volume=$musicVolume,atrim=0:$totalDurationSeconds[m_trim];'
            '[m_trim][v_sc]sidechaincompress=threshold=$threshold:ratio=$ratio:attack=20:release=350[m_ducked];'
            '[v_play][m_ducked]amix=inputs=2:duration=longest:dropout_transition=2[aout]';
      }

      args.addAll([
        '-filter_complex', audioFilter,
        '-map', '[aout]',
        '-c:a', 'aac',
        '-b:a', '192k',
        outputPath,
      ]);

      return _executeWithProgress(
        args: args,
        outputPath: outputPath,
        totalDurationSeconds: totalDurationSeconds,
        stage: 'duckingAudio',
        onProgress: onProgress,
      );
    }

    // Case 4: No audio inputs -> generate silent audio track
    final args = [
      '-y',
      '-f', 'lavfi',
      '-i', 'anullsrc=channel_layout=stereo:sample_rate=48000',
      '-t', totalDurationSeconds.toStringAsFixed(2),
      '-c:a', 'aac',
      '-b:a', '192k',
      outputPath,
    ];

    return _executeWithProgress(
      args: args,
      outputPath: outputPath,
      totalDurationSeconds: totalDurationSeconds,
      stage: 'silentAudio',
      onProgress: onProgress,
    );
  }

  /// Overlays Vietnamese Title and Subtitle text safely on video frames with Unicode font.
  Future<FfmpegResult> overlayTextAndTitles({
    required String inputVideoPath,
    required String outputPath,
    required String title,
    String? subtitle,
    double startSeconds = 0.0,
    double? durationSeconds,
    void Function(FfmpegProgress)? onProgress,
  }) async {
    if (!_isAvailable || _ffmpegPath == null) {
      return FfmpegResult.failed(exitCode: 1, stderr: 'FFmpeg không khả dụng.');
    }

    _isCancelled = false;
    final tempDir = Directory.systemTemp;
    final tempId = DateTime.now().millisecondsSinceEpoch;
    final titleFile = File(p.join(tempDir.path, 'title_$tempId.txt'));
    await titleFile.writeAsString(title, encoding: utf8);

    File? subFile;
    if (subtitle != null && subtitle.trim().isNotEmpty) {
      subFile = File(p.join(tempDir.path, 'subtitle_$tempId.txt'));
      await subFile.writeAsString(subtitle, encoding: utf8);
    }

    const fontPath = r'C\:/Windows/Fonts/segoeui.ttf';
    final escapedTitlePath = titleFile.path.replaceAll(r'\', r'/').replaceAll(':', r'\:');

    final filterBuffer = StringBuffer();
    // Title filter: centered top, with semi-transparent background box
    filterBuffer.write(
      "drawtext=fontfile='$fontPath':textfile='$escapedTitlePath':"
      "fontsize=36:fontcolor=white:box=1:boxcolor=black@0.5:boxborderw=10:"
      "x=(w-text_w)/2:y=60",
    );

    if (subFile != null) {
      final escapedSubPath = subFile.path.replaceAll(r'\', r'/').replaceAll(':', r'\:');
      filterBuffer.write(
        ",drawtext=fontfile='$fontPath':textfile='$escapedSubPath':"
        "fontsize=24:fontcolor=yellow:box=1:boxcolor=black@0.4:boxborderw=6:"
        "x=(w-text_w)/2:y=120",
      );
    }

    final args = [
      '-y',
      '-i', inputVideoPath,
      '-vf', filterBuffer.toString(),
      '-c:v', 'libx264',
      '-preset', 'fast',
      '-crf', '22',
      '-c:a', 'copy',
      outputPath,
    ];

    try {
      return await _executeWithProgress(
        args: args,
        outputPath: outputPath,
        totalDurationSeconds: durationSeconds ?? 5.0,
        stage: 'overlayTitle',
        onProgress: onProgress,
      );
    } finally {
      if (titleFile.existsSync()) titleFile.deleteSync();
      if (subFile != null && subFile.existsSync()) subFile.deleteSync();
    }
  }

  /// Burns Vietnamese SRT subtitles into video using libfreetype drawtext filter.
  Future<FfmpegResult> burnSubtitles({
    required String inputVideoPath,
    required String srtPath,
    required String outputPath,
    double totalDurationSeconds = 10.0,
    int fontSize = 28,
    void Function(FfmpegProgress)? onProgress,
  }) async {
    if (!_isAvailable || _ffmpegPath == null) {
      return FfmpegResult.failed(exitCode: 1, stderr: 'FFmpeg không khả dụng.');
    }

    _isCancelled = false;
    final srtFile = File(srtPath);
    if (!srtFile.existsSync()) {
      return FfmpegResult.failed(exitCode: 1, stderr: 'File phụ đề SRT không tồn tại: $srtPath');
    }

    final tempFiles = <File>[];
    try {
      final srtContent = await srtFile.readAsString(encoding: utf8);
      final cues = _parseSrtCues(srtContent);

      if (cues.isEmpty) {
        // No subtitles to burn -> direct copy
        final copyRes = await Process.run(_ffmpegPath!, [
          '-y', '-i', inputVideoPath, '-c', 'copy', outputPath,
        ]);
        return FfmpegResult(
          isSuccess: copyRes.exitCode == 0,
          exitCode: copyRes.exitCode,
          stdout: copyRes.stdout.toString(),
          stderr: copyRes.stderr.toString(),
          outputPath: outputPath,
          elapsed: Duration.zero,
        );
      }

      const fontPath = r'C\:/Windows/Fonts/segoeui.ttf';
      final tempDir = Directory.systemTemp;
      final tempId = DateTime.now().millisecondsSinceEpoch;
      final filterList = <String>[];

      for (int i = 0; i < cues.length; i++) {
        final cue = cues[i];
        final cueFile = File(p.join(tempDir.path, 'subcue_${tempId}_$i.txt'));
        await cueFile.writeAsString(cue.text, encoding: utf8);
        tempFiles.add(cueFile);

        final escapedPath = cueFile.path.replaceAll(r'\', r'/').replaceAll(':', r'\:');
        final start = cue.startSeconds.toStringAsFixed(2);
        final end = cue.endSeconds.toStringAsFixed(2);

        filterList.add(
          "drawtext=fontfile='$fontPath':textfile='$escapedPath':"
          "fontcolor=white:fontsize=$fontSize:box=1:boxcolor=black@0.65:boxborderw=8:"
          "x=(w-text_w)/2:y=h-text_h-50:enable='between(t,$start,$end)'",
        );
      }

      final filterGraph = filterList.join(',');
      final args = [
        '-y',
        '-i', inputVideoPath,
        '-vf', filterGraph,
        '-c:v', 'libx264',
        '-preset', 'fast',
        '-crf', '22',
        '-c:a', 'copy',
        '-progress', 'pipe:1',
        outputPath,
      ];

      return await _executeWithProgress(
        args: args,
        outputPath: outputPath,
        totalDurationSeconds: totalDurationSeconds,
        stage: 'burnSubtitles',
        onProgress: onProgress,
      );
    } finally {
      for (final f in tempFiles) {
        if (f.existsSync()) {
          try {
            f.deleteSync();
          } catch (_) {}
        }
      }
    }
  }

  /// Parses SRT subtitle text into timed cue segments.
  List<({double startSeconds, double endSeconds, String text})> _parseSrtCues(String content) {
    final cues = <({double startSeconds, double endSeconds, String text})>[];
    final blocks = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n\n');

    for (final block in blocks) {
      final lines = block.trim().split('\n');
      if (lines.length < 2) continue;

      // Find timing line (contains -->)
      int timeLineIdx = -1;
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('-->')) {
          timeLineIdx = i;
          break;
        }
      }
      if (timeLineIdx == -1) continue;

      final timeParts = lines[timeLineIdx].split('-->');
      if (timeParts.length != 2) continue;

      final startSec = _parseSrtTimestamp(timeParts[0].trim());
      final endSec = _parseSrtTimestamp(timeParts[1].trim());
      final text = lines.sublist(timeLineIdx + 1).join('\n').trim();

      if (startSec != null && endSec != null && text.isNotEmpty) {
        cues.add((startSeconds: startSec, endSeconds: endSec, text: text));
      }
    }
    return cues;
  }

  double? _parseSrtTimestamp(String ts) {
    // 00:01:23,456
    try {
      final parts = ts.split(':');
      if (parts.length != 3) return null;
      final hours = int.parse(parts[0]);
      final minutes = int.parse(parts[1]);
      final secMs = parts[2].split(RegExp(r'[,.]'));
      final seconds = int.parse(secMs[0]);
      final ms = secMs.length > 1 ? int.parse(secMs[1].padRight(3, '0').substring(0, 3)) : 0;
      return hours * 3600.0 + minutes * 60.0 + seconds + ms / 1000.0;
    } catch (_) {
      return null;
    }
  }

  /// Combines final video stream and audio stream into a valid MP4 container.
  Future<FfmpegResult> combineVideoAndAudio({
    required String videoPath,
    required String audioPath,
    required String outputPath,
    double? totalDurationSeconds,
    void Function(FfmpegProgress)? onProgress,
  }) async {
    if (!_isAvailable || _ffmpegPath == null) {
      return FfmpegResult.failed(exitCode: 1, stderr: 'FFmpeg không khả dụng.');
    }

    _isCancelled = false;
    final args = [
      '-y',
      '-i', videoPath,
      '-i', audioPath,
      '-c:v', 'copy',
      '-c:a', 'aac',
      '-b:a', '192k',
      '-shortest',
      outputPath,
    ];

    return _executeWithProgress(
      args: args,
      outputPath: outputPath,
      totalDurationSeconds: totalDurationSeconds ?? 10.0,
      stage: 'combineAudioVideo',
      onProgress: onProgress,
    );
  }

  /// Generates a fast thumbnail from an image or video file.
  Future<String?> generateThumbnail({
    required String mediaPath,
    required String outputImagePath,
    double atSeconds = 1.0,
    int width = 320,
    int height = 180,
  }) async {
    if (!_isAvailable || _ffmpegPath == null) return null;

    final outDir = Directory(p.dirname(outputImagePath));
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    final isImage = mediaPath.toLowerCase().endsWith('.jpg') ||
        mediaPath.toLowerCase().endsWith('.jpeg') ||
        mediaPath.toLowerCase().endsWith('.png') ||
        mediaPath.toLowerCase().endsWith('.webp');

    final args = <String>[
      '-y',
      if (!isImage) ...['-ss', atSeconds.toStringAsFixed(2)],
      '-i', mediaPath,
      '-vframes', '1',
      '-vf', 'scale=$width:$height:force_original_aspect_ratio=decrease,pad=$width:$height:(ow-iw)/2:(oh-ih)/2',
      outputImagePath,
    ];

    try {
      final res = await Process.run(_ffmpegPath!, args, runInShell: false)
          .timeout(const Duration(seconds: 10));
      if (res.exitCode == 0 && File(outputImagePath).existsSync()) {
        return outputImagePath;
      }
    } catch (_) {}
    return null;
  }

  /// Encodes PCM WAV file to MP3 at specified bitrate.
  Future<bool> encodeMp3({
    required String inputWavPath,
    required String outputMp3Path,
    int bitrateKbps = 192,
  }) async {
    if (!_isAvailable || _ffmpegPath == null) return false;

    try {
      final outDir = Directory(p.dirname(outputMp3Path));
      if (!outDir.existsSync()) outDir.createSync(recursive: true);

      final args = [
        '-y',
        '-i', inputWavPath,
        '-codec:a', 'libmp3lame',
        '-b:a', '${bitrateKbps}k',
        outputMp3Path,
      ];

      final res = await Process.run(_ffmpegPath!, args, runInShell: false)
          .timeout(const Duration(minutes: 5));

      return res.exitCode == 0 && File(outputMp3Path).existsSync() && File(outputMp3Path).lengthSync() > 0;
    } catch (e) {
      AppLogger.warning('FFmpeg MP3 encode failed: $e');
      return false;
    }
  }

  /// Generates an MP4 video from a still image and an audio file (Requirements 35 & 51).
  Future<bool> renderStillImageVideo({
    required String imagePath,
    required String audioPath,
    required String outputVideoPath,
    double durationSeconds = 3.0,
  }) async {
    if (!_isAvailable || _ffmpegPath == null) return false;
    try {
      final outDir = Directory(p.dirname(outputVideoPath));
      if (!outDir.existsSync()) outDir.createSync(recursive: true);

      final args = [
        '-y',
        '-loop', '1',
        '-i', imagePath,
        '-i', audioPath,
        '-c:v', 'libx264',
        '-tune', 'stillimage',
        '-c:a', 'aac',
        '-b:a', '192k',
        '-pix_fmt', 'yuv420p',
        '-t', durationSeconds.toStringAsFixed(2),
        '-shortest',
        outputVideoPath,
      ];

      final res = await Process.run(_ffmpegPath!, args, runInShell: false)
          .timeout(const Duration(seconds: 30));

      return res.exitCode == 0 && File(outputVideoPath).existsSync() && File(outputVideoPath).lengthSync() > 0;
    } catch (e) {
      AppLogger.error('renderStillImageVideo failed: $e');
      return false;
    }
  }

  /// Concatenates multiple audio files into a single audio output file.
  Future<bool> concatAudio({
    required List<String> inputAudioPaths,
    required String outputAudioPath,
  }) async {
    if (!_isAvailable || _ffmpegPath == null || inputAudioPaths.isEmpty) return false;

    File? listFile;
    try {
      final outDir = Directory(p.dirname(outputAudioPath));
      if (!outDir.existsSync()) outDir.createSync(recursive: true);

      final listPath = p.join(outDir.path, 'concat_${DateTime.now().millisecondsSinceEpoch}.txt');
      listFile = File(listPath);
      final listContent = inputAudioPaths
          .map((p) => "file '${p.replaceAll(r'\', r'/')}'")
          .join('\n');
      listFile.writeAsStringSync(listContent);

      final args = [
        '-y',
        '-f', 'concat',
        '-safe', '0',
        '-i', listFile.path,
        '-c', 'copy',
        outputAudioPath,
      ];

      final res = await Process.run(_ffmpegPath!, args, runInShell: false)
          .timeout(const Duration(minutes: 5));

      return res.exitCode == 0 && File(outputAudioPath).existsSync();
    } catch (e) {
      AppLogger.warning('FFmpeg audio concat failed: $e');
      return false;
    } finally {
      if (listFile != null && listFile.existsSync()) {
        try {
          listFile.deleteSync();
        } catch (_) {}
      }
    }
  }

  /// Executes FFmpeg command with streaming progress parsing and cancellation safety.
  Future<FfmpegResult> _executeWithProgress({
    required List<String> args,
    required String outputPath,
    required double totalDurationSeconds,
    required String stage,
    void Function(FfmpegProgress)? onProgress,
    Duration timeout = const Duration(minutes: 15),
  }) async {
    final stopwatch = Stopwatch()..start();
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();

    try {
      _activeProcess = await Process.start(
        _ffmpegPath!,
        args,
        runInShell: false,
      );

      final progressData = <String, String>{};

      // Listen to stdout (contains machine-readable key=value when using -progress pipe:1)
      _activeProcess!.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        stdoutBuffer.writeln(line);
        if (line.contains('=')) {
          final parts = line.split('=');
          if (parts.length >= 2) {
            progressData[parts[0].trim()] = parts.sublist(1).join('=').trim();
          }
        }
        if (line.startsWith('progress=')) {
          final p = FfmpegProgress.parseProgressLine(
            keyValues: progressData,
            totalDurationSeconds: totalDurationSeconds,
            currentStage: stage,
          );
          onProgress?.call(p);
        }
      });

      _activeProcess!.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        stderrBuffer.writeln(line);
      });

      final exitCode = await _activeProcess!.exitCode.timeout(timeout, onTimeout: () {
        _activeProcess?.kill(ProcessSignal.sigkill);
        throw TimeoutException('Lệnh FFmpeg đã vượt quá thời gian tối đa ($timeout).');
      });

      _activeProcess = null;
      stopwatch.stop();

      if (_isCancelled) {
        // Clean partial output file
        final outFile = File(outputPath);
        if (outFile.existsSync()) {
          try {
            outFile.deleteSync();
          } catch (_) {}
        }
        return FfmpegResult.cancelled();
      }

      final isSuccess = exitCode == 0 && File(outputPath).existsSync() && File(outputPath).lengthSync() > 100;
      if (!isSuccess) {
        AppLogger.error('FFmpeg [$stage] FAILED (exit: $exitCode):\n$stderrBuffer');
      }
      return FfmpegResult(
        isSuccess: isSuccess,
        exitCode: exitCode,
        stdout: stdoutBuffer.toString(),
        stderr: stderrBuffer.toString(),
        outputPath: outputPath,
        elapsed: stopwatch.elapsed,
      );
    } catch (e) {
      _activeProcess = null;
      stopwatch.stop();
      if (_isCancelled) {
        final outFile = File(outputPath);
        if (outFile.existsSync()) {
          try {
            outFile.deleteSync();
          } catch (_) {}
        }
        return FfmpegResult.cancelled();
      }
      return FfmpegResult.failed(exitCode: 1, stderr: e.toString(), elapsed: stopwatch.elapsed);
    }
  }
}
