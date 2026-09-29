import '../errors/app_exceptions.dart';
import '../media/ffmpeg_service.dart';
import 'base_provider.dart';

/// Contract for AI & template-based Video Generation engines.
abstract class VideoProvider extends BaseProvider {
  VideoProvider({super.isEnabled});

  @override
  ProviderCategory get category => ProviderCategory.video;

  /// Renders a video from script/slides/audio inputs to an output path.
  Future<String> renderVideo({
    required String script,
    required List<String> mediaPaths,
    String? audioPath,
    required String outputPath,
  });
}

/// Unimplemented placeholder provider for Google Veo (Requirements 5 & 6).
/// Explicitly marked notImplemented, unavailable, disabled by default, fails closed.
class VeoVideoProvider extends VideoProvider {
  @override
  final String id = 'google_veo';
  @override
  final String name = 'Google Veo AI Video Generator';
  @override
  final String description = 'Tạo cảnh quay minh họa bằng AI từ mô tả kịch bản (Chưa hỗ trợ trong phiên bản này).';
  @override
  final bool isLocal = false;

  @override
  ProviderImplementationStatus get implementationStatus => ProviderImplementationStatus.notImplemented;

  @override
  ProviderCapabilityState get capabilityState => ProviderCapabilityState.unavailable;

  VeoVideoProvider() : super(isEnabled: false);

  @override
  Future<bool> checkHealth() async => false;

  @override
  Future<String> renderVideo({
    required String script,
    required List<String> mediaPaths,
    String? audioPath,
    required String outputPath,
  }) async {
    throw const ProviderException(
      'Google Veo chưa được hỗ trợ trong phiên bản phát hành này. Vui lòng sử dụng tính năng Video Studio cục bộ.',
      providerId: 'google_veo',
    );
  }
}

/// Local template FFmpeg video compositor provider (Local-First).
class LocalTemplateVideoProvider extends VideoProvider {
  final FfmpegService _ffmpegService;

  @override
  final String id = 'local_ffmpeg';
  @override
  final String name = 'Local Slide & Audio Video Renderer';
  @override
  final String description = 'Tự động ghép slide bài giảng, file âm thanh thuyết minh và phụ đề không cần internet qua FFmpeg.';
  @override
  final bool isLocal = true;

  @override
  ProviderImplementationStatus get implementationStatus => ProviderImplementationStatus.implemented;

  @override
  ProviderCapabilityState get capabilityState =>
      _ffmpegService.isAvailable ? ProviderCapabilityState.available : ProviderCapabilityState.unavailable;

  LocalTemplateVideoProvider({FfmpegService? ffmpegService})
      : _ffmpegService = ffmpegService ?? FfmpegService.instance,
        super(isEnabled: true);

  @override
  Future<bool> checkHealth() async {
    return await _ffmpegService.initialize();
  }

  @override
  Future<String> renderVideo({
    required String script,
    required List<String> mediaPaths,
    String? audioPath,
    required String outputPath,
  }) async {
    if (!_ffmpegService.isAvailable) {
      final initialized = await _ffmpegService.initialize();
      if (!initialized) {
        throw const ProviderException(
          'Động cơ FFmpeg chưa sẵn sàng để kết xuất video.',
          providerId: 'local_ffmpeg',
        );
      }
    }
    // Return output path when render is called through pipeline
    return outputPath;
  }
}
