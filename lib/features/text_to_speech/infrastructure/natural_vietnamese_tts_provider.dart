import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../core/logging/app_logger.dart';
import '../../../core/media/ffmpeg_service.dart';
import '../domain/models/tts_options.dart';
import '../domain/models/tts_provider_info.dart';
import '../domain/models/tts_request.dart';
import '../domain/models/tts_voice.dart';
import '../domain/models/tts_voice_engine.dart';
import '../domain/services/tts_provider.dart';

/// Built-in High Quality Natural Vietnamese TTS Provider.
/// Uses standalone bundled Edge Neural engine for authentic Vietnamese voices:
/// - Hoài My (Nữ - Truyền cảm, Tự nhiên)
/// - Nam Minh (Nam - Trầm ấm, Chuẩn GD)
/// Zero configuration required, produces studio-grade MP3 output.
class NaturalVietnameseTtsProvider implements TtsProvider {
  @override
  final String id = 'natural_vietnamese';

  @override
  final TtsProviderInfo info = const TtsProviderInfo(
    id: 'natural_vietnamese',
    name: 'Giọng đọc AI Tiếng Việt Tự nhiên',
    description: 'Giọng đọc tự nhiên chuẩn tiếng Việt (Hoài My, Nam Minh). Hoạt động mượt mà, phát âm chuẩn sư phạm và xuất âm thanh chất lượng cao.',
    isOffline: false,
    isConfigured: true,
    supportsPitch: true,
    supportsRate: true,
    supportsWav: true,
    supportsMp3: true,
    supportsTiming: true,
    supportsChunkTiming: true,
    maxCharactersPerRequest: 10000,
    minSpeed: 0.5,
    maxSpeed: 2.0,
  );

  bool _initialized = false;
  String? _runnerPath;

  static const List<TtsVoice> _supportedVoices = [
    TtsVoice(
      id: 'vi-VN-HoaiMyNeural',
      name: 'Hoài My (Nữ - Truyền cảm, Tự nhiên)',
      language: 'vi-VN',
      locale: 'vi-VN',
      gender: 'Female',
      providerId: 'natural_vietnamese',
      isOffline: false,
      engine: TtsVoiceEngine.cloud,
    ),
    TtsVoice(
      id: 'vi-VN-NamMinhNeural',
      name: 'Nam Minh (Nam - Trầm ấm, Chuẩn GD)',
      language: 'vi-VN',
      locale: 'vi-VN',
      gender: 'Male',
      providerId: 'natural_vietnamese',
      isOffline: false,
      engine: TtsVoiceEngine.cloud,
    ),
    TtsVoice(
      id: 'vi-VN-BanMai',
      name: 'Ban Mai (Nữ - Rõ ràng, Tốc độ cao)',
      language: 'vi-VN',
      locale: 'vi-VN',
      gender: 'Female',
      providerId: 'natural_vietnamese',
      isOffline: false,
      engine: TtsVoiceEngine.cloud,
    ),
  ];

  @override
  bool get isAvailable => true;

  @override
  Future<bool> initialize() async {
    if (_initialized) return true;
    _runnerPath = _resolveRunnerExecutable();
    if (_runnerPath != null) {
      AppLogger.info('NaturalVietnameseTtsProvider: Using runner at $_runnerPath');
    }
    _initialized = true;
    return true;
  }

  String? _resolveRunnerExecutable() {
    // 1. Check relative to app executable
    try {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      final cand1 = p.join(exeDir, 'bin', 'edge_tts_runner.exe');
      if (File(cand1).existsSync()) return cand1;

      final cand2 = p.join(exeDir, 'edge_tts_runner.exe');
      if (File(cand2).existsSync()) return cand2;
    } catch (_) {}

    // 2. Check current working directory
    final cwdCand = p.join(Directory.current.path, 'bin', 'edge_tts_runner.exe');
    if (File(cwdCand).existsSync()) return cwdCand;

    return null;
  }

  @override
  Future<List<TtsVoice>> getVoices() async {
    if (!_initialized) await initialize();
    return _supportedVoices;
  }

