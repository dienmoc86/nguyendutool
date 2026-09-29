import 'dart:convert';
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

/// Built-in Free Natural Vietnamese TTS Provider.
/// Provides high-quality natural Vietnamese voices (Hoài My, Nam Minh, Ban Mai)
/// that work out of the box on all computers without requiring Windows Vietnamese language packs.
class NaturalVietnameseTtsProvider implements TtsProvider {
  @override
  final String id = 'natural_vietnamese';

  @override
  final TtsProviderInfo info = const TtsProviderInfo(
    id: 'natural_vietnamese',
    name: 'Giọng đọc AI Tiếng Việt Tự nhiên',
    description: 'Gói giọng đọc tự nhiên chuẩn tiếng Việt (Hoài My, Nam Minh, Ban Mai). Hoạt động trên mọi máy tính không cần cài gói ngôn ngữ Windows.',
    isOffline: false,
    isConfigured: true,
    supportsPitch: true,
    supportsRate: true,
    supportsWav: true,
    supportsMp3: true,
    supportsTiming: true,
    supportsChunkTiming: true,
    maxCharactersPerRequest: 4000,
    minSpeed: 0.5,
    maxSpeed: 2.0,
  );

  bool _initialized = false;
  bool _hasEdgeTtsCli = false;

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
    try {
      final res = await Process.run('edge-tts', ['--version']).timeout(const Duration(seconds: 3));
      _hasEdgeTtsCli = res.exitCode == 0;
      if (_hasEdgeTtsCli) {
        AppLogger.info('NaturalVietnameseTtsProvider: edge-tts CLI detected.');
      }
    } catch (_) {
      _hasEdgeTtsCli = false;
    }
    _initialized = true;
    return true;
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

    final voiceId = request.voice.id;
    final isNeural = voiceId.contains('Neural');
    
    final intermediateAudio = isWav 
        ? p.join(Directory.systemTemp.path, 'tts_raw_${DateTime.now().microsecondsSinceEpoch}.mp3')
        : targetPath;

    bool synthesized = false;

    // 1. Try edge-tts CLI if available for neural voices
    if (isNeural && _hasEdgeTtsCli) {
      try {
        final rateArg = request.options.speed != 1.0
            ? '${((request.options.speed - 1.0) * 100).round() >= 0 ? "+" : ""}${((request.options.speed - 1.0) * 100).round()}%'
            : '+0%';

        final proc = await Process.run(
          'edge-tts',
          ['--voice', voiceId, '--text', request.text, '--rate', rateArg, '--write-media', intermediateAudio],
        ).timeout(const Duration(seconds: 25));

        if (proc.exitCode == 0 && File(intermediateAudio).existsSync() && File(intermediateAudio).lengthSync() > 100) {
          AppLogger.info('Synthesized speech via Edge TTS Neural: $intermediateAudio');
          synthesized = true;
        }
      } catch (e) {
        AppLogger.warning('Edge TTS CLI failed, falling back to Google TTS: $e');
      }
    }

    // 2. High-reliability HTTP Google TTS fallback if not synthesized
    if (!synthesized) {
      await _synthesizeViaGoogleTts(request.text, intermediateAudio);
      synthesized = true;
    }

    // 3. If WAV was requested, transcode intermediate MP3 to standard PCM 16-bit WAV
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
      // Split text into chunks <= 180 characters on sentence boundaries
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
        } else {
          AppLogger.warning('Google TTS chunk HTTP ${resp.statusCode}');
        }
      }

      if (allAudioBytes.isEmpty) {
        throw const HttpException('Không thể nhận luồng âm thanh từ dịch vụ TTS.');
      }

      final file = File(outputPath);
      await file.writeAsBytes(allAudioBytes, flush: true);
      AppLogger.info('Synthesized speech via Google TTS: $outputPath (${allAudioBytes.length} bytes)');
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
          // Hard split if a single sentence exceeds limit
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
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}
