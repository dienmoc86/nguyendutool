import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../core/database/app_database.dart';
import '../../../core/filesystem/workspace_manager.dart';
import '../../../core/logging/app_logger.dart';
import '../domain/models/conversion_options.dart';
import '../domain/models/layout_models.dart';
import '../domain/models/ocr_models.dart';
import '../domain/models/pdf_document_analysis.dart';
import '../domain/models/table_models.dart';
import '../infrastructure/docx_generator.dart';
import '../infrastructure/image_preprocessor.dart';
import '../infrastructure/ocr_engine.dart';
import '../infrastructure/pdf_document_analyzer.dart';
import '../infrastructure/pdf_renderer.dart';
import '../infrastructure/pdf_text_extractor.dart';
import '../infrastructure/pptx_generator.dart';
import '../infrastructure/table_detector.dart';
import '../infrastructure/vietnamese_ocr_engine.dart';
import '../infrastructure/xlsx_generator.dart';

/// Progress reporting callback.
typedef ConversionProgressCallback = void Function(
  int currentPage,
  int totalPages,
  double progress,
  String stageDescription,
);

/// Conversion result bundle.
class ConversionResult {
  final String inputPath;
  final String? docxPath;
  final String? xlsxPath;
  final String? pptxPath;
  final PdfDocumentAnalysis analysis;
  final int totalPages;
  final int durationMs;
  final bool isSuccess;
  final String? errorMessage;

  const ConversionResult({
    required this.inputPath,
    this.docxPath,
    this.xlsxPath,
    this.pptxPath,
    required this.analysis,
    required this.totalPages,
    required this.durationMs,
    this.isSuccess = true,
    this.errorMessage,
  });
}

/// Core application service coordinating the complete PDF conversion workflow.
class PdfConverterService {
  final WorkspaceManager workspaceManager;
  final AppDatabase database;
  final PdfDocumentAnalyzer analyzer;
  final OcrEngine ocrEngine;
  final PdfPageRenderer renderer;
  final DocxGenerator docxGenerator;
  final XlsxGenerator xlsxGenerator;
  final PptxGenerator pptxGenerator;

  PdfConverterService({
    required this.workspaceManager,
    required this.database,
    PdfDocumentAnalyzer? analyzer,
    OcrEngine? ocrEngine,
    PdfPageRenderer? renderer,
    DocxGenerator? docxGenerator,
    XlsxGenerator? xlsxGenerator,
    PptxGenerator? pptxGenerator,
  })  : analyzer = analyzer ?? PdfDocumentAnalyzer(),
        ocrEngine = ocrEngine ?? VietnameseOcrEngine(),
        renderer = renderer ?? WinRtPdfPageRenderer(tempDir: workspaceManager.tempDir),
        docxGenerator = docxGenerator ?? DocxGenerator(),
        xlsxGenerator = xlsxGenerator ?? XlsxGenerator(),
        pptxGenerator = pptxGenerator ?? PptxGenerator();

