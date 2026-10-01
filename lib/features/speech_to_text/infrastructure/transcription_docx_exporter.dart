import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import '../domain/models/transcription_item.dart';

/// Professional OpenXML (.docx) exporter for Speech-to-Text transcriptions.
/// Produces standardized educational documents formatted in Times New Roman,
/// ready for formal school documentation, lesson plan archives, or meeting minutes.
class TranscriptionDocxExporter {
  static Future<File> exportTranscription({
    required TranscriptionResult result,
    required String outputPath,
    String? schoolName,
    String? title,
  }) async {
    final bodyBuffer = StringBuffer();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final formattedDate = dateFormat.format(result.createdAt);

    // 1. Header (School & Administrative format)
    bodyBuffer.write(_makeParagraph(
      (schoolName != null && schoolName.trim().isNotEmpty) ? schoolName.toUpperCase() : 'BỘ GIÁO DỤC VÀ ĐÀO TẠO',
      isBold: true,
      fontSize: 22,
      align: 'left',
      spaceAfter: 40,
    ));
    bodyBuffer.write(_makeParagraph(
      'HỆ THỐNG TRỢ LÝ GIÁO VIÊN - NGUYENDU TOOL',
      isItalic: true,
      fontSize: 20,
      align: 'left',
      spaceAfter: 120,
    ));

    // 2. Main Title
    final docTitle = (title != null && title.trim().isNotEmpty)
        ? title.trim()
        : 'VĂN BẢN GỠ BĂNG BÀI GIẢNG / GHI ÂM HỘI NGHỊ';
    bodyBuffer.write(_makeParagraph(
      docTitle.toUpperCase(),
      isBold: true,
      fontSize: 28,
      align: 'center',
      spaceBefore: 120,
      spaceAfter: 60,
    ));

    bodyBuffer.write(_makeParagraph(
      'Tệp nguồn: ${result.sourceFileName} | Thời gian gỡ băng: $formattedDate',
      isItalic: true,
      fontSize: 22,
      align: 'center',
      spaceAfter: 160,
    ));

    bodyBuffer.write(_makeDivider());

    // 3. Metadata Table
    final metaRows = [
      ['Tệp phương tiện nguồn:', result.sourceFileName],
      ['Dung lượng tệp:', result.formattedFileSize],
      ['Thời lượng ước tính:', result.formattedDuration],
      ['Động cơ nhận dạng AI:', 'Google Gemini (${result.modelUsed})'],
      ['Thời điểm xử lý:', formattedDate],
    ];
    bodyBuffer.write(_makeTable(['Thông tin tệp', 'Chi tiết'], metaRows, colWidths: [3200, 5800]));
    bodyBuffer.write(_makeParagraph('', spaceAfter: 180));

    // 4. Section: Summary (if present)
    if (result.summary != null && result.summary!.trim().isNotEmpty) {
      bodyBuffer.write(_makeParagraph(
        'I. TÓM TẮT & TRỌNG TÂM SƯ PHẠM',
        isBold: true,
        fontSize: 24,
        spaceBefore: 180,
        spaceAfter: 100,
      ));

      final summaryLines = result.summary!.split('\n');
      for (final line in summaryLines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('###')) continue;

        if (trimmed.startsWith('- ') || trimmed.startsWith('* ') || trimmed.startsWith('+ ')) {
          bodyBuffer.write(_makeParagraph('• ${trimmed.substring(2)}', indentLeft: 360, spaceAfter: 50));
        } else {
          bodyBuffer.write(_makeParagraph(trimmed, spaceAfter: 70));
        }
      }

      bodyBuffer.write(_makeDivider());
    }

    // 5. Section: Full Dialogue / Transcript
    bodyBuffer.write(_makeParagraph(
      result.summary != null ? 'II. NỘI DUNG GỠ BĂNG CHI TIẾT' : 'NỘI DUNG GỠ BĂNG CHI TIẾT',
      isBold: true,
      fontSize: 24,
      spaceBefore: 180,
      spaceAfter: 100,
    ));

    if (result.segments.isNotEmpty) {
      for (final seg in result.segments) {
        final header = '${seg.timestamp} [${seg.speaker}]:';
        bodyBuffer.write(_makeParagraph(header, isBold: true, fontSize: 22, spaceBefore: 80, spaceAfter: 30));
        bodyBuffer.write(_makeParagraph(seg.text, fontSize: 24, indentLeft: 360, spaceAfter: 80));
      }
    } else {
      // Fallback: Line-by-line from fullTranscript
      final transcriptLines = result.fullTranscript.split('\n');
      for (final line in transcriptLines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        bodyBuffer.write(_makeParagraph(trimmed, fontSize: 24, spaceAfter: 70));
      }
    }

    // 6. Sign-off block
    bodyBuffer.write(_makeParagraph('', spaceBefore: 300, spaceAfter: 60));
    bodyBuffer.write(_makeParagraph(
      'Người lập văn bản',
      isBold: true,
      fontSize: 22,
      align: 'right',
      spaceAfter: 400,
    ));
    bodyBuffer.write(_makeParagraph(
      '(Ký và ghi rõ họ tên)',
      isItalic: true,
      fontSize: 20,
      align: 'right',
      spaceAfter: 60,
    ));

