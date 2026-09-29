import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/filesystem/workspace_manager.dart';
import '../../../core/logging/app_logger.dart';
import '../../pdf_converter/domain/models/conversion_options.dart';
import '../../pdf_converter/infrastructure/pdf_document_analyzer.dart';
import '../../pdf_converter/infrastructure/pdf_renderer.dart';
import '../domain/models/document_quad.dart';
import '../domain/models/scan_options.dart';
import '../domain/models/scan_page.dart';
import '../infrastructure/cv_document_processor.dart';

/// Imports existing PDF documents into a scanner session by rasterizing each page into [ScanPage].
/// Reuses the existing [WinRtPdfPageRenderer] and does not modify the source PDF.
class PdfImportService {
  final PdfPageRenderer renderer;
  final PdfDocumentAnalyzer analyzer;

  PdfImportService({
    PdfPageRenderer? renderer,
    PdfDocumentAnalyzer? analyzer,
  })  : renderer = renderer ??
            WinRtPdfPageRenderer(
              tempDir: Directory(p.join(WorkspaceManager.getDefaultWorkspacePath(), 'temp', 'pdf_render')),
            ),
        analyzer = analyzer ?? PdfDocumentAnalyzer();

  /// Rasterizes all pages from [pdfPath] into [ScanPage] objects for [sessionId].
  Future<List<ScanPage>> importPdf({
    required String pdfPath,
    required String sessionId,
    int startingIndex = 0,
    void Function(double progress, String status)? onProgress,
  }) async {
    final pdfFile = File(pdfPath);
    if (!pdfFile.existsSync()) {
      throw ScanImportException('Tệp PDF nguồn không tồn tại: $pdfPath');
    }

    onProgress?.call(0.05, 'Đang phân tích cấu trúc tệp PDF...');
    final analysis = await analyzer.analyze(pdfPath);
    final totalPages = analysis.totalPages;

    if (totalPages <= 0) {
      throw const ScanImportException('Tệp PDF không có trang nào để nhập.');
    }

    final tempDir = Directory(p.join(WorkspaceManager.getDefaultWorkspacePath(), 'temp', 'scans', sessionId));
    if (!tempDir.existsSync()) {
      tempDir.createSync(recursive: true);
    }

    final pages = <ScanPage>[];

    for (int pageNum = 1; pageNum <= totalPages; pageNum++) {
      final currentIdx = startingIndex + (pageNum - 1);
      final pct = pageNum / totalPages;
      onProgress?.call(pct, 'Đang rasterize trang $pageNum/$totalPages...');

      try {
        final renderedPngPath = await renderer.renderPage(
          pdfPath: pdfPath,
          pageNumber: pageNum,
          dpi: DpiPreset.high200,
        );

        final renderedBytes = await File(renderedPngPath).readAsBytes();
        img.Image? decoded = img.decodeImage(renderedBytes);
        if (decoded == null) {
          AppLogger.warning('Cannot decode rasterized PDF page $pageNum');
          continue;
        }

        // Canonical Orientation Normalization
        decoded = img.bakeOrientation(decoded);

        final pageId = const Uuid().v4();
        final origFileName = 'page_${currentIdx + 1}_orig.png';
        final origPath = p.join(tempDir.path, origFileName);
        await File(origPath).writeAsBytes(img.encodePng(decoded));

        // Auto boundary detection
        final detectedQuad = CvDocumentProcessor.detectDocumentQuad(decoded);
        final quality = CvDocumentProcessor.assessQuality(decoded);
        final isBlank = CvDocumentProcessor.detectBlankPage(decoded);
        final dHash = CvDocumentProcessor.calculateDHash(decoded);

        // Processed version
        img.Image processedImg = decoded;
        if (detectedQuad.isPlausible(decoded.width.toDouble(), decoded.height.toDouble()) &&
            detectedQuad != DocumentQuad.fullImage(decoded.width.toDouble(), decoded.height.toDouble())) {
          processedImg = CvDocumentProcessor.warpPerspective(decoded, detectedQuad);
        }

        processedImg = CvDocumentProcessor.enhanceImage(
          processedImg,
          const ScanProcessingOptions(preset: EnhancementPreset.document),
        );

        final procFileName = 'page_${currentIdx + 1}_proc.png';
        final procPath = p.join(tempDir.path, procFileName);
        await File(procPath).writeAsBytes(img.encodePng(processedImg));

        pages.add(
          ScanPage(
            id: pageId,
            sessionId: sessionId,
            pageIndex: currentIdx,
            originalPath: origPath,
            processedPath: procPath,
            rotation: 0,
            detectedQuad: detectedQuad,
            quality: quality,
            isLikelyBlank: isBlank,
            perceptualHash: dHash,
            createdAt: DateTime.now(),
          ),
        );
      } catch (e, st) {
        AppLogger.error('Failed to rasterize PDF page $pageNum: $e', e, st);
      }
    }

    return pages;
  }
}
