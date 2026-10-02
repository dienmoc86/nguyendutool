import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../core/logging/app_logger.dart';
import '../../../core/media/ffmpeg_service.dart';
import '../domain/models/ai_video_generation_request.dart';

/// Service connecting NguyenDu Tool Video Studio to Open-Sora (HPC-AI Tech)
/// and Cloud AI Video diffusion endpoints.
///
/// Architecture:
/// - Connects to local/remote GPU servers hosting Open-Sora (FastAPI / Gradio / REST).
/// - Transmits text prompt, duration, resolution, aspect ratio.
/// - Downloads and catalogs the resulting MP4 video clip into local media storage.
/// - Provides intelligent local fallback preview via bundled FFmpeg when offline.
class OpenSoraVideoService {
  static OpenSoraVideoService? _instance;
  static OpenSoraVideoService get instance => _instance ??= OpenSoraVideoService();

  final FfmpegService _ffmpeg;

  OpenSoraVideoService({FfmpegService? ffmpegService})
      : _ffmpeg = ffmpegService ?? FfmpegService.instance;

  /// Tests connectivity to the Open-Sora GPU backend.
  Future<bool> testConnection(String serverUrl, {String? apiKey}) async {
    final cleanUrl = serverUrl.trim();
    if (cleanUrl.isEmpty) return false;

    HttpClient? client;
    try {
      final uri = Uri.parse(cleanUrl);
      client = HttpClient()..connectionTimeout = const Duration(seconds: 4);

      final request = await client.getUrl(uri);
      if (apiKey != null && apiKey.trim().isNotEmpty) {
        request.headers.set('Authorization', 'Bearer ${apiKey.trim()}');
      }

      final response = await request.close().timeout(const Duration(seconds: 5));
      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (e) {
      AppLogger.info('OpenSora connection test to $cleanUrl: not reachable ($e)');
      return false;
    } finally {
      client?.close();
    }
  }

  /// Generates an AI video clip from text using Open-Sora or cloud provider.
  Future<String> generateVideo({
    required AiVideoGenerationRequest request,
    void Function(double progress, String stage)? onProgress,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outDir = Directory(p.join(Directory.systemTemp.path, 'nguyendu_ai_videos'));
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }
    final targetVideoPath = p.join(outDir.path, 'ai_clip_$timestamp.mp4');

    onProgress?.call(0.1, 'Đang kết nối tới máy chủ Open-Sora...');

    final isReachable = await testConnection(request.serverUrl, apiKey: request.apiKey);

    if (isReachable) {
      try {
        onProgress?.call(0.3, 'Đang gửi kịch bản mô tả cho Open-Sora GPU...');
        final downloadedPath = await _requestRemoteOpenSora(request, targetVideoPath, onProgress);
        if (downloadedPath != null && File(downloadedPath).existsSync()) {
          onProgress?.call(1.0, 'Đã hoàn tất sinh video AI!');
          return downloadedPath;
        }
      } catch (e) {
        AppLogger.warning('Open-Sora server request failed, falling back to visual generator: $e');
      }
    }

    // Offline / Standby mode: Generate motion preview clip using FFmpeg
    onProgress?.call(0.5, 'Máy chủ GPU chưa kết nối, đang tạo video minh họa mô phỏng...');
    final fallbackPath = await _generateVisualAiPreviewClip(request, targetVideoPath);
    onProgress?.call(1.0, 'Video mô phỏng kịch bản AI đã sẵn sàng.');
    return fallbackPath;
  }

  Future<String?> _requestRemoteOpenSora(
    AiVideoGenerationRequest request,
    String targetPath,
    void Function(double progress, String stage)? onProgress,
  ) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final baseUri = Uri.parse(request.serverUrl.trim());
      final endpoint = baseUri.replace(
        path: baseUri.path.endsWith('/') ? '${baseUri.path}generate' : '${baseUri.path}/generate',
      );

      final req = await client.postUrl(endpoint);
      req.headers.contentType = ContentType.json;
      if (request.apiKey != null && request.apiKey!.trim().isNotEmpty) {
        req.headers.set('Authorization', 'Bearer ${request.apiKey!.trim()}');
      }

      final payload = jsonEncode({
        'prompt': request.prompt,
        'negative_prompt': request.negativePrompt ?? 'low quality, blurry, distorted',
        'duration': request.durationSeconds,
        'aspect_ratio': request.aspectRatio,
        'resolution': request.resolution,
        'fps': request.fps,
      });

      req.write(payload);
      final resp = await req.close().timeout(const Duration(minutes: 5));

      if (resp.statusCode == 200) {
        final contentType = resp.headers.contentType?.mimeType ?? '';

        // If direct video binary
        if (contentType.contains('video') || contentType.contains('octet-stream')) {
          onProgress?.call(0.8, 'Đang tải tệp video MP4 về máy tính...');
          final file = File(targetPath);
          final sink = file.openWrite();
          await resp.pipe(sink);
          await sink.flush();
          await sink.close();
          return targetPath;
        }

        // If JSON response with video URL
        final body = await resp.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        if (data is Map<String, dynamic>) {
          final videoUrl = data['video_url'] ?? data['url'] ?? data['output'];
          if (videoUrl is String && videoUrl.isNotEmpty) {
            onProgress?.call(0.85, 'Đang tải kết quả từ máy chủ...');
            await _downloadFile(videoUrl, targetPath);
            return targetPath;
          }
        }
      }
    } catch (e) {
      AppLogger.warning('Error communicating with Open-Sora endpoint: $e');
    } finally {
      client.close();
    }
    return null;
  }

  Future<void> _downloadFile(String url, String destination) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(Uri.parse(url));
      final resp = await req.close();
      if (resp.statusCode == 200) {
        final file = File(destination);
        final sink = file.openWrite();
        await resp.pipe(sink);
        await sink.flush();
        await sink.close();
      }
    } finally {
      client.close();
    }
  }

  /// Generates a local dynamic preview video clip matching project aspect ratio and duration.
  Future<String> _generateVisualAiPreviewClip(
    AiVideoGenerationRequest request,
    String outputPath,
  ) async {
    await _ffmpeg.initialize();
    final ffmpegPath = _ffmpeg.ffmpegPath;

    // Dimensions
    int width = 1280;
    int height = 720;
    if (request.aspectRatio == '9:16') {
      width = 720;
      height = 1280;
    } else if (request.aspectRatio == '1:1') {
      width = 720;
      height = 720;
    }

    final duration = request.durationSeconds.clamp(1.0, 30.0);

    if (ffmpegPath != null && File(ffmpegPath).existsSync()) {
      try {
        final process = await Process.run(
          ffmpegPath,
          [
            '-y',
            '-f',
            'lavfi',
            '-i',
            'gradients=s=${width}x$height:c0=0x1e3c72:c1=0x2a5298:d=$duration:r=24',
            '-t',
            duration.toStringAsFixed(1),
            '-c:v',
            'libx264',
            '-pix_fmt',
            'yuv420p',
            '-an',
            outputPath,
          ],
        );

        if (process.exitCode == 0 && File(outputPath).existsSync()) {
          return outputPath;
        }
      } catch (e) {
        AppLogger.warning('FFmpeg gradients generator failed, trying color fallback: $e');
      }

      // Simpler color fallback
      try {
        await Process.run(
          ffmpegPath,
          [
            '-y',
            '-f',
            'lavfi',
            '-i',
            'color=c=0x1e3c72:s=${width}x$height:d=$duration:r=24',
            '-t',
            duration.toStringAsFixed(1),
            '-c:v',
            'libx264',
            '-pix_fmt',
            'yuv420p',
            '-an',
            outputPath,
          ],
        );
        if (File(outputPath).existsSync()) {
          return outputPath;
        }
      } catch (_) {}
    }

    return outputPath;
  }
}
