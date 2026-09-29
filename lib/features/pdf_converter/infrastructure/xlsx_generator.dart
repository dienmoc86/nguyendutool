import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import '../domain/models/layout_models.dart';
import '../domain/models/table_models.dart';

/// Generates standard ECMA-376 / ISO 29500 Microsoft Excel (.xlsx) files without requiring MS Excel.
class XlsxGenerator {
  /// Generates a valid .xlsx file from layout document / extracted tables.
  Future<File> generate({
    required LayoutDocument document,
    required String outputPath,
  }) async {
    final archive = Archive();

    final tables = document.getAllTables();

    // 1. [Content_Types].xml
    final contentTypesXml = _generateContentTypesXml(tables.length);
    archive.addFile(
      ArchiveFile('[Content_Types].xml', contentTypesXml.length, utf8.encode(contentTypesXml)),
    );

    // 2. _rels/.rels
    final globalRelsXml = _generateGlobalRelsXml();
    archive.addFile(
      ArchiveFile('_rels/.rels', globalRelsXml.length, utf8.encode(globalRelsXml)),
    );

    // 3. xl/_rels/workbook.xml.rels
    final workbookRelsXml = _generateWorkbookRelsXml(tables.length);
    archive.addFile(
      ArchiveFile('xl/_rels/workbook.xml.rels', workbookRelsXml.length, utf8.encode(workbookRelsXml)),
    );

    // 4. xl/workbook.xml
    final workbookXml = _generateWorkbookXml(tables);
    archive.addFile(
      ArchiveFile('xl/workbook.xml', workbookXml.length, utf8.encode(workbookXml)),
    );

    // 5. xl/styles.xml
    final stylesXml = _generateStylesXml();
    archive.addFile(
      ArchiveFile('xl/styles.xml', stylesXml.length, utf8.encode(stylesXml)),
    );

    // 6. xl/worksheets/sheetN.xml
    if (tables.isEmpty) {
      // If no table was explicitly detected, generate a sheet from the paragraph lines
      final fallbackSheetXml = _generateFallbackSheetXml(document);
      archive.addFile(
        ArchiveFile('xl/worksheets/sheet1.xml', fallbackSheetXml.length, utf8.encode(fallbackSheetXml)),
      );
    } else {
      for (int i = 0; i < tables.length; i++) {
        final sheetXml = _generateTableSheetXml(tables[i]);
        archive.addFile(
          ArchiveFile('xl/worksheets/sheet${i + 1}.xml', sheetXml.length, utf8.encode(sheetXml)),
        );
      }
    }

    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);
    if (zipBytes == null) {
      throw const FormatException('Không thể mã hóa file XLSX.');
    }

    final file = File(outputPath);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    await file.writeAsBytes(zipBytes);
    return file;
  }

  String _generateContentTypesXml(int sheetCount) {
    final count = sheetCount > 0 ? sheetCount : 1;
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    buffer.writeln('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">');
    buffer.writeln('  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>');
    buffer.writeln('  <Default Extension="xml" ContentType="application/xml"/>');
    buffer.writeln('  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>');
    buffer.writeln('  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>');
    for (int i = 1; i <= count; i++) {
      buffer.writeln('  <Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>');
    }
    buffer.writeln('</Types>');
    return buffer.toString();
  }

  String _generateGlobalRelsXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>\n'
        '</Relationships>';
  }

  String _generateWorkbookRelsXml(int sheetCount) {
    final count = sheetCount > 0 ? sheetCount : 1;
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    buffer.writeln('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');
    buffer.writeln('  <Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>');
    for (int i = 1; i <= count; i++) {
      buffer.writeln('  <Relationship Id="rIdSheet$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet$i.xml"/>');
    }
    buffer.writeln('</Relationships>');
    return buffer.toString();
  }

  String _generateWorkbookXml(List<TableModel> tables) {
    final count = tables.isNotEmpty ? tables.length : 1;
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    buffer.writeln('<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">');
    buffer.writeln('  <sheets>');
    for (int i = 1; i <= count; i++) {
      final name = tables.isNotEmpty && tables[i - 1].caption != null
          ? _xmlEscape(tables[i - 1].caption!)
          : 'Bảng $i';
      buffer.writeln('    <sheet name="$name" sheetId="$i" r:id="rIdSheet$i"/>');
    }
    buffer.writeln('  </sheets>');
    buffer.writeln('</workbook>');
    return buffer.toString();
  }

  String _generateStylesXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\n'
        '  <fonts count="2">\n'
        '    <font><name val="Calibri"/><sz val="11"/><color theme="1"/></font>\n'
        '    <font><b/><name val="Calibri"/><sz val="11"/><color theme="1"/></font>\n'
        '  </fonts>\n'
        '  <fills count="2">\n'
        '    <fill><patternFill patternType="none"/></fill>\n'
        '    <fill><patternFill patternType="gray125"/></fill>\n'
        '  </fills>\n'
        '  <borders count="1">\n'
        '    <border><left/><right/><top/><bottom/><diagonal/></border>\n'
        '  </borders>\n'
        '  <cellStyleXfs count="1">\n'
        '    <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>\n'
        '  </cellStyleXfs>\n'
        '  <cellXfs count="2">\n'
        '    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>\n'
        '    <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>\n'
        '  </cellXfs>\n'
        '</styleSheet>';
  }

  String _generateTableSheetXml(TableModel table) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    buffer.writeln('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">');
    buffer.writeln('  <sheetData>');

    for (int r = 0; r < table.rows.length; r++) {
      final row = table.rows[r];
      final rowNum = r + 1;
      buffer.writeln('    <row r="$rowNum">');

      for (int c = 0; c < row.cells.length; c++) {
        final cell = row.cells[c];
        final colRef = _getColumnName(c);
        final cellRef = '$colRef$rowNum';
        final val = cell.text.trim();

        // Check if numeric
        final numVal = double.tryParse(val.replaceAll(',', ''));
        if (numVal != null && !val.startsWith('0') && val.length < 15) {
          buffer.writeln('      <c r="$cellRef" s="${cell.isHeader ? 1 : 0}"><v>$numVal</v></c>');
        } else {
          final escaped = _xmlEscape(val);
          buffer.writeln(
            '      <c r="$cellRef" t="inlineStr" s="${cell.isHeader ? 1 : 0}"><is><t xml:space="preserve">$escaped</t></is></c>',
          );
        }
      }
      buffer.writeln('    </row>');
    }

    buffer.writeln('  </sheetData>');
    buffer.writeln('</worksheet>');
    return buffer.toString();
  }

  String _generateFallbackSheetXml(LayoutDocument doc) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    buffer.writeln('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">');
    buffer.writeln('  <sheetData>');

    int rowNum = 1;
    for (final page in doc.pages) {
      for (final p in page.paragraphs) {
        final escaped = _xmlEscape(p.text);
        buffer.writeln('    <row r="$rowNum">');
        buffer.writeln('      <c r="A$rowNum" t="inlineStr" s="${p.isHeading ? 1 : 0}"><is><t xml:space="preserve">$escaped</t></is></c>');
        buffer.writeln('    </row>');
        rowNum++;
      }
    }

    buffer.writeln('  </sheetData>');
    buffer.writeln('</worksheet>');
    return buffer.toString();
  }

  /// Converts 0-based column index to Excel column name (A, B, ..., Z, AA, AB, ...).
  static String _getColumnName(int colIndex) {
    String name = '';
    int current = colIndex;
    while (current >= 0) {
      name = String.fromCharCode((current % 26) + 65) + name;
      current = (current ~/ 26) - 1;
    }
    return name;
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
