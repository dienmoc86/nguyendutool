import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import '../../../core/logging/app_logger.dart';
import '../../../core/media/ffmpeg_service.dart';

/// Fast thumbnail generator and disk-cache manager using FFmpeg.
class ThumbnailService {
  final FfmpegService _ffmpegService;
  final Directory _cacheDir;

  ThumbnailService({
    FfmpegService? ffmpegService,
    Directory? customCacheDir,
  })  : _ffmpegService = ffmpegService ?? FfmpegService.instance,
        _cacheDir = customCacheDir ??
            Directory(p.join(Directory.systemTemp.path, 'nguyendu_video_thumbnails')) {
    if (!_cacheDir.existsSync()) {
      _cacheDir.createSync(recursive: true);
    }
  }

  /// Returns cached thumbnail path or extracts a new thumbnail using FFmpeg.
  Future<String?> getThumbnail({
    required String mediaPath,
    double atSeconds = 1.0,
    int width = 320,
    int height = 180,
  }) async {
    final mediaFile = File(mediaPath);
    if (!mediaFile.existsSync()) return null;

    final key = crypto.md5.convert('$mediaPath:$atSeconds:${width}x$height'.codeUnits).toString();
    final cachedPath = p.join(_cacheDir.path, 'thumb_$key.jpg');
    final cachedFile = File(cachedPath);

    if (cachedFile.existsSync() && cachedFile.lengthSync() > 100) {
      return cachedPath;
    }

    try {
      final generated = await _ffmpegService.generateThumbnail(
        mediaPath: mediaPath,
        outputImagePath: cachedPath,
        atSeconds: atSeconds,
        width: width,
        height: height,
      );
      return generated;
    } catch (e) {
      AppLogger.warning('Thumbnail generation error for $mediaPath: $e');
      return null;
    }
  }

  /// Clears thumbnail disk cache.
  void clearCache() {
    try {
      if (_cacheDir.existsSync()) {
        _cacheDir.deleteSync(recursive: true);
        _cacheDir.createSync(recursive: true);
      }
    } catch (_) {}
  }
}
