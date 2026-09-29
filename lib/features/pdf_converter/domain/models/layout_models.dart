import 'ocr_models.dart';
import 'table_models.dart';

/// Block types identified during document layout analysis.
enum BlockType {
  paragraph,
  heading,
  table,
  image,
  separator,
}

/// Abstract representation of any block element in a document page.
abstract class DocumentBlock {
  final BlockType type;
  final int pageNumber;
  final OcrBoundingBox box;

  const DocumentBlock({
    required this.type,
    required this.pageNumber,
    required this.box,
  });

  Map<String, dynamic> toJson();
}

/// Text paragraph block with formatting and typography hints.
class ParagraphBlock extends DocumentBlock {
  final String text;
  final bool isHeading;
  final int headingLevel; // 1, 2, 3
  final String alignment; // 'left', 'center', 'right', 'justify'
  final bool isBold;
  final bool isItalic;
  final double fontSize;

  const ParagraphBlock({
    required this.text,
    required super.pageNumber,
    required super.box,
    this.isHeading = false,
    this.headingLevel = 0,
    this.alignment = 'left',
    this.isBold = false,
    this.isItalic = false,
    this.fontSize = 12.0,
  }) : super(type: isHeading ? BlockType.heading : BlockType.paragraph);

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'pageNumber': pageNumber,
    'box': box.toJson(),
    'text': text,
    'isHeading': isHeading,
    'headingLevel': headingLevel,
    'alignment': alignment,
    'isBold': isBold,
    'isItalic': isItalic,
    'fontSize': fontSize,
  };
}

/// Table block in document layout.
class TableBlock extends DocumentBlock {
  final TableModel table;

  const TableBlock({
    required this.table,
    required super.pageNumber,
    required super.box,
  }) : super(type: BlockType.table);

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'pageNumber': pageNumber,
    'box': box.toJson(),
    'table': table.toJson(),
  };
}

/// Image block in document layout.
class ImageBlock extends DocumentBlock {
  final String? imagePath;
  final int imageIndex;

  const ImageBlock({
    this.imagePath,
    required this.imageIndex,
    required super.pageNumber,
    required super.box,
  }) : super(type: BlockType.image);

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'pageNumber': pageNumber,
    'box': box.toJson(),
    'imagePath': imagePath,
    'imageIndex': imageIndex,
  };
}

/// Layout analysis of a single document page.
class DocumentPage {
  final int pageNumber;
  final double width;
  final double height;
  final List<DocumentBlock> blocks;

  const DocumentPage({
    required this.pageNumber,
    this.width = 595.0, // Default A4 width in pt
    this.height = 842.0, // Default A4 height in pt
    required this.blocks,
  });

  List<ParagraphBlock> get paragraphs =>
      blocks.whereType<ParagraphBlock>().toList();

  List<TableBlock> get tables =>
      blocks.whereType<TableBlock>().toList();

  List<ImageBlock> get images =>
      blocks.whereType<ImageBlock>().toList();
}

/// Complete reconstructed layout of the document ready for OpenXML export.
class LayoutDocument {
  final String title;
  final List<DocumentPage> pages;

  const LayoutDocument({
    required this.title,
    required this.pages,
  });

  int get totalPages => pages.length;

  List<TableModel> getAllTables() {
    final list = <TableModel>[];
    for (final page in pages) {
      for (final tableBlock in page.tables) {
        list.add(tableBlock.table);
      }
    }
    return list;
  }
}
