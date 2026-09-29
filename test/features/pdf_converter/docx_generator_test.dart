import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/features/pdf_converter/domain/models/layout_models.dart';
import 'package:nguyendu_tool/features/pdf_converter/domain/models/ocr_models.dart';
import 'package:nguyendu_tool/features/pdf_converter/domain/models/table_models.dart';
import 'package:nguyendu_tool/features/pdf_converter/infrastructure/docx_generator.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late DocxGenerator generator;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('docx_test_');
    generator = DocxGenerator();
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('DocxGenerator Tests', () {
    test('Produces valid OpenXML .docx with Vietnamese text and tables', () async {
      final outPath = p.join(tempDir.path, 'test_output.docx');

      const table = TableModel(
        colCount: 2,
        rowCount: 2,
        rows: [
          TableRow(
            isHeader: true,
            cells: [
              TableCell(text: 'Tiêu đề cột 1', rowIndex: 0, colIndex: 0, isHeader: true),
              TableCell(text: 'Tiêu đề cột 2', rowIndex: 0, colIndex: 1, isHeader: true),
            ],
          ),
          TableRow(
            isHeader: false,
            cells: [
              TableCell(text: 'Dữ liệu A', rowIndex: 1, colIndex: 0),
              TableCell(text: 'Dữ liệu B', rowIndex: 1, colIndex: 1),
            ],
          ),
        ],
      );

      const doc = LayoutDocument(
        title: 'Báo cáo kiểm thử',
        pages: [
          DocumentPage(
            pageNumber: 1,
            blocks: [
              ParagraphBlock(
                text: 'CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM',
                pageNumber: 1,
                box: OcrBoundingBox(left: 50, top: 50, width: 400, height: 20),
                isHeading: true,
                headingLevel: 1,
                alignment: 'center',
              ),
              ParagraphBlock(
                text: 'Độc lập - Tự do - Hạnh phúc',
                pageNumber: 1,
                box: OcrBoundingBox(left: 50, top: 80, width: 400, height: 20),
                alignment: 'center',
              ),
              TableBlock(
                table: table,
                pageNumber: 1,
                box: OcrBoundingBox(left: 50, top: 120, width: 400, height: 100),
              ),
            ],
          ),
        ],
      );

      final file = await generator.generate(document: doc, outputPath: outPath);

      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(100));

      // Validate ZIP archive contents
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final fileNames = archive.files.map((f) => f.name).toList();
      expect(fileNames, contains('[Content_Types].xml'));
      expect(fileNames, contains('_rels/.rels'));
      expect(fileNames, contains('word/document.xml'));
      expect(fileNames, contains('word/styles.xml'));

      // Validate word/document.xml content
      final docFile = archive.findFile('word/document.xml')!;
      final docXml = utf8.decode(docFile.content as List<int>);

      expect(docXml, contains('CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM'));
      expect(docXml, contains('Độc lập - Tự do - Hạnh phúc'));
      expect(docXml, contains('<w:tbl>'));
      expect(docXml, contains('Tiêu đề cột 1'));
      expect(docXml, contains('Dữ liệu A'));
    });
  });
}
