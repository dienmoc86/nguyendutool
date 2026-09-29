import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import '../../../core/logging/app_logger.dart';
import '../domain/models/layout_models.dart';
import '../domain/models/table_models.dart';

/// Generates standard ECMA-376 / ISO 29500 Microsoft PowerPoint (.pptx) presentation files.
/// Tailored specifically for school teachers, educators, and administrative staff.
class PptxGenerator {
  /// Generates a valid .pptx presentation file from layout document and writes to target path.
  Future<File> generate({
    required LayoutDocument document,
    required String outputPath,
    String? sourcePdfPath,
  }) async {
    // 1. If sourcePdfPath is available and local python office_converter is present, try high-fidelity visual generation
    if (sourcePdfPath != null && File(sourcePdfPath).existsSync()) {
      final visualSuccess = await _tryVisualPptxConversion(sourcePdfPath, outputPath);
      if (visualSuccess && File(outputPath).existsSync()) {
        AppLogger.info('Generated high-fidelity PPTX presentation via visual engine.');
        return File(outputPath);
      }
    }

    // 2. Pure Dart PresentationML generator (Zero external dependency)
    final archive = Archive();

    // 1. [Content_Types].xml
    final contentTypesXml = _generateContentTypesXml(document.pages.length);
    archive.addFile(
      ArchiveFile('[Content_Types].xml', contentTypesXml.length, utf8.encode(contentTypesXml)),
    );

    // 2. _rels/.rels
    final globalRelsXml = _generateGlobalRelsXml();
    archive.addFile(
      ArchiveFile('_rels/.rels', globalRelsXml.length, utf8.encode(globalRelsXml)),
    );

    // 3. ppt/_rels/presentation.xml.rels
    final presRelsXml = _generatePresentationRelsXml(document.pages.length);
    archive.addFile(
      ArchiveFile('ppt/_rels/presentation.xml.rels', presRelsXml.length, utf8.encode(presRelsXml)),
    );

    // 4. ppt/presentation.xml
    final presXml = _generatePresentationXml(document.pages.length);
    archive.addFile(
      ArchiveFile('ppt/presentation.xml', presXml.length, utf8.encode(presXml)),
    );

    // 5. ppt/theme/theme1.xml
    final themeXml = _generateThemeXml();
    archive.addFile(
      ArchiveFile('ppt/theme/theme1.xml', themeXml.length, utf8.encode(themeXml)),
    );

    // 6. ppt/slideMasters/slideMaster1.xml & rels
    final masterXml = _generateSlideMasterXml();
    archive.addFile(
      ArchiveFile('ppt/slideMasters/slideMaster1.xml', masterXml.length, utf8.encode(masterXml)),
    );
    final masterRelsXml = _generateSlideMasterRelsXml();
    archive.addFile(
      ArchiveFile('ppt/slideMasters/_rels/slideMaster1.xml.rels', masterRelsXml.length, utf8.encode(masterRelsXml)),
    );

    // 7. ppt/slideLayouts/slideLayout1.xml & rels
    final layoutXml = _generateSlideLayoutXml();
    archive.addFile(
      ArchiveFile('ppt/slideLayouts/slideLayout1.xml', layoutXml.length, utf8.encode(layoutXml)),
    );
    final layoutRelsXml = _generateSlideLayoutRelsXml();
    archive.addFile(
      ArchiveFile('ppt/slideLayouts/_rels/slideLayout1.xml.rels', layoutRelsXml.length, utf8.encode(layoutRelsXml)),
    );

    // 8. Individual slides: ppt/slides/slide{i}.xml & rels
    for (int i = 0; i < document.pages.length; i++) {
      final slideNum = i + 1;
      final page = document.pages[i];

      final slideXml = _generateSlideXml(page, slideNum);
      archive.addFile(
        ArchiveFile('ppt/slides/slide$slideNum.xml', slideXml.length, utf8.encode(slideXml)),
      );

      final slideRelsXml = _generateSlideRelsXml();
      archive.addFile(
        ArchiveFile('ppt/slides/_rels/slide$slideNum.xml.rels', slideRelsXml.length, utf8.encode(slideRelsXml)),
      );
    }

    // Compress to zip archive
    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);
    if (zipBytes == null) {
      throw const FormatException('Không thể mã hóa file PPTX.');
    }

