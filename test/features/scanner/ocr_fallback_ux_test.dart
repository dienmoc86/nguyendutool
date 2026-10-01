import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:nguyendu_tool/features/pdf_converter/domain/models/ocr_models.dart';
import 'package:nguyendu_tool/features/pdf_converter/infrastructure/vietnamese_ocr_engine.dart';

void main() {
  group('OCR Explicit Fallback Consent (Entry Remediation 0.A)', () {
    test('VietnameseOcrEngine does NOT silently fallback when allowFallbackLanguage is false', () async {
      final engine = VietnameseOcrEngine();
      final hasOcr = await engine.initialize();

      if (!hasOcr) {
        // OCR not available on platform
        return;
      }

      final tempDir = Directory.systemTemp.createTempSync('ocr_fallback_test_');
      final imgPath = p.join(tempDir.path, 'sample_ocr_fallback.png');
      final dummyImg = img.Image(width: 400, height: 200);
      img.fill(dummyImg, color: img.ColorRgb8(255, 255, 255));
      await File(imgPath).writeAsBytes(img.encodePng(dummyImg));

      final hasVi = engine.hasVietnameseLanguagePack;

      if (!hasVi) {
        // When vi-VN is NOT installed, calling with allowFallbackLanguage: false MUST throw OcrLanguageUnavailableException!
        expect(
          () async => await engine.recognizePage(
            OcrRequest(
              imagePath: imgPath,
              pageNumber: 1,
              language: 'vie',
              allowFallbackLanguage: false, // Strict: no silent fallback
            ),
          ),
          throwsA(isA<OcrLanguageUnavailableException>()),
        );

        // When user explicitly consents (allowFallbackLanguage: true), it succeeds with available language
        final fallbackResult = await engine.recognizePage(
          OcrRequest(
            imagePath: imgPath,
            pageNumber: 1,
            language: 'vie',
            allowFallbackLanguage: true, // Explicit user consent
          ),
        );
        expect(fallbackResult, isNotNull);
      } else {
        // vi-VN is installed, recognizing with allowFallbackLanguage: false succeeds without throwing
        final result = await engine.recognizePage(
          OcrRequest(
            imagePath: imgPath,
            pageNumber: 1,
            language: 'vie',
            allowFallbackLanguage: false,
          ),
        );
        expect(result.languageUsed?.toLowerCase(), startsWith('vi'));
      }

      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });
  });
}
