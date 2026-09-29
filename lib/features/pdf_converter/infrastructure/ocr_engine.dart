import '../domain/models/ocr_models.dart';

/// Abstract contract for OCR engines in NguyenDu Tool.
abstract class OcrEngine {
  /// Unique identifier of the engine (e.g. 'windows_ocr', 'vietnamese_ocr', 'tesseract_cli').
  String get id;

  /// Display name of the OCR engine.
  String get name;

  /// Indicates whether the engine is ready and available on the current machine.
  bool get isAvailable;

  /// Indicates whether the Vietnamese language pack is installed/available.
  bool get isVietnameseLanguagePackAvailable => false;

  /// Initializes engine resources.
  Future<bool> initialize();

  /// Executes OCR recognition on a single page image.
  Future<OcrPageResult> recognizePage(OcrRequest request);

  /// Releases engine resources.
  Future<void> dispose();
}
