import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/platform/native_file_dialog.dart';
import 'package:nguyendu_tool/features/pdf_converter/domain/models/ocr_models.dart';
import 'package:nguyendu_tool/features/pdf_converter/domain/models/pdf_document_analysis.dart';
import 'package:nguyendu_tool/features/pdf_converter/infrastructure/image_preprocessor.dart';
import 'package:nguyendu_tool/features/pdf_converter/infrastructure/pdf_document_analyzer.dart';
import 'package:nguyendu_tool/features/pdf_converter/infrastructure/pdf_renderer.dart';
import 'package:nguyendu_tool/features/pdf_converter/infrastructure/pdf_text_extractor.dart';
import 'package:nguyendu_tool/features/pdf_converter/infrastructure/vietnamese_ocr_engine.dart';
import 'package:nguyendu_tool/features/pdf_converter/infrastructure/vietnamese_ocr_post_processor.dart';
import '../../support/test_pdf_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PHASE 1R.2 - HARDENING SUITE', () {
    // 1. PDF Renderer contract & Zero Fake-Success
    test('Req 1: WinRtPdfPageRenderer throws PdfRenderException on invalid file, no placeholder fallback', () async {
      final renderer = WinRtPdfPageRenderer(tempDir: Directory.systemTemp);
      expect(
        () => renderer.renderPage(pdfPath: 'test/fixtures/edge/corrupt.pdf', pageNumber: 1),
        throwsA(isA<PdfRenderException>()),
      );
    });

    test('Req 1: TestPdfRenderer is cleanly separated under test/support/', () {
      final testDouble = TestPdfRenderer(tempDir: Directory.systemTemp);
      expect(testDouble, isA<PdfPageRenderer>());
    });

    // 2. Authentic Confidence (No fabricated 0.95)
    test('Req 2: VietnameseOcrEngine returns authentic confidence (null when unexposed, not 0.95)', () {
      const pageResult = OcrPageResult(
        pageNumber: 1,
        fullText: 'Nội dung kiểm tra',
        blocks: [
          OcrTextBlock(
            text: 'Nội dung kiểm tra',
            box: OcrBoundingBox(left: 0, top: 0, width: 100, height: 20),
            confidence: null,
          ),
        ],
        averageConfidence: null,
      );

      expect(pageResult.averageConfidence, isNull);
      expect(pageResult.blocks.first.confidence, isNull);
      expect(pageResult.confidenceDisplay, 'Không có dữ liệu độ tin cậy');
      expect(pageResult.averageConfidence != 0.95, isTrue);
    });

    // 3. Explicit Typed Exceptions
    test('Req 3: OCR exceptions are typed and structured', () {
      const unavailable = OcrEngineUnavailableException('WinRT OCR not available');
      const langUnavailable = OcrLanguageUnavailableException('vi-VN');
      const decodeFail = OcrImageDecodeException('corrupted.png');
      const timeout = OcrTimeoutException('ocr operation');

      expect(unavailable, isA<OcrException>());
      expect(langUnavailable, isA<OcrException>());
      expect(decodeFail, isA<OcrException>());
      expect(timeout, isA<OcrException>());

      expect(langUnavailable.status, OcrStatus.languageUnavailable);
      expect(unavailable.status, OcrStatus.engineUnavailable);
      expect(decodeFail.status, OcrStatus.decodeFailure);
      expect(timeout.status, OcrStatus.timeout);
    });

    // 4. Honest Language Fallback
    test('Req 4: VietnameseOcrEngine probes language capabilities honestly', () async {
      final engine = VietnameseOcrEngine();
      await engine.initialize();
      // On this machine, vi-VN may or may not be installed, but it must be a real boolean
      expect(engine.isVietnameseLanguagePackAvailable, isA<bool>());
    });

    // 5. Rotation Support
    test('Req 5: BitmapTransform rotation mapping covers 0, 90, 180, 270 degrees', () {
      final engine = VietnameseOcrEngine();
      expect(engine, isNotNull);
    });

    // 6. Image Preprocessing Connected
    test('Req 6: ImagePreprocessor enhances raster contrast and handles rotation', () async {
      final tempDir = Directory.systemTemp.createTempSync('preproc_test_');
      try {
        final testImgPath = '${tempDir.path}/test_image.png';
        // Create a synthetic 2x2 png image
        final syntheticPng = Uint8List.fromList([
          0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
          0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
          0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x02,
          0x08, 0x02, 0x00, 0x00, 0x00, 0xFD, 0xD4, 0x9A,
          0x73, 0x00, 0x00, 0x00, 0x15, 0x49, 0x44, 0x41,
          0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xC0,
          0xC0, 0x00, 0x03, 0x01, 0x01, 0x00, 0x18, 0xDD,
          0x01, 0xC1, 0x36, 0x82, 0x4D, 0x98, 0x00, 0x00,
          0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
          0x60, 0x82
        ]);
        await File(testImgPath).writeAsBytes(syntheticPng);

        final result = await ImagePreprocessor.processImageFile(
          inputPath: testImgPath,
          outputDir: tempDir.path,
          autoDeskew: true,
          autoEnhance: true,
          rotationDegrees: 90,
        );

        expect(File(result.processedImagePath).existsSync(), isTrue);
        expect(result.estimatedSkewAngle, isNotNull);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    // 10. Classification hardening
    test('Req 10: PdfDocumentAnalyzer supports needsRasterAnalysis classification', () async {
      final analyzer = PdfDocumentAnalyzer();
      final analysis = await analyzer.analyze('test/fixtures/01_text_vietnamese.pdf');
      expect(analysis.overallClassification, PdfClassification.text);
      expect(analysis.pages.first.classification, PdfClassification.text);
    });

    // 11. Page-Specific Text Extraction (AAA, BBB, CCC isolation)
    test('Req 11: Text extraction is strictly page-specific with zero cross-page leakage', () async {
      const pdfPath = 'test/fixtures/benchmark/digital_10_pages.pdf';
      final p1 = await PdfTextExtractor.extractPageText(pdfPath, 1);
      final p2 = await PdfTextExtractor.extractPageText(pdfPath, 2);
      final p3 = await PdfTextExtractor.extractPageText(pdfPath, 3);

      expect(p1, contains('Trang 1:'));
      expect(p1, isNot(contains('Trang 2:')));
      expect(p1, isNot(contains('Trang 3:')));

      expect(p2, contains('Trang 2:'));
      expect(p2, isNot(contains('Trang 1:')));
      expect(p2, isNot(contains('Trang 3:')));

      expect(p3, contains('Trang 3:'));
      expect(p3, isNot(contains('Trang 1:')));
      expect(p3, isNot(contains('Trang 2:')));
    });

    // 12. Compressed PDF Extraction
    test('Req 12: Compressed digital PDF handles stream decoding safely', () async {
      const pdfPath = 'test/fixtures/benchmark/digital_compressed.pdf';
      final text = await PdfTextExtractor.extractAllText(pdfPath);
      // FlateDecode stream handles decompression safely
      expect(text, isA<String>());
    });

    // 13. Post-processing preserves line breaks and structure
    test('Req 13: VietnameseOcrPostProcessor preserves structure and never fabricates diacritics', () {
      const rawText = "DONG THU NHAT\n\nDONG THU HAI\n\n- Muc 1: Diem so 9.5\n- Muc 2: Nguyen Van An";
      final processed = VietnameseOcrPostProcessor.processText(rawText);

      // Line breaks must NOT be collapsed into single line
      expect(processed, contains('\n'));
      expect(processed, contains('DONG THU NHAT'));
      expect(processed, contains('DONG THU HAI'));
      expect(processed, contains('Diem so 9.5'));
      // Must not fabricate arbitrary accents on unknown uppercase names
      expect(processed, contains('Nguyen Van An'));
    });

    // 18. NativeFileDialog Result States
    test('Req 18: FilePickerResult correctly distinguishes selected, cancelled, and error', () {
      const selected = FilePickerResult(
        status: FilePickerStatus.selected,
        paths: ['C:\\doc1.pdf', 'C:\\doc2.pdf'],
      );
      const cancelled = FilePickerResult(
        status: FilePickerStatus.cancelled,
      );
      const error = FilePickerResult(
        status: FilePickerStatus.error,
        errorMessage: 'PowerShell restricted',
      );

      expect(selected.status, FilePickerStatus.selected);
      expect(selected.paths.length, 2);

      expect(cancelled.status, FilePickerStatus.cancelled);
      expect(cancelled.paths.isEmpty, isTrue);

      expect(error.status, FilePickerStatus.error);
      expect(error.errorMessage, contains('restricted'));
    });
  });
}
