import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/features/pdf_converter/domain/models/layout_models.dart';
import 'package:nguyendu_tool/features/pdf_converter/domain/models/ocr_models.dart';
import 'package:nguyendu_tool/features/pdf_converter/domain/models/table_models.dart';
import 'package:nguyendu_tool/features/pdf_converter/infrastructure/xlsx_generator.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late XlsxGenerator generator;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('xlsx_test_');
    generator = XlsxGenerator();
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('XlsxGenerator Tests', () {
    test('Produces valid OpenXML .xlsx with numbers, headers, and Vietnamese text', () async {
      final outPath = p.join(tempDir.path, 'test_spreadsheet.xlsx');

      const table = TableModel(
        colCount: 3,
        rowCount: 3,
        caption: 'Bảng Điểm',
        rows: [
          TableRow(
            isHeader: true,
            cells: [
              TableCell(text: 'Mã số', rowIndex: 0, colIndex: 0, isHeader: true),
              TableCell(text: 'Họ và tên', rowIndex: 0, colIndex: 1, isHeader: true),
              TableCell(text: 'Điểm trung bình', rowIndex: 0, colIndex: 2, isHeader: true),
            ],
          ),
          TableRow(
            isHeader: false,
            cells: [
              TableCell(text: 'HS001', rowIndex: 1, colIndex: 0),
              TableCell(text: 'Nguyễn Văn Nam', rowIndex: 1, colIndex: 1),
              TableCell(text: '9.5', rowIndex: 1, colIndex: 2),
            ],
          ),
          TableRow(
            isHeader: false,
            cells: [
              TableCell(text: 'HS002', rowIndex: 2, colIndex: 0),
              TableCell(text: 'Trần Thị Hà', rowIndex: 2, colIndex: 1),
              TableCell(text: '8.7', rowIndex: 2, colIndex: 2),
            ],
          ),
        ],
      );

      const doc = LayoutDocument(
        title: 'Bảng điểm tổng kết',
        pages: [
          DocumentPage(
            pageNumber: 1,
            blocks: [
              TableBlock(
                table: table,
                pageNumber: 1,
                box: OcrBoundingBox(left: 40, top: 40, width: 500, height: 200),
              ),
            ],
          ),
        ],
      );

      final file = await generator.generate(document: doc, outputPath: outPath);

      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(100));

      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final fileNames = archive.files.map((f) => f.name).toList();
      expect(fileNames, contains('[Content_Types].xml'));
      expect(fileNames, contains('xl/workbook.xml'));
      expect(fileNames, contains('xl/styles.xml'));
      expect(fileNames, contains('xl/worksheets/sheet1.xml'));

      final sheetFile = archive.findFile('xl/worksheets/sheet1.xml')!;
      final sheetXml = utf8.decode(sheetFile.content as List<int>);

      expect(sheetXml, contains('Mã số'));
      expect(sheetXml, contains('Nguyễn Văn Nam'));
      expect(sheetXml, contains('<v>9.5</v>'));
      expect(sheetXml, contains('<v>8.7</v>'));
    });
  });
}
