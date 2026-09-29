import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import '../domain/models/layout_models.dart';
import '../domain/models/table_models.dart';

/// Generates standard ECMA-376 / ISO 29500 Microsoft Word (.docx) files without requiring MS Office.
class DocxGenerator {
  /// Generates a valid .docx file from layout document and writes to target path.
  Future<File> generate({
    required LayoutDocument document,
    required String outputPath,
  }) async {
    final archive = Archive();

    // 1. [Content_Types].xml
    final contentTypesXml = _generateContentTypesXml();
    archive.addFile(
      ArchiveFile('[Content_Types].xml', contentTypesXml.length, utf8.encode(contentTypesXml)),
    );

    // 2. _rels/.rels
    final globalRelsXml = _generateGlobalRelsXml();
    archive.addFile(
      ArchiveFile('_rels/.rels', globalRelsXml.length, utf8.encode(globalRelsXml)),
    );

    // 3. word/_rels/document.xml.rels
    final docRelsXml = _generateDocumentRelsXml();
    archive.addFile(
      ArchiveFile('word/_rels/document.xml.rels', docRelsXml.length, utf8.encode(docRelsXml)),
    );

    // 4. word/styles.xml
    final stylesXml = _generateStylesXml();
    archive.addFile(
      ArchiveFile('word/styles.xml', stylesXml.length, utf8.encode(stylesXml)),
    );

    // 5. word/document.xml
    final documentXml = _generateDocumentXml(document);
    archive.addFile(
      ArchiveFile('word/document.xml', documentXml.length, utf8.encode(documentXml)),
    );

    // Compress to zip archive
    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);
    if (zipBytes == null) {
      throw const FormatException('Không thể mã hóa file DOCX.');
    }

    final file = File(outputPath);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    await file.writeAsBytes(zipBytes);
    return file;
  }

  String _generateContentTypesXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\n'
        '  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\n'
        '  <Default Extension="xml" ContentType="application/xml"/>\n'
        '  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>\n'
        '  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>\n'
        '</Types>';
  }

  String _generateGlobalRelsXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>\n'
        '</Relationships>';
  }

  String _generateDocumentRelsXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>\n'
        '</Relationships>';
  }

  String _generateStylesXml() {
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

  String _generateDocumentXml(LayoutDocument doc) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    buffer.writeln(
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">',
    );
    buffer.writeln('  <w:body>');

    for (int pIdx = 0; pIdx < doc.pages.length; pIdx++) {
      final page = doc.pages[pIdx];

      for (final block in page.blocks) {
        if (block is ParagraphBlock) {
          buffer.write(_renderParagraph(block));
        } else if (block is TableBlock) {
          buffer.write(_renderTable(block.table));
        }
      }

      // Add page break between pages except for the last page
      if (pIdx < doc.pages.length - 1) {
        buffer.writeln('    <w:p><w:r><w:br w:type="page"/></w:r></w:p>');
      }
    }

    // Default Section Properties (A4 Portrait, 1 inch margins)
    buffer.writeln('    <w:sectPr>');
    buffer.writeln('      <w:pgSz w:w="11906" w:h="16838"/>'); // A4 in dxa
    buffer.writeln('      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>');
    buffer.writeln('    </w:sectPr>');
    buffer.writeln('  </w:body>');
    buffer.writeln('</w:document>');

    return buffer.toString();
  }

  String _renderParagraph(ParagraphBlock p) {
    final buffer = StringBuffer();
    buffer.writeln('    <w:p>');
    buffer.writeln('      <w:pPr>');

    // Alignment
    final jcVal = p.alignment == 'center'
        ? 'center'
        : p.alignment == 'right'
            ? 'right'
            : p.alignment == 'justify'
                ? 'both'
                : 'left';
    buffer.writeln('        <w:jc w:val="$jcVal"/>');

    // Spacing
    buffer.writeln('        <w:spacing w:before="60" w:after="60" w:line="276" w:lineRule="auto"/>');
    buffer.writeln('      </w:pPr>');

    // Run text
    buffer.writeln('      <w:r>');
    buffer.writeln('        <w:rPr>');
    if (p.isBold || p.isHeading) {
      buffer.writeln('          <w:b/>');
    }
    if (p.isItalic) {
      buffer.writeln('          <w:i/>');
    }
    final szVal = (p.isHeading ? (p.headingLevel == 1 ? 32 : 28) : 26);
    buffer.writeln('          <w:sz w:val="$szVal"/>');
    buffer.writeln('        </w:rPr>');

    final escapedText = _xmlEscape(p.text);
    buffer.writeln('        <w:t xml:space="preserve">$escapedText</w:t>');
    buffer.writeln('      </w:r>');
    buffer.writeln('    </w:p>');

    return buffer.toString();
  }

  String _renderTable(TableModel table) {
    final buffer = StringBuffer();
    buffer.writeln('    <w:tbl>');
    buffer.writeln('      <w:tblPr>');
    buffer.writeln('        <w:tblW w:w="5000" w:type="pct"/>');
    buffer.writeln('        <w:jc w:val="center"/>');
    buffer.writeln('        <w:tblBorders>');
    buffer.writeln('          <w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/>');
    buffer.writeln('          <w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/>');
    buffer.writeln('          <w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/>');
    buffer.writeln('          <w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/>');
    buffer.writeln('          <w:insideH w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>');
    buffer.writeln('          <w:insideV w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>');
    buffer.writeln('        </w:tblBorders>');
    buffer.writeln('      </w:tblPr>');

    for (final row in table.rows) {
      buffer.writeln('      <w:tr>');
      if (row.isHeader) {
        buffer.writeln('        <w:trPr><w:tblHeader/></w:trPr>');
      }

      for (final cell in row.cells) {
        buffer.writeln('        <w:tc>');
        buffer.writeln('          <w:tcPr>');
        if (cell.isHeader) {
          buffer.writeln('            <w:shd w:val="clear" w:color="auto" w:fill="F2F4F8"/>');
        }
        buffer.writeln('          </w:tcPr>');
        buffer.writeln('          <w:p>');
        buffer.writeln('            <w:pPr>');
        buffer.writeln('              <w:jc w:val="${cell.isHeader ? 'center' : 'left'}"/>');
        buffer.writeln('            </w:pPr>');
        buffer.writeln('            <w:r>');
        buffer.writeln('              <w:rPr>');
        if (cell.isHeader) buffer.writeln('                <w:b/>');
        buffer.writeln('                <w:sz w:val="24"/>'); // 12pt
        buffer.writeln('              </w:rPr>');
        buffer.writeln(
          '              <w:t xml:space="preserve">${_xmlEscape(cell.text)}</w:t>',
        );
        buffer.writeln('            </w:r>');
        buffer.writeln('          </w:p>');
        buffer.writeln('        </w:tc>');
      }
      buffer.writeln('      </w:tr>');
    }

    buffer.writeln('    </w:tbl>');
    return buffer.toString();
  }

  static String _xmlEscape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