    final file = File(outputPath);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    await file.writeAsBytes(zipBytes);
    return file;
  }

  /// Attempts high-fidelity PPTX conversion via local python converter suite if available.
  Future<bool> _tryVisualPptxConversion(String inputPdf, String outputPptx) async {
    try {
      final converterScript = p.join(Directory.current.path, 'tools', 'office_converter', 'converter.py');
      if (!File(converterScript).existsSync()) return false;

      final res = await Process.run(
        'python',
        [converterScript, inputPdf, '-t', 'pptx', '-o', outputPptx],
      ).timeout(const Duration(seconds: 45));

      return res.exitCode == 0 && File(outputPptx).existsSync();
    } catch (e) {
      AppLogger.warning('Visual PPTX conversion fallback to native PresentationML: $e');
      return false;
    }
  }

  String _generateContentTypesXml(int slideCount) {
    final sb = StringBuffer();
    sb.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    sb.writeln('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">');
    sb.writeln('  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>');
    sb.writeln('  <Default Extension="xml" ContentType="application/xml"/>');
    sb.writeln('  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>');
    sb.writeln('  <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>');
    sb.writeln('  <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>');
    sb.writeln('  <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>');
    for (int i = 1; i <= slideCount; i++) {
      sb.writeln('  <Override PartName="/ppt/slides/slide$i.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>');
    }
    sb.writeln('</Types>');
    return sb.toString();
  }

  String _generateGlobalRelsXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>\n'
        '</Relationships>';
  }

  String _generatePresentationRelsXml(int slideCount) {
    final sb = StringBuffer();
    sb.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    sb.writeln('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');
    sb.writeln('  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>');
    sb.writeln('  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="theme/theme1.xml"/>');
    for (int i = 1; i <= slideCount; i++) {
      sb.writeln('  <Relationship Id="rId${i + 2}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide$i.xml"/>');
    }
    sb.writeln('</Relationships>');
    return sb.toString();
  }

  String _generatePresentationXml(int slideCount) {
    final sb = StringBuffer();
    sb.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    sb.writeln('<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">');
    sb.writeln('  <p:sldMasterIdLst>');
    sb.writeln('    <p:sldMasterId id="2147483648" r:id="rId1"/>');
    sb.writeln('  </p:sldMasterIdLst>');
    sb.writeln('  <p:sldIdLst>');
    for (int i = 1; i <= slideCount; i++) {
      sb.writeln('    <p:sldId id="${255 + i}" r:id="rId${i + 2}"/>');
    }
    sb.writeln('  </p:sldIdLst>');
    // 16:9 widescreen dimensions (12192000 x 6858000 dxa)
    sb.writeln('  <p:sldSz cx="12192000" cy="6858000" type="screen16x9"/>');
    sb.writeln('  <p:notesSz cx="6858000" cy="9144000"/>');
    sb.writeln('</p:presentation>');
    return sb.toString();
  }

  String _generateSlideRelsXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>\n'
        '</Relationships>';
  }

  String _generateSlideLayoutRelsXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>\n'
        '</Relationships>';
  }

  String _generateSlideMasterRelsXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>\n'
        '  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>\n'
        '</Relationships>';
  }

  String _generateThemeXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="NguyenDu School Theme">
  <a:themeElements>
    <a:clrScheme name="NguyenDuEducation">
      <a:dk1><a:srgbClr val="1A1D20"/></a:dk1>
      <a:lt1><a:srgbClr val="FFFFFF"/></a:lt1>
      <a:dk2><a:srgbClr val="2B3A42"/></a:dk2>
      <a:lt2><a:srgbClr val="F4F6F9"/></a:lt2>
      <a:accent1><a:srgbClr val="1F4E79"/></a:accent1>
      <a:accent2><a:srgbClr val="2E75B6"/></a:accent2>
      <a:accent3><a:srgbClr val="5B9BD5"/></a:accent3>
      <a:accent4><a:srgbClr val="41719C"/></a:accent4>
      <a:accent5><a:srgbClr val="1E4E79"/></a:accent5>
      <a:accent6><a:srgbClr val="002060"/></a:accent6>
      <a:hlink><a:srgbClr val="0563C1"/></a:hlink>
      <a:folHlink><a:srgbClr val="954F72"/></a:folHlink>
    </a:clrScheme>
    <a:fontScheme name="EducationFonts">
      <a:majorFont><a:latin typeface="Arial"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont>
      <a:minorFont><a:latin typeface="Arial"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont>
    </a:fontScheme>
    <a:fmtScheme name="Office">
      <a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst>
      <a:lnStyleLst><a:ln w="9525"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln></a:lnStyleLst>
      <a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst>
      <a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst>
    </a:fmtScheme>
  </a:themeElements>
</a:theme>''';
  }

  String _generateSlideMasterXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
    </p:spTree>
  </p:cSld>
  <p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>
  <p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst>
</p:sldMaster>''';
  }

  String _generateSlideLayoutXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" type="titleAndContent" preserve="1">
  <p:cSld name="Title and Content">
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
    </p:spTree>
  </p:cSld>