  /// Converts a PDF document according to specified options with real-time progress callbacks and cancel support.
  Future<ConversionResult> convert({
    required String pdfPath,
    required ConversionOptions options,
    ConversionProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    final stopwatch = Stopwatch()..start();
    final inputFile = File(pdfPath);
    if (!inputFile.existsSync()) {
      throw ArgumentError('Tệp PDF không tồn tại: $pdfPath');
    }

    final filenameWithoutExt = p.basenameWithoutExtension(pdfPath);
    String? outputDocxPath;
    String? outputXlsxPath;
    String? outputPptxPath;
    final createdFiles = <String>[];

    try {
      // Step 1: Analyze Document
      onProgress?.call(0, 0, 0.05, 'Đang phân tích cấu trúc tài liệu PDF...');
      if (isCancelled?.call() == true) throw const ProcessCancelledException();

      final analysis = await analyzer.analyze(pdfPath);
      final totalPages = analysis.totalPages;

      await ocrEngine.initialize();

      final documentPages = <DocumentPage>[];

      // Step 2: Process Page by Page
      for (int i = 0; i < totalPages; i++) {
        if (isCancelled?.call() == true) throw const ProcessCancelledException();

        final pageNum = i + 1;
        final pageAnalysis = i < analysis.pages.length ? analysis.pages[i] : null;
        final requiresOcr = pageAnalysis?.requiresOcr ?? true;

        final pageProgress = 0.1 + 0.7 * (i / totalPages);
        onProgress?.call(
          pageNum,
          totalPages,
          pageProgress,
          'Đang xử lý trang $pageNum / $totalPages (${requiresOcr ? "Nhận diện OCR" : "Trích xuất văn bản"})...',
        );

        List<OcrTextBlock> blocks = [];
        String pageText = '';

        if (!requiresOcr && pageAnalysis?.textLength != null && pageAnalysis!.textLength > 30) {
          // Direct page-specific digital text extraction
          final digitalText = await _extractDigitalText(pdfPath, pageNum);
          if (digitalText.isNotEmpty) {
            pageText = digitalText;
            blocks = _createBlocksFromText(pageText);
          } else {
            // Safe fallback to OCR if page content stream was empty or unmapped
            final ocrRes = await _processPageViaOcr(
              pdfPath: pdfPath,
              pageNum: pageNum,
              pageAnalysis: pageAnalysis,
              options: options,
              isCancelled: isCancelled,
            );
            blocks = ocrRes.blocks;
            pageText = ocrRes.fullText;
          }
        } else {
          // Scanned, mixed, or needsRasterAnalysis: Render, Preprocess, and OCR
          final ocrRes = await _processPageViaOcr(
            pdfPath: pdfPath,
            pageNum: pageNum,
            pageAnalysis: pageAnalysis,
            options: options,
            isCancelled: isCancelled,
          );
          blocks = ocrRes.blocks;
          pageText = ocrRes.fullText;
        }

        // Detect tables if enabled
        List<TableModel> tables = [];
        if (options.detectTables) {
          tables = TableDetector.detectTables(blocks, pageNumber: pageNum);
        }

        // Construct document blocks
        final docBlocks = <DocumentBlock>[];

        if (tables.isNotEmpty) {
          for (final t in tables) {
            docBlocks.add(TableBlock(
              table: t,
              pageNumber: pageNum,
              box: const OcrBoundingBox(left: 40, top: 100, width: 500, height: 200),
            ));
          }
        }

        // Add remaining text as paragraphs
        if (blocks.isNotEmpty) {
          for (final b in blocks) {
            final isHeading = b.text.length < 60 &&
                (b.text == b.text.toUpperCase() ||
                    b.text.startsWith(RegExp(r'^(CHƯƠNG|PHẦN|ĐIỀU)\b', unicode: true)));
            docBlocks.add(
              ParagraphBlock(
                text: b.text,
                pageNumber: pageNum,
                box: b.box,
                isHeading: isHeading,
                headingLevel: isHeading ? 1 : 0,
                alignment: isHeading ? 'center' : 'left',
              ),
            );
          }
        } else if (pageText.isNotEmpty) {
          for (final line in pageText.split('\n')) {
            if (line.trim().isEmpty) continue;
            docBlocks.add(
              ParagraphBlock(
                text: line.trim(),
                pageNumber: pageNum,
                box: const OcrBoundingBox(left: 40, top: 50, width: 500, height: 20),
              ),
            );
          }
        }

        documentPages.add(DocumentPage(pageNumber: pageNum, blocks: docBlocks));
      }

      if (isCancelled?.call() == true) throw const ProcessCancelledException();

      // Step 3: Layout Reconstruction
      final layoutDoc = LayoutDocument(
        title: filenameWithoutExt,
        pages: documentPages,
      );

      // Step 4: Export to Word / Excel
      onProgress?.call(totalPages, totalPages, 0.85, 'Đang xuất tệp Office...');
      if (isCancelled?.call() == true) throw const ProcessCancelledException();

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      if (options.format == OutputFormat.docx ||
          options.format == OutputFormat.both ||
          options.format == OutputFormat.all) {
        outputDocxPath = p.join(
          workspaceManager.exportsDir.path,
          '${filenameWithoutExt}_$timestamp.docx',
        );
        await docxGenerator.generate(document: layoutDoc, outputPath: outputDocxPath);
        createdFiles.add(outputDocxPath);
        await _recordInLibrary(
          outputDocxPath,
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        );
      }

      if (isCancelled?.call() == true) throw const ProcessCancelledException();

      if (options.format == OutputFormat.xlsx ||
          options.format == OutputFormat.both ||
          options.format == OutputFormat.all) {
        outputXlsxPath = p.join(
          workspaceManager.exportsDir.path,
          '${filenameWithoutExt}_$timestamp.xlsx',
        );
        await xlsxGenerator.generate(document: layoutDoc, outputPath: outputXlsxPath);
        createdFiles.add(outputXlsxPath);
        await _recordInLibrary(
          outputXlsxPath,
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
      }

      if (isCancelled?.call() == true) throw const ProcessCancelledException();

      if (options.format == OutputFormat.pptx || options.format == OutputFormat.all) {
        outputPptxPath = p.join(
          workspaceManager.exportsDir.path,
          '${filenameWithoutExt}_$timestamp.pptx',
        );
        await pptxGenerator.generate(
          document: layoutDoc,
          outputPath: outputPptxPath,
          sourcePdfPath: pdfPath,
        );
        createdFiles.add(outputPptxPath);
        await _recordInLibrary(
          outputPptxPath,
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        );
      }

      // Step 5: Clean temporary files
      await renderer.cleanup();

      stopwatch.stop();
      onProgress?.call(totalPages, totalPages, 1.0, 'Chuyển đổi thành công!');

      AppLogger.info(
        'PDF conversion completed successfully for $pdfPath in ${stopwatch.elapsedMilliseconds}ms',
      );

      return ConversionResult(
        inputPath: pdfPath,
        docxPath: outputDocxPath,
        xlsxPath: outputXlsxPath,
        pptxPath: outputPptxPath,
        analysis: analysis,
        totalPages: totalPages,
        durationMs: stopwatch.elapsedMilliseconds,
        isSuccess: true,
      );
    } catch (e, st) {
      stopwatch.stop();

      // Clean up incomplete files on cancellation or error
      for (final fPath in createdFiles) {
        try {
          final f = File(fPath);
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      }
      await renderer.cleanup();

      if (e is ProcessCancelledException) {
        AppLogger.info('PDF conversion cancelled by user for: $pdfPath');
        return ConversionResult(
          inputPath: pdfPath,
          analysis: const PdfDocumentAnalysis(
            filePath: '',
            totalPages: 0,
            pages: [],
            overallClassification: PdfClassification.text,
            totalCharacters: 0,
          ),
          totalPages: 0,
          durationMs: stopwatch.elapsedMilliseconds,
          isSuccess: false,
          errorMessage: 'Quá trình chuyển đổi đã bị người dùng hủy.',
        );
      }

      AppLogger.error('Lỗi khi chuyển đổi PDF sang Office', e, st);
      return ConversionResult(
        inputPath: pdfPath,
        analysis: const PdfDocumentAnalysis(
          filePath: '',
          totalPages: 0,
          pages: [],
          overallClassification: PdfClassification.text,
          totalCharacters: 0,
        ),
        totalPages: 0,
        durationMs: stopwatch.elapsedMilliseconds,
        isSuccess: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Renders, preprocesses, and executes OCR for a single page.
  Future<OcrPageResult> _processPageViaOcr({
    required String pdfPath,
    required int pageNum,
    required PdfPageAnalysis? pageAnalysis,
    required ConversionOptions options,
    bool Function()? isCancelled,
  }) async {
    // 1. Render page image
    final pageImagePath = await renderer.renderPage(
      pdfPath: pdfPath,
      pageNumber: pageNum,
      dpi: options.dpi,
      rotationDegrees: pageAnalysis?.rotationDegrees,
    );

    if (isCancelled?.call() == true) throw const ProcessCancelledException();

    // 2. Preprocess raster image (grayscale, contrast, deskew) if enabled
    String ocrImagePath = pageImagePath;
    if (options.autoEnhance || options.autoDeskew) {
      final prepResult = await ImagePreprocessor.processImageFile(
        inputPath: pageImagePath,
        outputDir: workspaceManager.tempDir.path,
        autoDeskew: options.autoDeskew,
        autoEnhance: options.autoEnhance,
        rotationDegrees: pageAnalysis?.rotationDegrees ?? 0,
      );
      ocrImagePath = prepResult.processedImagePath;
    }

    if (isCancelled?.call() == true) throw const ProcessCancelledException();

    // 3. OCR execution
    return await ocrEngine.recognizePage(
      OcrRequest(
        imagePath: ocrImagePath,
        pageNumber: pageNum,
        language: options.language.code,
        autoDeskew: options.autoDeskew,
        autoEnhance: options.autoEnhance,
        rotationDegrees: pageAnalysis?.rotationDegrees ?? 0,
        autoRotate: true,
        allowFallbackLanguage: true,
      ),
    );
  }

  /// Digital text extraction strictly specific to [pageNum] (1-indexed).
  Future<String> _extractDigitalText(String pdfPath, int pageNum) async {
    final text = await PdfTextExtractor.extractPageText(pdfPath, pageNum);
    return text;
  }

  List<OcrTextBlock> _createBlocksFromText(String text) {
    final lines = text.split('\n');
    final blocks = <OcrTextBlock>[];
    double top = 50.0;
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      blocks.add(
        OcrTextBlock(
          text: line.trim(),
          box: OcrBoundingBox(left: 40.0, top: top, width: 500.0, height: 18.0),
          confidence: null,
        ),
      );
      top += 22.0;
    }
    return blocks;
  }

  Future<void> _recordInLibrary(String filePath, String mimeType) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return;

      final now = DateTime.now().toIso8601String();
      final ext = p.extension(filePath).replaceAll('.', '');
      final fileId = '${p.basenameWithoutExtension(filePath)}_$ext';
      await database.db.insert('files', {
        'id': fileId,
        'original_name': p.basename(filePath),
        'local_path': filePath,
        'mime_type': mimeType,
        'size': file.lengthSync(),
        'created_at': now,
      });
      AppLogger.info('Recorded output file in Document Library: ${file.path}');
    } catch (e) {
      AppLogger.warning('Could not record file into library database', e);
    }
  }
}

/// Thrown when the user cancels the conversion process.
class ProcessCancelledException implements Exception {
  final String message;
  const ProcessCancelledException([this.message = 'Quá trình đã bị hủy bởi người dùng.']);

  @override
  String toString() => message;
}