    return _packageDocx(bodyBuffer.toString(), outputPath);
  }

  /// Packages OpenXML (.docx) archive.
  static Future<File> _packageDocx(String bodyContentXml, String outputPath) async {
    final archive = Archive();

    // [Content_Types].xml
    const contentTypesXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\n'
        '  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\n'
        '  <Default Extension="xml" ContentType="application/xml"/>\n'
        '  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>\n'
        '  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>\n'
        '</Types>';
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesXml.length, utf8.encode(contentTypesXml)));

    // _rels/.rels
    const rootRelsXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>\n'
        '</Relationships>';
    archive.addFile(ArchiveFile('_rels/.rels', rootRelsXml.length, utf8.encode(rootRelsXml)));

    // word/_rels/document.xml.rels
    const docRelsXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>\n'
        '</Relationships>';
    archive.addFile(ArchiveFile('word/_rels/document.xml.rels', docRelsXml.length, utf8.encode(docRelsXml)));

    // word/styles.xml
    const stylesXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">\n'
        '  <w:docDefaults>\n'
        '    <w:rPrDefault>\n'
        '      <w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:cs="Times New Roman"/>\n'
        '      <w:sz w:val="26"/>\n'
        '      <w:lang w:val="vi-VN"/>\n'
        '    </w:rPrDefault>\n'
        '  </w:docDefaults>\n'
        '</w:styles>';
    archive.addFile(ArchiveFile('word/styles.xml', stylesXml.length, utf8.encode(stylesXml)));

    // word/document.xml
    final docBuffer = StringBuffer();
    docBuffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    docBuffer.write('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">\n');
    docBuffer.write('  <w:body>\n');
    docBuffer.write(bodyContentXml);
    // Standard A4 Margins: Top 2cm, Bottom 2cm, Left 3cm, Right 1.5cm
    docBuffer.write('    <w:sectPr>\n');
    docBuffer.write('      <w:pgMar w:top="1134" w:right="850" w:bottom="1134" w:left="1701" w:header="708" w:footer="708" w:gutter="0"/>\n');
    docBuffer.write('    </w:sectPr>\n');
    docBuffer.write('  </w:body>\n');
    docBuffer.write('</w:document>');

    final docBytes = utf8.encode(docBuffer.toString());
    archive.addFile(ArchiveFile('word/document.xml', docBytes.length, docBytes));

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw const FormatException('Không thể tạo file OpenXML (.docx).');
    }

    final file = File(outputPath);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    await file.writeAsBytes(zipBytes);
    return file;
  }

  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _makeParagraph(
    String text, {
    bool isBold = false,
    bool isItalic = false,
    int fontSize = 26, // 13pt
    String align = 'left',
    int spaceBefore = 0,
    int spaceAfter = 100,
    int indentLeft = 0,
  }) {
    final sb = StringBuffer();
    sb.write('    <w:p>\n');
    sb.write('      <w:pPr>\n');
    if (align != 'left') {
      sb.write('        <w:jc w:val="$align"/>\n');
    }
    if (spaceBefore > 0 || spaceAfter > 0) {
      sb.write('        <w:spacing w:before="$spaceBefore" w:after="$spaceAfter"/>\n');
    }
    if (indentLeft > 0) {
      sb.write('        <w:ind w:left="$indentLeft"/>\n');
    }
    sb.write('      </w:pPr>\n');

    sb.write('      <w:r>\n');
    sb.write('        <w:rPr>\n');
    if (isBold) sb.write('          <w:b/>\n');
    if (isItalic) sb.write('          <w:i/>\n');
    sb.write('          <w:sz w:val="$fontSize"/>\n');
    sb.write('        </w:rPr>\n');
    sb.write('        <w:t xml:space="preserve">${_escapeXml(text)}</w:t>\n');
    sb.write('      </w:r>\n');
    sb.write('    </w:p>\n');
    return sb.toString();
  }

  static String _makeDivider() {
    return _makeParagraph('____________________________________________________', align: 'center', spaceAfter: 140);
  }

  static String _makeTable(List<String> headers, List<List<String>> rows, {List<int>? colWidths}) {
    final sb = StringBuffer();
    sb.write('    <w:tbl>\n');
    sb.write('      <w:tblPr>\n');
    sb.write('        <w:tblW w:w="0" w:type="auto"/>\n');
    sb.write('        <w:tblBorders>\n');
    sb.write('          <w:top w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>\n');
    sb.write('          <w:left w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>\n');
    sb.write('          <w:bottom w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>\n');
    sb.write('          <w:right w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>\n');
    sb.write('          <w:insideH w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>\n');
    sb.write('          <w:insideV w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>\n');
    sb.write('        </w:tblBorders>\n');
    sb.write('      </w:tblPr>\n');

    // Header row
    sb.write('      <w:tr>\n');
    for (int i = 0; i < headers.length; i++) {
      final width = (colWidths != null && i < colWidths.length) ? colWidths[i] : 2000;
      sb.write('        <w:tc>\n');
      sb.write('          <w:tcPr>\n');
      sb.write('            <w:tcW w:w="$width" w:type="dxa"/>\n');
      sb.write('            <w:shd w:val="clear" w:color="auto" w:fill="EFEFEF"/>\n');
      sb.write('          </w:tcPr>\n');
      sb.write(_makeParagraph(headers[i], isBold: true, fontSize: 22, align: 'center', spaceAfter: 60));
      sb.write('        </w:tc>\n');
    }
    sb.write('      </w:tr>\n');

    // Data rows
    for (final row in rows) {
      sb.write('      <w:tr>\n');
      for (int i = 0; i < row.length; i++) {
        final width = (colWidths != null && i < colWidths.length) ? colWidths[i] : 2000;
        sb.write('        <w:tc>\n');
        sb.write('          <w:tcPr>\n');
        sb.write('            <w:tcW w:w="$width" w:type="dxa"/>\n');
        sb.write('          </w:tcPr>\n');
        sb.write(_makeParagraph(row[i], fontSize: 22, spaceAfter: 40));
        sb.write('        </w:tc>\n');
      }
      sb.write('      </w:tr>\n');
    }

    sb.write('    </w:tbl>\n');
    return sb.toString();
  }
}
