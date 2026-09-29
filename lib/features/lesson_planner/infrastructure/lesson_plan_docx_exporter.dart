import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import '../../../core/logging/app_logger.dart';

/// Exports generated Lesson Plans to standard Microsoft Word (.docx) files conforming to
/// Vietnamese government administrative format (Decree 30/2020/NĐ-CP & Dispatch 5512).
class LessonPlanDocxExporter {
  /// Generates a .docx file from lesson plan text content.
  static Future<File> export({
    required String title,
    required String subject,
    required String grade,
    required String content,
    required String outputPath,
  }) async {
    final archive = Archive();

    // 1. [Content_Types].xml
    final contentTypesXml = _generateContentTypesXml();
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesXml.length, utf8.encode(contentTypesXml)));

    // 2. _rels/.rels
    final globalRelsXml = _generateGlobalRelsXml();
    archive.addFile(ArchiveFile('_rels/.rels', globalRelsXml.length, utf8.encode(globalRelsXml)));

    // 3. word/_rels/document.xml.rels
    final docRelsXml = _generateDocumentRelsXml();
    archive.addFile(ArchiveFile('word/_rels/document.xml.rels', docRelsXml.length, utf8.encode(docRelsXml)));

    // 4. word/styles.xml
    final stylesXml = _generateStylesXml();
    archive.addFile(ArchiveFile('word/styles.xml', stylesXml.length, utf8.encode(stylesXml)));

    // 5. word/document.xml
    final documentXml = _generateDocumentXml(title: title, subject: subject, grade: grade, content: content);
    archive.addFile(ArchiveFile('word/document.xml', documentXml.length, utf8.encode(documentXml)));

    // Compress to zip archive
    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);
    if (zipBytes == null) {
      throw const FormatException('Không thể nén tệp DOCX.');
    }

    final file = File(outputPath);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    await file.writeAsBytes(zipBytes);
    AppLogger.info('Exported MOET 5512 Lesson Plan to Word: $outputPath');
    return file;
  }

  static String _generateContentTypesXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\n'
        '  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\n'
        '  <Default Extension="xml" ContentType="application/xml"/>\n'
        '  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>\n'
        '  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>\n'
        '</Types>';
  }

  static String _generateGlobalRelsXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>\n'
        '</Relationships>';
  }

  static String _generateDocumentRelsXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>\n'
        '</Relationships>';
  }

  static String _generateStylesXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">\n'
        '  <w:docDefaults>\n'
        '    <w:rPrDefault>\n'
        '      <w:rPr>\n'
        '        <w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:cs="Times New Roman"/>\n'
        '        <w:sz w:val="26"/>\n' // 13pt
        '        <w:lang w:val="vi-VN"/>\n'
        '      </w:rPr>\n'
        '    </w:rPrDefault>\n'
        '  </w:docDefaults>\n'
        '</w:styles>';
  }

  static String _generateDocumentXml({
    required String title,
    required String subject,
    required String grade,
    required String content,
  }) {
    final buffer = StringBuffer();
    buffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    buffer.write('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">\n');
    buffer.write('  <w:body>\n');

    // Page Margins: Top 2cm (1134 dxa), Bottom 2cm (1134 dxa), Left 3cm (1701 dxa), Right 1.5cm (850 dxa)
    // Decreed standard for Vietnamese educational and administrative documents
    const sectPr = '<w:sectPr>\n'
        '  <w:pgMar w:top="1134" w:right="850" w:bottom="1134" w:left="1701" w:header="708" w:footer="708" w:gutter="0"/>\n'
        '</w:sectPr>\n';

    // Header 1: KẾ HOẠCH BÀI DẠY (GIÁO ÁN)
    buffer.write(_makeParagraph(
      'KẾ HOẠCH BÀI DẠY (CÔNG VĂN 5512/BGDĐT-GDTrH)',
      isBold: true,
      fontSize: 28, // 14pt
      align: 'center',
    ));

    // Header 2: Tên bài dạy
    buffer.write(_makeParagraph(
      'TÊN BÀI DẠY: ${title.toUpperCase()}',
      isBold: true,
      fontSize: 28, // 14pt
      align: 'center',
    ));

    // Header 3: Môn & Lớp
    buffer.write(_makeParagraph(
      'Môn học: $subject - $grade',
      isBold: true,
      fontSize: 26, // 13pt
      align: 'center',
    ));

    buffer.write(_makeParagraph('', fontSize: 16)); // spacing

    // Process line by line from markdown content
    final lines = content.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        buffer.write(_makeParagraph('', fontSize: 16));
        continue;
      }

      // Main Section Headings (I., II., III., IV.)
      final isMajorHeader = RegExp(r'^(I|II|III|IV|V)\.').hasMatch(trimmed) || trimmed.startsWith('# ');
      final isSubHeader = RegExp(r'^(\d+|Hoạt động \d+)\.').hasMatch(trimmed) || trimmed.startsWith('## ');
      final isSubSubHeader = RegExp(r'^[a-d]\.').hasMatch(trimmed) || trimmed.startsWith('### ');

      if (isMajorHeader) {
        final cleanText = trimmed.replaceFirst(RegExp(r'^#\s*'), '');
        buffer.write(_makeParagraph(cleanText, isBold: true, fontSize: 26, spaceBefore: 200, spaceAfter: 100));
      } else if (isSubHeader) {
        final cleanText = trimmed.replaceFirst(RegExp(r'^##\s*'), '');
        buffer.write(_makeParagraph(cleanText, isBold: true, isItalic: false, fontSize: 26, spaceBefore: 120, spaceAfter: 60));
      } else if (isSubSubHeader) {
        final cleanText = trimmed.replaceFirst(RegExp(r'^###\s*'), '');
        buffer.write(_makeParagraph(cleanText, isBold: true, isItalic: true, fontSize: 26, spaceBefore: 80, spaceAfter: 40));
      } else {
        // Standard body paragraph
        buffer.write(_makeParagraph(trimmed, fontSize: 26, spaceAfter: 60));
      }
    }

    buffer.write(sectPr);
    buffer.write('  </w:body>\n');
    buffer.write('</w:document>');
    return buffer.toString();
  }

  static String _makeParagraph(
    String text, {
    bool isBold = false,
    bool isItalic = false,
    int fontSize = 26,
    String align = 'both', // justified
    int spaceBefore = 0,
    int spaceAfter = 80,
  }) {
    final cleanText = _escapeXml(text);
    return '    <w:p>\n'
        '      <w:pPr>\n'
        '        <w:jc w:val="$align"/>\n'
        '        <w:spacing w:before="$spaceBefore" w:after="$spaceAfter" w:line="276" w:lineRule="auto"/>\n'
        '      </w:pPr>\n'
        '      <w:r>\n'
        '        <w:rPr>\n'
        '          <w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:cs="Times New Roman"/>\n'
        '          ${isBold ? '<w:b/>' : ''}\n'
        '          ${isItalic ? '<w:i/>' : ''}\n'
        '          <w:sz w:val="$fontSize"/>\n'
        '          <w:szCs w:val="$fontSize"/>\n'
        '        </w:rPr>\n'
        '        <w:t xml:space="preserve">$cleanText</w:t>\n'
        '      </w:r>\n'
        '    </w:p>\n';
  }

  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
