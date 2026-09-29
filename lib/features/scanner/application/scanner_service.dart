import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/jobs/data/job_repository.dart';
import '../../../core/jobs/domain/job_model.dart';
import '../../../core/jobs/domain/job_status.dart';
import '../../../core/jobs/domain/job_type.dart';
import '../../../core/logging/app_logger.dart';
import '../../file_library/domain/file_entry.dart';
import '../../file_library/infrastructure/file_repository.dart';
import '../../pdf_converter/domain/models/layout_models.dart';
import '../../pdf_converter/domain/models/ocr_models.dart';
import '../../pdf_converter/infrastructure/docx_generator.dart';
import '../../pdf_converter/infrastructure/pptx_generator.dart';
import '../../pdf_converter/infrastructure/vietnamese_ocr_engine.dart';
import '../domain/models/document_quad.dart';
import '../domain/models/scan_options.dart';
import '../domain/models/scan_page.dart';
import '../domain/models/scan_profile.dart';
import '../domain/models/scan_session.dart';
import '../domain/repositories/scan_session_repository.dart';
import '../domain/services/scanner_device_provider.dart';
import '../infrastructure/cv_document_processor.dart';
import '../infrastructure/searchable_pdf_generator.dart';
import '../infrastructure/windows_camera_service.dart';
import 'image_import_service.dart';
import 'pdf_import_service.dart';

/// Primary application service orchestrating document scanning, computer vision processing,
/// OCR recognition, session persistence, and multi-format document export.
class ScannerService {
  final ScannerDeviceProvider deviceProvider;
  final WindowsCameraService cameraService;
  final ImageImportService imageImportService;
  final PdfImportService pdfImportService;
  final VietnameseOcrEngine ocrEngine;
  final SearchablePdfGenerator pdfGenerator;
  final DocxGenerator docxGenerator;
  final PptxGenerator pptxGenerator;
  final ScanSessionRepository sessionRepository;
  final JobRepository jobRepository;
  final FileRepository fileRepository;

  bool _isCancelled = false;
  String? _activeJobId;

  ScannerService({
    required this.deviceProvider,
    required this.cameraService,
    required this.imageImportService,
    required this.pdfImportService,
    required this.ocrEngine,
    required this.pdfGenerator,
    required this.docxGenerator,
    PptxGenerator? pptxGenerator,
    required this.sessionRepository,
    required this.jobRepository,
    required this.fileRepository,
  }) : pptxGenerator = pptxGenerator ?? PptxGenerator();

