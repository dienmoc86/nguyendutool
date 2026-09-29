import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:nguyendu_tool/features/pdf_converter/domain/models/ocr_models.dart';
import 'package:nguyendu_tool/features/scanner/domain/models/scan_options.dart';
import 'package:nguyendu_tool/features/scanner/domain/models/scan_page.dart';
import 'package:nguyendu_tool/features/scanner/infrastructure/searchable_pdf_generator.dart';

void main() {
  final tempDir = Directory(p.join(Directory.current.path, 'test', 'temp_searchable_pdf_test'));

  setUpAll(() {
    if (!tempDir.existsSync()) {
      tempDir.createSync(recursive: true);
    }
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('SearchablePdfGenerator - 5-Page Searchable PDF Validation', () {
    test('Generates valid 5-page Searchable PDF with DCT images and UTF-16BE text overlay', () async {
      final now = DateTime.now();
      final pages = <ScanPage>[];

      final testPhrases = [
        'CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM',
        'Độc lập - Tự do - Hạnh phúc',
        'TRƯỜNG THCS NGUYỄN DU',
        'KẾ HOẠCH GIẢNG DẠY MÔN NGỮ VĂN NĂM HỌC 2026',
        'Đạt chuẩn quốc gia về giáo dục và đào tạo chất lượng cao',
      ];

      // Create 5 test page image files and corresponding OCR results
      for (int i = 0; i < 5; i++) {
        final imgObj = img.Image(width: 800, height: 1100);
        img.fill(imgObj, color: img.ColorRgb8(250, 250, 250));
        // Draw some visual lines
        img.fillRect(imgObj, x1: 100, y1: 150, x2: 700, y2: 170, color: img.ColorRgb8(50, 50, 50));
        img.fillRect(imgObj, x1: 100, y1: 220, x2: 500, y2: 240, color: img.ColorRgb8(80, 80, 80));

        final imgPath = p.join(tempDir.path, 'test_page_${i + 1}.png');
        await File(imgPath).writeAsBytes(img.encodePng(imgObj));

        final phrase = testPhrases[i];
        final ocrRes = OcrPageResult(
          pageNumber: i + 1,
          blocks: [
            OcrTextBlock(
              text: phrase,
              box: const OcrBoundingBox(left: 100, top: 150, width: 600, height: 25),
            ),
            const OcrTextBlock(
              text: 'Nội dung chi tiết chương trình học kỳ II',
              box: OcrBoundingBox(left: 100, top: 220, width: 400, height: 20),
            ),
          ],
          fullText: '$phrase\nNội dung chi tiết chương trình học kỳ II',
          durationMs: 120,
          status: OcrStatus.success,
          languageUsed: 'vi-VN',
        );

        pages.add(
          ScanPage(
            id: 'page_test_${i + 1}',
            sessionId: 'session_searchable_test',
            pageIndex: i,
            originalPath: imgPath,
            processedPath: imgPath,
            ocrResult: ocrRes,
            ocrStatus: 'done',
            createdAt: now,
          ),
        );
      }

      final outPdfPath = p.join(tempDir.path, 'NguyenDu_Searchable_5Pages.pdf');
      final generator = SearchablePdfGenerator();

      final resultPath = await generator.generatePdf(
        pages: pages,
        options: ScanOutputOptions(
          format: ScanOutputFormat.searchablePdf,
          outputPath: outPdfPath,
          quality: ScanOutputQuality.balanced,
        ),
      );

      final pdfFile = File(resultPath);
      expect(pdfFile.existsSync(), isTrue);
      expect(await pdfFile.length(), greaterThan(10000));

      final pdfBytes = await pdfFile.readAsBytes();
      final pdfContent = latin1.decode(pdfBytes, allowInvalid: true);

      // Verify PDF Header
      expect(pdfContent, contains('%PDF-1.5'));

      // Verify 5 Pages count in Pages dictionary
      expect(pdfContent, contains('/Count 5'));

      // Verify Invisible text mode "3 Tr" exists
      expect(pdfContent, contains('3 Tr'));

      // Verify /ActualText with UTF-16BE bytes exists
      expect(pdfContent, contains('/ActualText <FEFF'));

      // Verify EOF marker
      expect(pdfContent, contains('%%EOF'));

      // Validate each page's Vietnamese text is encoded in UTF-16BE
      for (final phrase in testPhrases) {
        final utf16beBuf = StringBuffer('<FEFF');
        for (int c = 0; c < phrase.length; c++) {
          utf16beBuf.write(phrase.codeUnitAt(c).toRadixString(16).padLeft(4, '0').toUpperCase());
        }
        utf16beBuf.write('>');
        final expectedTag = utf16beBuf.toString();

        expect(
          pdfContent.contains(expectedTag),
          isTrue,
          reason: 'Expected phrase "$phrase" encoded as $expectedTag in Searchable PDF',
        );
      }
    });
  });
}
