import '../../features/pdf_converter/domain/models/ocr_models.dart';
import '../../features/pdf_converter/infrastructure/vietnamese_ocr_engine.dart';
import 'base_provider.dart';

/// Contract for Optical Character Recognition and layout analysis engines.
abstract class OcrProvider extends BaseProvider {
  OcrProvider({super.isEnabled});

  @override
  ProviderCategory get category => ProviderCategory.ocr;

  /// Performs OCR on an image/document file and returns extracted text.
  Future<String> recognizeText(String imagePath, {String? language});
}

/// Production Windows Native OCR Provider wired to [VietnameseOcrEngine].
class LocalWindowsOcrProvider extends OcrProvider {
  final VietnameseOcrEngine _engine;

  @override
  final String id = 'windows_ocr';
  @override
  final String name = 'Windows Native OCR Engine';
  @override
  final String description =
      'Nhận diện tài liệu và chữ viết trực tiếp trên máy tính Windows, bảo mật hoàn toàn.';
  @override
  final bool isLocal = true;

  @override
  ProviderImplementationStatus get implementationStatus => ProviderImplementationStatus.implemented;

  @override
  ProviderCapabilityState get capabilityState => ProviderCapabilityState.available;

  LocalWindowsOcrProvider({VietnameseOcrEngine? engine})
      : _engine = engine ?? VietnameseOcrEngine(),
        super(isEnabled: true);

  @override
  Future<bool> checkHealth() async {
    return await _engine.initialize();
  }

  @override
  Future<String> recognizeText(String imagePath, {String? language}) async {
    await _engine.initialize();
    final result = await _engine.recognizePage(
      OcrRequest(
        imagePath: imagePath,
        pageNumber: 1,
        language: language ?? 'vie',
      ),
    );
    return result.fullText;
  }
}