  /// Creates a new empty scan session.
  ScanSession createSession(ScanSource source, [String? name]) {
    final now = DateTime.now();
    final id = const Uuid().v4();
    final session = ScanSession(
      id: id,
      name: name ?? 'Phiên quét ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')} ${now.hour}:${now.minute}',
      sourceType: source,
      createdAt: now,
      updatedAt: now,
    );
    return session;
  }

  /// Checks if Windows has Vietnamese OCR installed.
  Future<bool> checkVietnameseOcrInstalled() async {
    await ocrEngine.initialize();
    return ocrEngine.hasVietnameseLanguagePack;
  }

  /// Imports local image files into [session].
  Future<ScanSession> importImages({
    required ScanSession session,
    required List<String> filePaths,
    void Function(double progress, String status)? onProgress,
  }) async {
    final importedPages = await imageImportService.importImages(
      filePaths: filePaths,
      sessionId: session.id,
      startingIndex: session.pageCount,
      onProgress: onProgress,
    );

    var updated = session;
    for (final page in importedPages) {
      updated = updated.addPage(page);
    }
    await sessionRepository.saveSession(updated);
    return updated;
  }

  /// Imports an existing PDF document into [session].
  Future<ScanSession> importPdf({
    required ScanSession session,
    required String pdfPath,
    void Function(double progress, String status)? onProgress,
  }) async {
    final importedPages = await pdfImportService.importPdf(
      pdfPath: pdfPath,
      sessionId: session.id,
      startingIndex: session.pageCount,
      onProgress: onProgress,
    );

    var updated = session;
    for (final page in importedPages) {
      updated = updated.addPage(page);
    }
    await sessionRepository.saveSession(updated);
    return updated;
  }

  /// Acquires a page from a physical scanner device via WIA.
  Future<ScanSession> acquireScannerPage({
    required ScanSession session,
    required String deviceId,
    required ScanProfile profile,
    void Function(double progress, String status)? onProgress,
  }) async {
    final acquiredFilePath = await deviceProvider.acquirePage(
      deviceId: deviceId,
      profile: profile,
      onProgress: (p) => onProgress?.call(p, 'Đang nhận dữ liệu từ máy quét...'),
    );

    final importedPages = await imageImportService.importImages(
      filePaths: [acquiredFilePath],
      sessionId: session.id,
      startingIndex: session.pageCount,
      onProgress: onProgress,
    );

    var updated = session;
    for (final p in importedPages) {
      updated = updated.addPage(p);
    }
    await sessionRepository.saveSession(updated);
    return updated;
  }

  /// Captures a page using an attached camera/webcam.
  Future<ScanSession> captureCameraPage({
    required ScanSession session,
    String? deviceId,
    void Function(double progress, String status)? onProgress,
  }) async {
    onProgress?.call(0.2, 'Đang chụp ảnh từ camera...');
    final capturePath = await cameraService.captureStill(deviceId: deviceId);

    final importedPages = await imageImportService.importImages(
      filePaths: [capturePath],
      sessionId: session.id,
      startingIndex: session.pageCount,
      onProgress: onProgress,
    );

    var updated = session;
    for (final p in importedPages) {
      updated = updated.addPage(p);
    }
    await sessionRepository.saveSession(updated);
    return updated;
  }

  /// Updates manual/crop quad for a page and regenerates processed preview.
  Future<ScanSession> updatePageCrop({
    required ScanSession session,
    required int pageIndex,
    required DocumentQuad quad,
  }) async {
    if (pageIndex < 0 || pageIndex >= session.pages.length) return session;
    final page = session.pages[pageIndex];

    final origBytes = await File(page.originalPath).readAsBytes();
    final decoded = img.decodeImage(origBytes);
    if (decoded == null) return session;

    // 4-point perspective warp
    img.Image warped = CvDocumentProcessor.warpPerspective(decoded, quad);

    // Apply current enhancement options
    warped = CvDocumentProcessor.enhanceImage(warped, page.processingOptions);

    await File(page.processedPath).writeAsBytes(img.encodePng(warped));

    final updatedPage = page.copyWith(
      manualQuad: quad,
      ocrResult: null, // Reset OCR when geometry changes
      ocrStatus: 'none',
    );

    final updatedSession = session.updatePageAt(pageIndex, updatedPage);
    await sessionRepository.saveSession(updatedSession);
    return updatedSession;
  }

  /// Updates visual enhancement processing options for a page.
  Future<ScanSession> updatePageProcessing({
    required ScanSession session,
    required int pageIndex,
    required ScanProcessingOptions options,
  }) async {
    if (pageIndex < 0 || pageIndex >= session.pages.length) return session;
    final page = session.pages[pageIndex];

    final origBytes = await File(page.originalPath).readAsBytes();
    final decoded = img.decodeImage(origBytes);
    if (decoded == null) return session;

    // Apply active crop quad if exists
    img.Image baseImg = decoded;
    final activeQuad = page.activeQuad;
    if (activeQuad != null &&
        activeQuad.isPlausible(decoded.width.toDouble(), decoded.height.toDouble()) &&
        activeQuad != DocumentQuad.fullImage(decoded.width.toDouble(), decoded.height.toDouble())) {
      baseImg = CvDocumentProcessor.warpPerspective(decoded, activeQuad);
    }

    // Apply enhancement
    final enhanced = CvDocumentProcessor.enhanceImage(baseImg, options);
    await File(page.processedPath).writeAsBytes(img.encodePng(enhanced));

    final updatedPage = page.copyWith(
      processingOptions: options,
      rotation: options.rotationDegrees,
    );

    final updatedSession = session.updatePageAt(pageIndex, updatedPage);
    await sessionRepository.saveSession(updatedSession);
    return updatedSession;
  }

  /// Canonical rotation pipeline: rotates the page image by +90° or -90°.
  Future<ScanSession> rotatePage({
    required ScanSession session,
    required int pageIndex,
    required int deltaDegrees,
  }) async {
    if (pageIndex < 0 || pageIndex >= session.pages.length) return session;
    final page = session.pages[pageIndex];

    final currentRotation = page.rotation;
    final newRotation = ((currentRotation + deltaDegrees) % 360 + 360) % 360;

    return updatePageProcessing(
      session: session,
      pageIndex: pageIndex,
      options: page.processingOptions.copyWith(rotationDegrees: newRotation),
    );
  }

  /// Runs OCR on a specific page with explicit fallback consent.
  Future<ScanSession> runOcrOnPage({
    required ScanSession session,
    required int pageIndex,
    String language = 'vie',
    bool allowFallbackLanguage = false,
  }) async {
    if (pageIndex < 0 || pageIndex >= session.pages.length) return session;
    final page = session.pages[pageIndex];

    final imagePath = File(page.processedPath).existsSync()
        ? page.processedPath
        : page.originalPath;

    // Canonical Rotation Pipeline:
    // Image is already visually normalized on disk in processedPath.
    // Therefore rotationDegrees = 0!
    final ocrResult = await ocrEngine.recognizePage(
      OcrRequest(
        imagePath: imagePath,
        pageNumber: pageIndex + 1,
        language: language,
        rotationDegrees: 0, // Canonical: normalized
        autoRotate: false,
        allowFallbackLanguage: allowFallbackLanguage,
      ),
    );

    final updatedPage = page.copyWith(
      ocrResult: ocrResult,
      ocrStatus: ocrResult.status == OcrStatus.success ? 'done' : 'error',
    );

    final updatedSession = session.updatePageAt(pageIndex, updatedPage);
    await sessionRepository.saveSession(updatedSession);
    return updatedSession;
  }

  /// Exports [session] according to [options] with real Job tracking and Document Library addition.
  Future<String> exportSession({
    required ScanSession session,
    required ScanOutputOptions options,
    void Function(double progress, String status)? onProgress,
  }) async {
    if (session.isEmpty) {
      throw const ScanExportException('Phiên quét rỗng. Không có trang nào để xuất.');
    }

    _isCancelled = false;
    final jobId = const Uuid().v4();
    _activeJobId = jobId;

    // Create real persistent Job
    final jobRecord = JobModel(
      id: jobId,
      jobType: JobType.scanProcess,
      moduleType: 'scanner',
      status: JobStatus.running,
      progress: 0.05,
      inputJson: jsonEncode({'sessionId': session.id, 'format': options.format.name}),
      createdAt: DateTime.now(),
      startedAt: DateTime.now(),
    );
    await jobRepository.createJob(jobRecord);

    final createdFiles = <String>[];
    String finalOutputPath = options.outputPath;

    try {
      // 1. Filter target pages
      final targetPages = options.pageIndices != null
          ? session.pages.where((p) => options.pageIndices!.contains(p.pageIndex)).toList()
          : session.pages;

      // 2. Perform OCR if required for format and not already performed
      final needsOcr = options.enableOcr ||
          options.format == ScanOutputFormat.searchablePdf ||
          options.format == ScanOutputFormat.docx ||
          options.format == ScanOutputFormat.pptx ||
          options.format == ScanOutputFormat.txt;

      var currentSession = session;
      if (needsOcr) {
        for (int i = 0; i < targetPages.length; i++) {
          if (_isCancelled) throw const ScanCancelledException('Tác vụ xuất tài liệu đã bị hủy.');

          final page = targetPages[i];
          final pct = 0.1 + (i / targetPages.length) * 0.4;
          onProgress?.call(pct, 'Đang nhận dạng OCR trang ${i + 1}/${targetPages.length}...');
          await jobRepository.updateProgress(jobId, pct);

          if (page.ocrResult == null || page.ocrStatus != 'done') {
            currentSession = await runOcrOnPage(
              session: currentSession,
              pageIndex: page.pageIndex,
              language: options.ocrLanguage,
              allowFallbackLanguage: options.allowFallbackLanguage,
            );
          }
        }
      }

      if (_isCancelled) throw const ScanCancelledException('Tác vụ xuất tài liệu đã bị hủy.');

      // Refresh target pages with OCR results
      final refreshedPages = options.pageIndices != null
          ? currentSession.pages.where((p) => options.pageIndices!.contains(p.pageIndex)).toList()
          : currentSession.pages;

      // 3. Build target document
      onProgress?.call(0.6, 'Đang xây dựng tệp xuất: ${options.format.label}...');
      await jobRepository.updateProgress(jobId, 0.6);

      switch (options.format) {
        case ScanOutputFormat.searchablePdf:
        case ScanOutputFormat.standardPdf:
          finalOutputPath = await pdfGenerator.generatePdf(
            pages: refreshedPages,
            options: options,
            onProgress: (p, s) {
              onProgress?.call(0.6 + p * 0.35, s);
            },
          );
          createdFiles.add(finalOutputPath);
          break;

        case ScanOutputFormat.docx:
          final docxFile = await _exportToDocx(refreshedPages, options.outputPath);
          finalOutputPath = docxFile.path;
          createdFiles.add(finalOutputPath);
          break;

        case ScanOutputFormat.pptx:
          final pptxFile = await _exportToPptx(refreshedPages, options.outputPath);
          finalOutputPath = pptxFile.path;
          createdFiles.add(finalOutputPath);
          break;

        case ScanOutputFormat.images:
          final exportedImages = await _exportToImages(refreshedPages, options.outputPath);
          createdFiles.addAll(exportedImages);
          if (exportedImages.isNotEmpty) finalOutputPath = exportedImages.first;
          break;

        case ScanOutputFormat.txt:
          final txtFile = await _exportToTxt(refreshedPages, options.outputPath);
          finalOutputPath = txtFile.path;
          createdFiles.add(finalOutputPath);
          break;
      }

      if (_isCancelled) throw const ScanCancelledException('Tác vụ xuất tài liệu đã bị hủy.');

      // 4. Record to Document Library
      final exportedFile = File(finalOutputPath);
      if (exportedFile.existsSync()) {
        final fileSize = await exportedFile.length();
        final fileEntry = FileEntry(
          id: const Uuid().v4(),
          originalName: p.basename(finalOutputPath),
          localPath: finalOutputPath,
          mimeType: options.format == ScanOutputFormat.docx
              ? 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
              : options.format == ScanOutputFormat.pptx
                  ? 'application/vnd.openxmlformats-officedocument.presentationml.presentation'
                  : options.format == ScanOutputFormat.txt
                      ? 'text/plain'
                      : 'application/pdf',
          size: fileSize,
          createdAt: DateTime.now(),
        );
        await fileRepository.addFile(fileEntry);
      }

      // Mark Job completed
      await jobRepository.completeJob(
        jobId,
        outputJson: jsonEncode({'outputPath': finalOutputPath, 'pages': refreshedPages.length}),
      );

      onProgress?.call(1.0, 'Xuất tài liệu thành công!');
      return finalOutputPath;
    } catch (e, st) {
      AppLogger.error('Export failed: $e', e, st);
      // Clean partial created files
      for (final f in createdFiles) {
        try {
          final fileObj = File(f);
          if (fileObj.existsSync()) fileObj.deleteSync();
        } catch (_) {}
      }

      await jobRepository.failJob(
        jobId,
        e.toString(),
      );
      rethrow;
    } finally {
      _activeJobId = null;
    }
  }

  /// Cancels in-progress export or acquisition.
  Future<void> cancelCurrentOperation() async {
    _isCancelled = true;
    await deviceProvider.cancelAcquisition();
    if (_activeJobId != null) {
      await jobRepository.cancelJob(_activeJobId!);
    }
  }

  Future<File> _exportToDocx(List<ScanPage> pages, String outputPath) async {
    final docPages = <DocumentPage>[];

    for (int i = 0; i < pages.length; i++) {
      final page = pages[i];
      final pageNum = i + 1;
      final blocks = <DocumentBlock>[];

      if (page.ocrResult != null && page.ocrResult!.blocks.isNotEmpty) {
        for (final b in page.ocrResult!.blocks) {
          blocks.add(
            ParagraphBlock(
              text: b.text,
              pageNumber: pageNum,
              box: b.box,
            ),
          );
        }
      } else {
        blocks.add(
          ParagraphBlock(
            text: '[Trang $pageNum - Quét ảnh]',
            pageNumber: pageNum,
            box: const OcrBoundingBox(left: 40, top: 40, width: 400, height: 20),
          ),
        );
      }

      docPages.add(DocumentPage(pageNumber: pageNum, blocks: blocks));
    }

    final doc = LayoutDocument(title: 'Tài liệu quét', pages: docPages);
    return await docxGenerator.generate(document: doc, outputPath: outputPath);
  }

  Future<List<String>> _exportToImages(List<ScanPage> pages, String outputDir) async {
    final dir = Directory(outputDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final resultPaths = <String>[];
    for (int i = 0; i < pages.length; i++) {
      final page = pages[i];
      final srcPath = File(page.processedPath).existsSync() ? page.processedPath : page.originalPath;
      final pageNumStr = (i + 1).toString().padLeft(3, '0');
      final destPath = p.join(dir.path, 'document_page_$pageNumStr.png');
      await File(srcPath).copy(destPath);
      resultPaths.add(destPath);
    }
    return resultPaths;
  }

  Future<File> _exportToTxt(List<ScanPage> pages, String outputPath) async {
    final buffer = StringBuffer();
    for (int i = 0; i < pages.length; i++) {
      final page = pages[i];
      buffer.writeln('=== Trang ${i + 1} ===');
      if (page.ocrResult != null) {
        buffer.writeln(page.ocrResult!.fullText);
      } else {
        buffer.writeln('[Không có văn bản OCR]');
      }
      buffer.writeln();
    }

    final file = File(outputPath);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    await file.writeAsString(buffer.toString(), encoding: utf8);
    return file;
  }

  Future<File> _exportToPptx(List<ScanPage> pages, String outputPath) async {
    final docPages = <DocumentPage>[];
    for (int i = 0; i < pages.length; i++) {
      final page = pages[i];
      final pageNum = i + 1;
      final blocks = <DocumentBlock>[];

      if (page.ocrResult != null && page.ocrResult!.blocks.isNotEmpty) {
        for (final b in page.ocrResult!.blocks) {
          blocks.add(
            ParagraphBlock(
              text: b.text,
              pageNumber: pageNum,
              box: b.box,
            ),
          );
        }
      } else {
        blocks.add(
          ParagraphBlock(
            text: '[Trang $pageNum - Bài giảng quét]',
            pageNumber: pageNum,
            box: const OcrBoundingBox(left: 40, top: 40, width: 400, height: 20),
          ),
        );
      }

      docPages.add(DocumentPage(pageNumber: pageNum, blocks: blocks));
    }

    final doc = LayoutDocument(title: 'Bài giảng trình chiếu', pages: docPages);
    return await pptxGenerator.generate(document: doc, outputPath: outputPath);
  }
}
