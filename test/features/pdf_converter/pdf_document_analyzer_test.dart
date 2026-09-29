import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/features/pdf_converter/domain/models/pdf_document_analysis.dart';
import 'package:nguyendu_tool/features/pdf_converter/infrastructure/pdf_document_analyzer.dart';

void main() {
  late PdfDocumentAnalyzer analyzer;

  setUp(() {
    analyzer = PdfDocumentAnalyzer();
  });

  group('PdfDocumentAnalyzer Tests', () {
    test('01_text_vietnamese.pdf is classified as text document', () async {
      final res = await analyzer.analyze('test/fixtures/01_text_vietnamese.pdf');
      expect(res.totalPages, 1);
      expect(res.overallClassification, PdfClassification.text);
      expect(res.needsOcr, isFalse);
      expect(res.totalCharacters, greaterThan(50));
    });

    test('02_scan_vietnamese.pdf is classified as scanned document', () async {
      final res = await analyzer.analyze('test/fixtures/02_scan_vietnamese.pdf');
      expect(res.totalPages, 1);
      expect(res.overallClassification, PdfClassification.scanned);
      expect(res.needsOcr, isTrue);
    });

    test('03_mixed_document.pdf is classified as mixed document', () async {
      final res = await analyzer.analyze('test/fixtures/03_mixed_document.pdf');
      expect(res.totalPages, 1);
      expect(res.overallClassification, PdfClassification.mixed);
      expect(res.needsOcr, isTrue);
    });

    test('04_table.pdf detects table indicators', () async {
      final res = await analyzer.analyze('test/fixtures/04_table.pdf');
      expect(res.containsTables, isTrue);
    });

    test('05_multi_page.pdf counts 3 pages correctly', () async {
      final res = await analyzer.analyze('test/fixtures/05_multi_page.pdf');
      expect(res.totalPages, 3);
      expect(res.pages.length, 3);
    });

    test('Throws on non-pdf or corrupt file', () async {
      expect(
        () => analyzer.analyze('pubspec.yaml'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
