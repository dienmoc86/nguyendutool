import 'package:nguyendu_tool/features/pdf_converter/domain/models/ocr_models.dart';
import 'package:nguyendu_tool/features/pdf_converter/infrastructure/ocr_engine.dart';

/// Test double implementing [OcrEngine] for unit tests.
class MockOcrEngine implements OcrEngine {
  final Map<int, OcrPageResult> pageResults;
  final bool shouldFail;
  final Exception? failWithException;

  MockOcrEngine({
    this.pageResults = const {},
    this.shouldFail = false,
    this.failWithException,
  });

  @override
  String get id => 'mock_ocr';

  @override
  String get name => 'Mock Test OCR Engine';

  @override
  bool get isAvailable => true;

  @override
  bool get isVietnameseLanguagePackAvailable => true;

  @override
  Future<bool> initialize() async => true;

  @override
  Future<OcrPageResult> recognizePage(OcrRequest request) async {
    if (shouldFail) {
      throw failWithException ??
          const OcrProcessException('MockOcrEngine intentionally configured to fail.');
    }

    if (pageResults.containsKey(request.pageNumber)) {
      return pageResults[request.pageNumber]!;
    }

    return OcrPageResult(
      pageNumber: request.pageNumber,
      blocks: [
        OcrTextBlock(
          text: 'Mock OCR content for page ${request.pageNumber}',
          box: const OcrBoundingBox(left: 50, top: 50, width: 400, height: 20),
          confidence: null,
        ),
      ],
      fullText: 'Mock OCR content for page ${request.pageNumber}',
      averageConfidence: null,
      durationMs: 10,
      status: OcrStatus.success,
      languageUsed: 'mock-test',
    );
  }

  @override
  Future<void> dispose() async {}
}
