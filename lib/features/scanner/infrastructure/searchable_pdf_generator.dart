import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import '../../../core/errors/app_exceptions.dart';
import '../../../core/logging/app_logger.dart';
import '../../pdf_converter/domain/models/ocr_models.dart';
import '../domain/models/scan_options.dart';
import '../domain/models/scan_page.dart';

/// Generates multi-page Searchable and Standard PDF documents from scanned pages.
/// - Visual Layer: High-resolution raster scan image (DCT/JPEG compressed).
/// - Text Layer: Invisible OCR text layer (Render Mode 3 Tr) aligned to coordinates
///   with ISO 32000 /ActualText UTF-16BE spans for full Vietnamese Unicode Ctrl+F searching.
class SearchablePdfGenerator {
  /// Generates a PDF file from [pages] according to [options].
  Future<String> generatePdf({
    required List<ScanPage> pages,
    required ScanOutputOptions options,
    void Function(double progress, String status)? onProgress,
  }) async {
    if (pages.isEmpty) {
      throw const ScanExportException('Không có trang nào trong phiên quét để xuất PDF.');
    }

    final outDir = Directory(p.dirname(options.outputPath));
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }

    final outputFile = File(options.outputPath);
    final isSearchable = options.format == ScanOutputFormat.searchablePdf;

    onProgress?.call(0.05, 'Đang chuẩn bị dữ liệu xuất PDF...');

    final pdfBuilder = _RawPdfBuilder();

    for (int i = 0; i < pages.length; i++) {
      final page = pages[i];
      final pageNum = i + 1;
      final pct = 0.1 + (i / pages.length) * 0.8;
      onProgress?.call(pct, 'Đang xây dựng trang $pageNum/${pages.length}...');

      // Load processed image or fallback to original
      final imagePath = File(page.processedPath).existsSync()
          ? page.processedPath
          : page.originalPath;

      final imgBytes = await File(imagePath).readAsBytes();
      img.Image? decoded = img.decodeImage(imgBytes);
      if (decoded == null) {
        throw ScanExportException('Không thể giải mã hình ảnh trang $pageNum: $imagePath');
      }

      // Encode as JPEG according to chosen quality preset
      final jpegQuality = (options.quality.jpegQuality * 100).round();
      final compressedJpegBytes = Uint8List.fromList(
        img.encodeJpg(decoded, quality: jpegQuality),
      );

      // Determine PDF page dimensions in points (A4 base: 595.28 pt width)
      const baseWidthPt = 595.28;
      final aspectRatio = decoded.height / decoded.width.toDouble();
      final pageHeightPt = baseWidthPt * aspectRatio;

      // Extract OCR blocks if searchable PDF requested
      List<OcrTextBlock> blocks = const [];
      if (isSearchable && page.ocrResult != null && page.ocrResult!.blocks.isNotEmpty) {
        blocks = page.ocrResult!.blocks;
      }

      pdfBuilder.addPage(
        jpegBytes: compressedJpegBytes,
        pixelWidth: decoded.width,
        pixelHeight: decoded.height,
        pageWidthPt: baseWidthPt,
        pageHeightPt: pageHeightPt,
        ocrBlocks: blocks,
      );
    }

    onProgress?.call(0.95, 'Đang ghi tệp PDF...');
    final pdfBytes = pdfBuilder.build();
    await outputFile.writeAsBytes(pdfBytes);

    onProgress?.call(1.0, 'Xuất tệp PDF hoàn tất.');
    AppLogger.info('Successfully generated Searchable PDF at: ${options.outputPath} (${pdfBytes.length} bytes)');
    return options.outputPath;
  }
}

/// Internal raw PDF builder producing compliant PDF 1.5 documents
/// with DCTDecode images and /ActualText Unicode text overlays.
class _RawPdfBuilder {
  final List<Uint8List> _pagesJpeg = [];
  final List<List<int>> _pagesPixelDims = [];
  final List<List<double>> _pagesPtDims = [];
  final List<List<OcrTextBlock>> _pagesOcr = [];

  void addPage({
    required Uint8List jpegBytes,
    required int pixelWidth,
    required int pixelHeight,
    required double pageWidthPt,
    required double pageHeightPt,
    required List<OcrTextBlock> ocrBlocks,
  }) {
    _pagesJpeg.add(jpegBytes);
    _pagesPixelDims.add([pixelWidth, pixelHeight]);
    _pagesPtDims.add([pageWidthPt, pageHeightPt]);
    _pagesOcr.add(ocrBlocks);
  }