</p:sldLayout>''';
  }

  /// Generates clean slide content from layout page.
  String _generateSlideXml(DocumentPage page, int slideNum) {
    final sb = StringBuffer();
    sb.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    sb.writeln('<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">');
    sb.writeln('  <p:cSld>');
    sb.writeln('    <p:spTree>');
    sb.writeln('      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>');
    sb.writeln('      <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>');

    // 1. School Header Banner shape
    sb.writeln('      <p:sp>');
    sb.writeln('        <p:nvSpPr><p:cNvPr id="2" name="SchoolHeader"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>');
    sb.writeln('        <p:spPr>');
    sb.writeln('          <a:xfrm><a:off x="0" y="0"/><a:ext cx="12192000" cy="800000"/></a:xfrm>');
    sb.writeln('          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>');
    sb.writeln('          <a:solidFill><a:srgbClr val="1F4E79"/></a:solidFill>');
    sb.writeln('        </p:spPr>');
    sb.writeln('        <p:txBody>');
    sb.writeln('          <a:bodyPr vert="horz" lIns="360000" tIns="180000" rIns="360000" bIns="180000" anchor="ctr"/>');
    sb.writeln('          <a:lstStyle/>');
    sb.writeln('          <a:p>');
    sb.writeln('            <a:pPr algn="l"/>');
    sb.writeln('            <a:r>');
    sb.writeln('              <a:rPr lang="vi-VN" sz="1800" b="1"><a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill><a:latin typeface="Arial"/></a:rPr>');
    sb.writeln('              <a:t>TRƯỜNG THCS NGUYỄN DU - BÀI GIẢNG ĐIỆN TỬ (TRANG $slideNum)</a:t>');
    sb.writeln('            </a:r>');
    sb.writeln('          </a:p>');
    sb.writeln('        </p:txBody>');
    sb.writeln('      </p:sp>');

    // 2. Slide Content Box
    sb.writeln('      <p:sp>');
    sb.writeln('        <p:nvSpPr><p:cNvPr id="3" name="ContentBox"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>');
    sb.writeln('        <p:spPr>');
    sb.writeln('          <a:xfrm><a:off x="720000" y="1100000"/><a:ext cx="10752000" cy="5100000"/></a:xfrm>');
    sb.writeln('          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>');
    sb.writeln('          <a:noFill/>');
    sb.writeln('        </p:spPr>');
    sb.writeln('        <p:txBody>');
    sb.writeln('          <a:bodyPr vert="horz" lIns="0" tIns="0" rIns="0" bIns="0"/>');
    sb.writeln('          <a:lstStyle/>');

    // Extract text paragraphs and tables
    bool hasContent = false;
    for (final block in page.blocks) {
      if (block is ParagraphBlock) {
        if (block.text.trim().isEmpty) continue;
        hasContent = true;

        final isHeading = block.isHeading || block.fontSize > 13.0;
        final fontSizeEighths = isHeading ? 2000 : 1500; // 20pt for title, 15pt for body

        sb.writeln('          <a:p>');
        if (isHeading) {
          sb.writeln('            <a:pPr marL="0" indent="0"><a:spcBfr><a:spcPts val="1200"/></a:spcBfr><a:spcAft><a:spcPts val="600"/></a:spcAft></a:pPr>');
        } else {
          sb.writeln('            <a:pPr lvl="0" marL="288000" indent="-288000"><a:buChar char="•"/><a:spcAft><a:spcPts val="400"/></a:spcAft></a:pPr>');
        }
        sb.writeln('            <a:r>');
        sb.writeln('              <a:rPr lang="vi-VN" sz="$fontSizeEighths" b="${isHeading ? "1" : "0"}">');
        sb.writeln('                <a:solidFill><a:srgbClr val="${isHeading ? "1F4E79" : "262626"}"/></a:solidFill>');
        sb.writeln('                <a:latin typeface="Arial"/>');
        sb.writeln('              </a:rPr>');
        sb.writeln('              <a:t>${_escapeXml(block.text.trim())}</a:t>');
        sb.writeln('            </a:r>');
        sb.writeln('          </a:p>');
      } else if (block is TableBlock) {
        hasContent = true;
        for (final row in block.table.rows) {
          final rowText = row.cells.map((c) => c.text.trim()).where((t) => t.isNotEmpty).join(' | ');
          if (rowText.isEmpty) continue;
          sb.writeln('          <a:p>');
          sb.writeln('            <a:pPr lvl="0" marL="288000" indent="-288000"><a:buChar char="▪"/><a:spcAft><a:spcPts val="300"/></a:spcAft></a:pPr>');
          sb.writeln('            <a:r>');
          sb.writeln('              <a:rPr lang="vi-VN" sz="1300" b="${row.isHeader ? "1" : "0"}">');
          sb.writeln('                <a:solidFill><a:srgbClr val="${row.isHeader ? "1F4E79" : "333333"}"/></a:solidFill>');
          sb.writeln('                <a:latin typeface="Arial"/>');
          sb.writeln('              </a:rPr>');
          sb.writeln('              <a:t>${_escapeXml(rowText)}</a:t>');
          sb.writeln('            </a:r>');
          sb.writeln('          </a:p>');
        }
      }
    }

    if (!hasContent) {
      sb.writeln('          <a:p>');
      sb.writeln('            <a:r>');
      sb.writeln('              <a:rPr lang="vi-VN" sz="1600" i="1"><a:solidFill><a:srgbClr val="8C8C8C"/></a:solidFill></a:rPr>');
      sb.writeln('              <a:t>[Nội dung trang tài liệu số hóa]</a:t>');
      sb.writeln('            </a:r>');
      sb.writeln('          </a:p>');
    }

    sb.writeln('        </p:txBody>');
    sb.writeln('      </p:sp>');

    sb.writeln('    </p:spTree>');
    sb.writeln('  </p:cSld>');
    sb.writeln('</p:sld>');
    return sb.toString();
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
