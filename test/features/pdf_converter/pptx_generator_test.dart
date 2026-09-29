import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/features/pdf_converter/domain/models/conversion_options.dart';
import 'package:nguyendu_tool/features/pdf_converter/domain/models/layout_models.dart';
import 'package:nguyendu_tool/features/pdf_converter/domain/models/ocr_models.dart';
import 'package:nguyendu_tool/features/pdf_converter/domain/models/table_models.dart';
import 'package:nguyendu_tool/features/pdf_converter/infrastructure/pptx_generator.dart';
import 'package:nguyendu_tool/features/scanner/domain/models/scan_options.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late PptxGenerator generator;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pptx_test_');
    generator = PptxGenerator();
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('PptxGenerator & PresentationML Tests', () {
    test('Produces valid OpenXML .pptx presentation archive with educational slides', () async {
      final outPath = p.join(tempDir.path, 'bai_giang_dien_tu.pptx');

      const doc = LayoutDocument(
        title: 'Bài giảng Lịch Sử 12',
        pages: [
          DocumentPage(
            pageNumber: 1,
            blocks: [
              ParagraphBlock(
                text: 'BÀI 1: VIỆT NAM TỪ NĂM 1919 ĐẾN NĂM 1930',
                pageNumber: 1,
                box: OcrBoundingBox(left: 50, top: 40, width: 600, height: 40),
                isHeading: true,
                headingLevel: 1,
              ),
              ParagraphBlock(
                text: '1. Chính sách khai thác thuộc địa lần thứ hai của thực dân Pháp',
                pageNumber: 1,
                box: OcrBoundingBox(left: 50, top: 100, width: 600, height: 30),
                isHeading: true,
                headingLevel: 2,
              ),
              ParagraphBlock(
                text: 'Sau Chiến tranh thế giới thứ nhất, thực dân Pháp đẩy mạnh khai thác thuộc địa để bù đắp thiệt hại chiến tranh.',
                pageNumber: 1,
                box: OcrBoundingBox(left: 50, top: 150, width: 600, height: 60),
              ),
              TableBlock(
                table: TableModel(
                  rowCount: 2,
                  colCount: 2,
                  rows: [
                    TableRow(
                      isHeader: true,
                      cells: [
                        TableCell(text: 'Lĩnh vực', rowIndex: 0, colIndex: 0, isHeader: true),
                        TableCell(text: 'Chính sách khai thác', rowIndex: 0, colIndex: 1, isHeader: true),
                      ],
                    ),
                    TableRow(
                      isHeader: false,
                      cells: [
                        TableCell(text: 'Nông nghiệp', rowIndex: 1, colIndex: 0),
                        TableCell(text: 'Đẩy mạnh cướp đoạt ruộng đất lập đồn điền cao su', rowIndex: 1, colIndex: 1),
                      ],
                    ),
                  ],
                ),
                pageNumber: 1,
                box: OcrBoundingBox(left: 50, top: 230, width: 600, height: 100),
              ),
            ],
          ),
          DocumentPage(
            pageNumber: 2,
            blocks: [
              ParagraphBlock(
                text: '2. Những chuyển biến về kinh tế và giai cấp xã hội',
                pageNumber: 2,
                box: OcrBoundingBox(left: 50, top: 50, width: 600, height: 40),
                isHeading: true,
                headingLevel: 1,
              ),
              ParagraphBlock(
                text: 'Giai cấp công nhân phát triển nhanh chóng và trở thành lực lượng lãnh đạo cách mạng.',
                pageNumber: 2,
                box: OcrBoundingBox(left: 50, top: 110, width: 600, height: 50),
              ),
            ],
          ),
        ],
      );

      final file = await generator.generate(document: doc, outputPath: outPath);

      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(500));

      // Validate ZIP archive contents (ISO/IEC 29500 & ECMA-376 PresentationML)
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final fileNames = archive.files.map((f) => f.name).toSet();
      expect(fileNames, contains('[Content_Types].xml'));
      expect(fileNames, contains('_rels/.rels'));
      expect(fileNames, contains('ppt/presentation.xml'));
      expect(fileNames, contains('ppt/_rels/presentation.xml.rels'));
      expect(fileNames, contains('ppt/theme/theme1.xml'));
      expect(fileNames, contains('ppt/slideMasters/slideMaster1.xml'));
      expect(fileNames, contains('ppt/slideLayouts/slideLayout1.xml'));
      expect(fileNames, contains('ppt/slides/slide1.xml'));
      expect(fileNames, contains('ppt/slides/_rels/slide1.xml.rels'));
      expect(fileNames, contains('ppt/slides/slide2.xml'));
      expect(fileNames, contains('ppt/slides/_rels/slide2.xml.rels'));

      // Validate slide 1 content
      final slide1File = archive.findFile('ppt/slides/slide1.xml')!;
      final slide1Xml = utf8.decode(slide1File.content as List<int>);

      expect(slide1Xml, contains('BÀI 1: VIỆT NAM TỪ NĂM 1919 ĐẾN NĂM 1930'));
      expect(slide1Xml, contains('Chính sách khai thác thuộc địa'));
      expect(slide1Xml, contains('Nông nghiệp'));

      // Validate slide 2 content
      final slide2File = archive.findFile('ppt/slides/slide2.xml')!;
      final slide2Xml = utf8.decode(slide2File.content as List<int>);

      expect(slide2Xml, contains('Những chuyển biến về kinh tế'));
      expect(slide2Xml, contains('Giai cấp công nhân'));
    });

    test('OutputFormat includes pptx and all with teacher labels', () {
      expect(OutputFormat.pptx.name, equals('pptx'));
      expect(OutputFormat.all.name, equals('all'));
      expect(OutputFormat.pptx.label, contains('PowerPoint'));
      expect(OutputFormat.docx.label, contains('Giáo án'));
      expect(OutputFormat.xlsx.label, contains('Sổ sách'));
    });

    test('ScanOutputFormat includes pptx for educational presentations', () {
      expect(ScanOutputFormat.pptx.name, equals('pptx'));
      expect(ScanOutputFormat.pptx.extension, equals('.pptx'));
      expect(ScanOutputFormat.pptx.label, contains('PowerPoint'));
    });
  });
}