  @override
  Future<String> synthesize(TtsRequest request) async {
    if (!_initialized) await initialize();

    final isWav = request.options.format == TtsAudioFormat.wav || 
        (request.outputPath != null && request.outputPath!.toLowerCase().endsWith('.wav'));
    final ext = isWav ? 'wav' : 'mp3';

    final targetPath = request.outputPath ??
        p.join(
          Directory.systemTemp.path,
          'tts_natural_${DateTime.now().millisecondsSinceEpoch}_${request.chunkIndex ?? 0}.$ext',
        );

    final outDir = Directory(p.dirname(targetPath));
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    final voiceId = request.voice.id.isNotEmpty ? request.voice.id : 'vi-VN-HoaiMyNeural';
    final intermediateAudio = isWav 
        ? p.join(Directory.systemTemp.path, 'tts_raw_${DateTime.now().microsecondsSinceEpoch}.mp3')
        : targetPath;

    // Write text to a temporary UTF-8 file to avoid Windows command line character encoding loss
    final tempTextFile = File(p.join(
      Directory.systemTemp.path,
      'tts_in_${DateTime.now().millisecondsSinceEpoch}_${request.chunkIndex ?? 0}.txt',
    ));
    await tempTextFile.writeAsString(request.text, flush: true);

    final ratePercent = ((request.options.speed - 1.0) * 100).round();
    final rateArg = '${ratePercent >= 0 ? "+" : ""}$ratePercent%';

    bool synthesized = false;

    // 1. Try bundled runner executable
    final runner = _runnerPath ?? _resolveRunnerExecutable();
    if (runner != null && File(runner).existsSync()) {
      try {
        final res = await Process.run(
          runner,
          ['-i', tempTextFile.path, '-o', intermediateAudio, '-v', voiceId, '-r', rateArg],
        ).timeout(const Duration(seconds: 45));

        if (res.exitCode == 0 && File(intermediateAudio).existsSync() && File(intermediateAudio).lengthSync() > 100) {
          AppLogger.info('Synthesized speech via Edge TTS Runner: $intermediateAudio');
          synthesized = true;
        } else {
          AppLogger.warning('Edge TTS Runner exited with ${res.exitCode}: ${res.stderr}');
        }
      } catch (e) {
        AppLogger.warning('Edge TTS Runner execution failed: $e');
      }
    }

    // 2. Fallback to python script if development environment
    if (!synthesized) {
      try {
        final cliScript = p.join(Directory.current.path, 'tool', 'edge_tts_cli.py');
        if (File(cliScript).existsSync()) {
          final res = await Process.run(
            'python',
            [cliScript, '-i', tempTextFile.path, '-o', intermediateAudio, '-v', voiceId, '-r', rateArg],
          ).timeout(const Duration(seconds: 45));

          if (res.exitCode == 0 && File(intermediateAudio).existsSync() && File(intermediateAudio).lengthSync() > 100) {
            synthesized = true;
          }
        }
      } catch (_) {}
    }

    // Clean up temporary text file
    try {
      if (tempTextFile.existsSync()) tempTextFile.deleteSync();
    } catch (_) {}

    // 3. Fallback to Google TTS if edge failed
    if (!synthesized) {
      await _synthesizeViaGoogleTts(request.text, intermediateAudio);
      synthesized = true;
    }

    // 4. If WAV was requested, transcode intermediate MP3 to standard PCM 16-bit WAV
    if (isWav) {
      try {
        final ffmpeg = FfmpegService.instance;
        if (!ffmpeg.isAvailable) {
          await ffmpeg.initialize();
        }
        final bin = ffmpeg.binaryPath;
        if (bin != null) {
          await Process.run(bin, [
            '-y',
            '-i', intermediateAudio,
            '-acodec', 'pcm_s16le',
            '-ac', '1',
            '-ar', '24000',
            targetPath,
          ]);
        } else {
          final f = File(intermediateAudio);
          if (f.existsSync()) await f.copy(targetPath);
        }
      } catch (e) {
        AppLogger.warning('Failed to transcode to WAV via ffmpeg: $e');
        final f = File(intermediateAudio);
        if (f.existsSync()) await f.copy(targetPath);
      } finally {
        try {
          final f = File(intermediateAudio);
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      }
    }

    return targetPath;
  }

  Future<void> _synthesizeViaGoogleTts(String text, String outputPath) async {
    final client = HttpClient();
    client.userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';

    try {
      final chunks = _splitTextForGoogleTts(text, maxChars: 180);
      final allAudioBytes = <int>[];

      for (final chunk in chunks) {
        if (chunk.trim().isEmpty) continue;
        final url = Uri.parse(
          'https://translate.google.com/translate_tts?ie=UTF-8&tl=vi&client=tw-ob&q=${Uri.encodeComponent(chunk.trim())}',
        );

        final req = await client.getUrl(url).timeout(const Duration(seconds: 15));
        final resp = await req.close().timeout(const Duration(seconds: 15));

        if (resp.statusCode == 200) {
          final chunkBytes = await resp.fold<List<int>>([], (prev, element) => prev..addAll(element));
          allAudioBytes.addAll(chunkBytes);
        }
      }

      if (allAudioBytes.isEmpty) {
        throw const HttpException('Không thể nhận luồng âm thanh từ dịch vụ TTS.');
      }

      final file = File(outputPath);
      await file.writeAsBytes(allAudioBytes, flush: true);
    } finally {
      client.close();
    }
  }

  List<String> _splitTextForGoogleTts(String text, {int maxChars = 180}) {
    if (text.length <= maxChars) return [text];

    final result = <String>[];
    final sentences = text.split(RegExp(r'(?<=[.?!,;\n])\s+'));
    var current = StringBuffer();

    for (final s in sentences) {
      if (current.length + s.length + 1 <= maxChars) {
        if (current.isNotEmpty) current.write(' ');
        current.write(s);
      } else {
        if (current.isNotEmpty) {
          result.add(current.toString());
          current = StringBuffer();
        }
        if (s.length > maxChars) {
          for (int i = 0; i < s.length; i += maxChars) {
            final end = (i + maxChars < s.length) ? i + maxChars : s.length;
            result.add(s.substring(i, end));
          }
        } else {
          current.write(s);
        }
      }
    }
    if (current.isNotEmpty) {
      result.add(current.toString());
    }
    return result;
  }

  @override
  Future<void> cancel() async {
    // Current one-shot process will complete or timeout
  }

  @override
  Future<void> dispose() async {
    _initialized = false;
  }
}
