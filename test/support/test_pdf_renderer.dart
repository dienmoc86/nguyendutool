import 'dart:io';
import 'package:nguyendu_tool/features/pdf_converter/domain/models/conversion_options.dart';
import 'package:nguyendu_tool/features/pdf_converter/infrastructure/pdf_renderer.dart';

/// Test-only double of PdfPageRenderer.
/// NEVER used or referenced in production `lib/`.
class TestPdfRenderer implements PdfPageRenderer {
  final Directory tempDir;
  final bool shouldFail;
  final String? fixedImagePath;

  TestPdfRenderer({
    required this.tempDir,
    this.shouldFail = false,
    this.fixedImagePath,
  });

  @override
  Future<String> renderPage({
    required String pdfPath,
    required int pageNumber,
    DpiPreset dpi = DpiPreset.high200,
    int? rotationDegrees,
  }) async {
    if (shouldFail) {
      throw const PdfRenderException('Simulated test rendering failure');
    }

    if (fixedImagePath != null && File(fixedImagePath!).existsSync()) {
      return fixedImagePath!;
    }

    // Write a standard 1x1 test image for isolated widget/unit tests
    final dummyPath = '${tempDir.path}/test_page_$pageNumber.png';
    final dummyFile = File(dummyPath);
    if (!dummyFile.existsSync()) {
      await dummyFile.writeAsBytes(const [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
        0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,
        0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
        0x00, 0x03, 0x01, 0x01, 0x00, 0x18, 0xDD, 0x8D,
        0xB0, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
        0x44, 0xAE, 0x42, 0x60, 0x82,
      ]);
    }
    return dummyPath;
  }

  @override
  Future<void> cleanup() async {
    if (tempDir.existsSync()) {
      for (final f in tempDir.listSync()) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    }
  }
}
