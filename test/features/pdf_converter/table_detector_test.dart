import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/features/pdf_converter/domain/models/ocr_models.dart';
import 'package:nguyendu_tool/features/pdf_converter/infrastructure/table_detector.dart';

void main() {
  group('TableDetector Tests', () {
    test('Detects pipe-delimited tables with headers', () {
      final blocks = [
        const OcrTextBlock(
          text: '| STT | Họ và tên | Điểm số |\n| 1 | Nguyễn Văn A | 9.5 |\n| 2 | Trần Thị B | 8.8 |',
          box: OcrBoundingBox(left: 50, top: 100, width: 400, height: 100),
        ),
      ];

      final tables = TableDetector.detectTables(blocks);
      expect(tables.isNotEmpty, isTrue);

      final table = tables.first;
      expect(table.rowCount, 3);
      expect(table.colCount, 3);
      expect(table.rows[0].isHeader, isTrue);
      expect(table.rows[0].cells[1].text, 'Họ và tên');
      expect(table.rows[1].cells[1].text, 'Nguyễn Văn A');
      expect(table.rows[2].cells[2].text, '8.8');
    });

    test('Detects spatial column aligned blocks as tables', () {
      final blocks = [
        // Header row
        const OcrTextBlock(text: 'Mã số', box: OcrBoundingBox(left: 50, top: 100, width: 80, height: 20)),
        const OcrTextBlock(text: 'Tên giáo viên', box: OcrBoundingBox(left: 180, top: 100, width: 150, height: 20)),
        const OcrTextBlock(text: 'Tổ bộ môn', box: OcrBoundingBox(left: 380, top: 100, width: 100, height: 20)),

        // Data row 1
        const OcrTextBlock(text: 'GV01', box: OcrBoundingBox(left: 50, top: 130, width: 80, height: 20)),
        const OcrTextBlock(text: 'Lê Văn Cường', box: OcrBoundingBox(left: 180, top: 130, width: 150, height: 20)),
        const OcrTextBlock(text: 'Toán học', box: OcrBoundingBox(left: 380, top: 130, width: 100, height: 20)),

        // Data row 2
        const OcrTextBlock(text: 'GV02', box: OcrBoundingBox(left: 50, top: 160, width: 80, height: 20)),
        const OcrTextBlock(text: 'Nguyễn Thị Dung', box: OcrBoundingBox(left: 180, top: 160, width: 150, height: 20)),
        const OcrTextBlock(text: 'Ngữ văn', box: OcrBoundingBox(left: 380, top: 160, width: 100, height: 20)),
      ];

      final tables = TableDetector.detectTables(blocks);
      expect(tables.isNotEmpty, isTrue);

      final table = tables.first;
      expect(table.rowCount, 3);
      expect(table.colCount, 3);
      expect(table.rows[0].isHeader, isTrue);
      expect(table.rows[0].cells[0].text, 'Mã số');
      expect(table.rows[1].cells[1].text, 'Lê Văn Cường');
    });
  });
}