  Uint8List build() {
    final buffer = BytesBuilder();
    final xrefOffsets = <int>[];

    void writeString(String str) {
      buffer.add(utf8.encode(str));
    }

    void writeBytes(List<int> bytes) {
      buffer.add(bytes);
    }

    int currentOffset() => buffer.length;

    // Header
    writeString('%PDF-1.5\r\n');
    writeString('%\xE2\xE3\xCF\xD3\r\n');

    final pageCount = _pagesJpeg.length;
    // Object ID layout:
    // 1: Catalog
    // 2: Pages
    // 3: Font /F1
    // Per page (4 objects per page):
    // Page Obj: 4 + i*4 + 0
    // Image XObj: 4 + i*4 + 1
    // Content Stream: 4 + i*4 + 2
    // (Optional reserved): 4 + i*4 + 3

    xrefOffsets.add(0); // 0 is always dummy in xref

    // 1: Catalog
    xrefOffsets.add(currentOffset());
    writeString('1 0 obj\r\n');
    writeString('<< /Type /Catalog /Pages 2 0 R >>\r\n');
    writeString('endobj\r\n');

    // 2: Pages tree
    final pageRefList = <String>[];
    for (int i = 0; i < pageCount; i++) {
      final pageObjId = 4 + i * 3;
      pageRefList.add('$pageObjId 0 R');
    }
    xrefOffsets.add(currentOffset());
    writeString('2 0 obj\r\n');
    writeString('<< /Type /Pages /Kids [${pageRefList.join(' ')}] /Count $pageCount >>\r\n');
    writeString('endobj\r\n');

    // 3: Standard Helvetica Font
    xrefOffsets.add(currentOffset());
    writeString('3 0 obj\r\n');
    writeString('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\r\n');
    writeString('endobj\r\n');

    // Per-page objects
    for (int i = 0; i < pageCount; i++) {
      final pageObjId = 4 + i * 3;
      final imageObjId = pageObjId + 1;
      final contentObjId = pageObjId + 2;

      final ptDim = _pagesPtDims[i];
      final pixelDim = _pagesPixelDims[i];
      final ptW = ptDim[0];
      final ptH = ptDim[1];
      final pxW = pixelDim[0];
      final pxH = pixelDim[1];

      final jpeg = _pagesJpeg[i];
      final ocr = _pagesOcr[i];

      // Page Object
      xrefOffsets.add(currentOffset());
      writeString('$pageObjId 0 obj\r\n');
      writeString('<< /Type /Page /Parent 2 0 R\r\n');
      writeString('/MediaBox [0 0 ${ptW.toStringAsFixed(2)} ${ptH.toStringAsFixed(2)}]\r\n');
      writeString('/Resources <<\r\n');
      writeString('  /Font << /F1 3 0 R >>\r\n');
      writeString('  /XObject << /Im1 $imageObjId 0 R >>\r\n');
      writeString('>>\r\n');
      writeString('/Contents $contentObjId 0 R\r\n');
      writeString('>>\r\n');
      writeString('endobj\r\n');

      // Image XObject
      xrefOffsets.add(currentOffset());
      writeString('$imageObjId 0 obj\r\n');
      writeString('<< /Type /XObject /Subtype /Image\r\n');
      writeString('/Width $pxW /Height $pxH\r\n');
      writeString('/ColorSpace /DeviceRGB /BitsPerComponent 8\r\n');
      writeString('/Filter /DCTDecode /Length ${jpeg.length} >>\r\n');
      writeString('stream\r\n');
      writeBytes(jpeg);
      writeString('\r\nendstream\r\n');
      writeString('endobj\r\n');

      // Content Stream
      final contentBuffer = StringBuffer();
      // Draw background image full page
      contentBuffer.write('q\r\n');
      contentBuffer.write('${ptW.toStringAsFixed(2)} 0 0 ${ptH.toStringAsFixed(2)} 0 0 cm\r\n');
      contentBuffer.write('/Im1 Do\r\n');
      contentBuffer.write('Q\r\n');

      // Render invisible text layer if OCR text exists
      if (ocr.isNotEmpty) {
        final scaleX = ptW / pxW.toDouble();
        final scaleY = ptH / pxH.toDouble();

        for (final block in ocr) {
          final text = block.text.trim();
          if (text.isEmpty) continue;

          // Compute PDF coordinates (origin at bottom-left)
          final xPdf = block.box.left * scaleX;
          final boxHPdf = block.box.height * scaleY;
          final yPdf = (pxH - (block.box.top + block.box.height)) * scaleY;
          final fontSize = math.max(6.0, boxHPdf * 0.85);

          final actualTextHex = _toUtf16BeHex(text);

          contentBuffer.write('/Span << /ActualText $actualTextHex >> BDC\r\n');
          contentBuffer.write('BT\r\n');
          contentBuffer.write('3 Tr\r\n'); // Invisible text mode
          contentBuffer.write('/F1 ${fontSize.toStringAsFixed(2)} Tf\r\n');
          contentBuffer.write('1 0 0 1 ${xPdf.toStringAsFixed(2)} ${yPdf.toStringAsFixed(2)} Tm\r\n');
          // Dummy ASCII string so PDF viewer assigns physical width to the word
          final placeholder = ' ' * math.max(1, text.length);
          contentBuffer.write('($placeholder) Tj\r\n');
          contentBuffer.write('ET\r\n');
          contentBuffer.write('EMC\r\n');
        }
      }

      final contentBytes = utf8.encode(contentBuffer.toString());
      xrefOffsets.add(currentOffset());
      writeString('$contentObjId 0 obj\r\n');
      writeString('<< /Length ${contentBytes.length} >>\r\n');
      writeString('stream\r\n');
      writeBytes(contentBytes);
      writeString('\r\nendstream\r\n');
      writeString('endobj\r\n');
    }

    // Cross-Reference Table (xref)
    final startXref = currentOffset();
    writeString('xref\r\n');
    writeString('0 ${xrefOffsets.length}\r\n');
    writeString('0000000000 65535 f\r\n');
    for (int i = 1; i < xrefOffsets.length; i++) {
      final off = xrefOffsets[i].toString().padLeft(10, '0');
      writeString('$off 00000 n\r\n');
    }

    // Trailer
    writeString('trailer\r\n');
    writeString('<< /Size ${xrefOffsets.length} /Root 1 0 R >>\r\n');
    writeString('startxref\r\n');
    writeString('$startXref\r\n');
    writeString('%%EOF\r\n');

    return buffer.toBytes();
  }

  /// Converts a UTF-8 string to a PDF UTF-16BE hex string `<FEFF...>`
  static String _toUtf16BeHex(String text) {
    final buffer = StringBuffer('<FEFF');
    for (int i = 0; i < text.length; i++) {
      final codeUnit = text.codeUnitAt(i);
      buffer.write(codeUnit.toRadixString(16).padLeft(4, '0').toUpperCase());
    }
    buffer.write('>');
    return buffer.toString();
  }
}
