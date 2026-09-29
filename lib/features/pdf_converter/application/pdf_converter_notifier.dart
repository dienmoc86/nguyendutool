import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../core/filesystem/workspace_manager.dart';
import '../../../core/providers/app_providers.dart';
import '../domain/models/conversion_options.dart';
import '../domain/models/pdf_document_analysis.dart';
import '../infrastructure/vietnamese_ocr_engine.dart';
import 'pdf_converter_service.dart';

/// State of an individual file in the conversion queue.
class PdfQueueItem {
  final String filePath;
  final String fileName;
  final int fileSize;
  final PdfDocumentAnalysis? analysis;
  final double progress;
  final String statusText;
  final bool isProcessing;
  final bool isCompleted;
  final bool isFailed;
  final bool isCancelled;
  final String? docxPath;
  final String? xlsxPath;
  final String? pptxPath;
  final String? errorMessage;

  const PdfQueueItem({
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    this.analysis,
    this.progress = 0.0,
    this.statusText = 'Chờ xử lý',
    this.isProcessing = false,
    this.isCompleted = false,
    this.isFailed = false,
    this.isCancelled = false,
    this.docxPath,
    this.xlsxPath,
    this.pptxPath,
    this.errorMessage,
  });

  PdfQueueItem copyWith({
    String? filePath,
    String? fileName,
    int? fileSize,
    PdfDocumentAnalysis? analysis,
    double? progress,
    String? statusText,
    bool? isProcessing,
    bool? isCompleted,
    bool? isFailed,
    bool? isCancelled,
    String? docxPath,
    String? xlsxPath,
    String? pptxPath,
    String? errorMessage,
  }) {
    return PdfQueueItem(
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      analysis: analysis ?? this.analysis,
      progress: progress ?? this.progress,
      statusText: statusText ?? this.statusText,
      isProcessing: isProcessing ?? this.isProcessing,
      isCompleted: isCompleted ?? this.isCompleted,
      isFailed: isFailed ?? this.isFailed,
      isCancelled: isCancelled ?? this.isCancelled,
      docxPath: docxPath ?? this.docxPath,
      xlsxPath: xlsxPath ?? this.xlsxPath,
      pptxPath: pptxPath ?? this.pptxPath,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Overall state of the PDF Converter module.
class PdfConverterState {
  final List<PdfQueueItem> queue;
  final int activeIndex;
  final ConversionOptions options;
  final bool isRunning;
  final bool isCancelled;
  final String currentStatus;
  final double overallProgress;
  final bool isVietnameseOcrInstalled;
  final String? ocrLanguageWarning;

  const PdfConverterState({
    this.queue = const [],
    this.activeIndex = -1,
    this.options = const ConversionOptions(),
    this.isRunning = false,
    this.isCancelled = false,
    this.currentStatus = 'Sẵn sàng',
    this.overallProgress = 0.0,
    this.isVietnameseOcrInstalled = true,
    this.ocrLanguageWarning,
  });

  PdfConverterState copyWith({
    List<PdfQueueItem>? queue,
    int? activeIndex,
    ConversionOptions? options,
    bool? isRunning,
    bool? isCancelled,
    String? currentStatus,
    double? overallProgress,
    bool? isVietnameseOcrInstalled,
    String? ocrLanguageWarning,
    bool clearWarning = false,
  }) {
    return PdfConverterState(
      queue: queue ?? this.queue,
      activeIndex: activeIndex ?? this.activeIndex,
      options: options ?? this.options,
      isRunning: isRunning ?? this.isRunning,
      isCancelled: isCancelled ?? this.isCancelled,
      currentStatus: currentStatus ?? this.currentStatus,
      overallProgress: overallProgress ?? this.overallProgress,
      isVietnameseOcrInstalled: isVietnameseOcrInstalled ?? this.isVietnameseOcrInstalled,
      ocrLanguageWarning: clearWarning ? null : (ocrLanguageWarning ?? this.ocrLanguageWarning),
    );
  }
}

/// Riverpod StateNotifier for managing the PDF Converter queue and execution.
class PdfConverterNotifier extends StateNotifier<PdfConverterState> {
  final PdfConverterService _service;
  final WorkspaceManager _workspaceManager;
  bool _cancelRequested = false;

  WorkspaceManager get workspaceManager => _workspaceManager;

  PdfConverterNotifier(this._service, this._workspaceManager)
      : super(const PdfConverterState()) {
    checkOcrCapabilities();
  }

  Future<void> checkOcrCapabilities() async {
    final engine = _service.ocrEngine;
    if (engine is VietnameseOcrEngine) {
      await engine.initialize();
      final hasVie = engine.isVietnameseLanguagePackAvailable;
      if (!hasVie && state.options.language == OcrLanguage.vietnamese) {
        state = state.copyWith(
          isVietnameseOcrInstalled: false,
          ocrLanguageWarning: 'Gói nhận dạng tiếng Việt của Windows chưa được cài đặt. Hệ thống sẽ sử dụng động cơ Latinh với độ chính xác cơ bản. Khuyến nghị cài đặt gói Tiếng Việt trong Windows Settings để có độ chính xác cao nhất.',
        );
      } else {
        state = state.copyWith(
          isVietnameseOcrInstalled: hasVie,
          clearWarning: true,
        );
      }
    }
  }

  void updateOptions(ConversionOptions options) {
    String? warning;
    final engine = _service.ocrEngine;
    if (engine is VietnameseOcrEngine && !engine.isVietnameseLanguagePackAvailable && options.language == OcrLanguage.vietnamese) {
      warning = 'Gói nhận dạng tiếng Việt của Windows chưa được cài đặt. Hệ thống sẽ sử dụng động cơ Latinh với độ chính xác cơ bản. Khuyến nghị cài đặt gói Tiếng Việt trong Windows Settings.';
    }
    state = state.copyWith(
      options: options,
      ocrLanguageWarning: warning,
      clearWarning: warning == null,
    );
  }

  void addFiles(List<String> filePaths) {
    final currentPaths = state.queue.map((item) => item.filePath).toSet();
    final newItems = <PdfQueueItem>[];

    for (final path in filePaths) {
      if (currentPaths.contains(path)) continue;
      final file = File(path);
      if (file.existsSync()) {
        newItems.add(
          PdfQueueItem(
            filePath: path,
            fileName: p.basename(path),
            fileSize: file.lengthSync(),
          ),
        );
      }
    }

    if (newItems.isNotEmpty) {
      state = state.copyWith(queue: [...state.queue, ...newItems]);
      _analyzeQueuedFiles(newItems);
    }
  }

  void removeFile(int index) {
    if (state.isRunning && state.activeIndex == index) return;
    final updated = [...state.queue]..removeAt(index);
    state = state.copyWith(queue: updated);
  }

  void clearQueue() {
    if (state.isRunning) return;
    state = state.copyWith(queue: [], activeIndex: -1, overallProgress: 0.0);
  }

  Future<void> _analyzeQueuedFiles(List<PdfQueueItem> items) async {
    for (final item in items) {
      try {
        final analysis = await _service.analyzer.analyze(item.filePath);
        final index = state.queue.indexWhere((q) => q.filePath == item.filePath);
        if (index != -1) {
          final updatedQueue = [...state.queue];
          updatedQueue[index] = updatedQueue[index].copyWith(
            analysis: analysis,
            statusText: '${analysis.totalPages} trang (${analysis.overallClassification.label})',
          );
          state = state.copyWith(queue: updatedQueue);
        }
      } catch (_) {}
    }
  }

  Future<void> startBatchConversion() async {
    if (state.isRunning || state.queue.isEmpty) return;

    _cancelRequested = false;
    state = state.copyWith(
      isRunning: true,
      isCancelled: false,
      currentStatus: 'Đang khởi chạy tiến trình...',
      overallProgress: 0.0,
    );

    for (int i = 0; i < state.queue.length; i++) {
      if (_cancelRequested) break;

      state = state.copyWith(activeIndex: i);
      final currentItem = state.queue[i];

      _updateItemStatus(i, isProcessing: true, statusText: 'Đang chuẩn bị...', progress: 0.0);

      try {
        final result = await _service.convert(
          pdfPath: currentItem.filePath,
          options: state.options,
          onProgress: (current, total, progress, stage) {
            if (_cancelRequested) return;
            _updateItemStatus(
              i,
              isProcessing: true,
              progress: progress,
              statusText: stage,
            );
            final batchProgress = (i + progress) / state.queue.length;
            state = state.copyWith(
              overallProgress: batchProgress,
              currentStatus: 'Đang xử lý ${i + 1}/${state.queue.length}: ${currentItem.fileName}',
            );
          },
          isCancelled: () => _cancelRequested,
        );

        if (_cancelRequested) {
          _updateItemStatus(i, isCancelled: true, statusText: 'Đã hủy', isProcessing: false);
          break;
        }

        if (result.isSuccess) {
          _updateItemStatus(
            i,
            isCompleted: true,
            isProcessing: false,
            progress: 1.0,
            statusText: 'Hoàn thành (${result.durationMs}ms)',
            docxPath: result.docxPath,
            xlsxPath: result.xlsxPath,
            pptxPath: result.pptxPath,
          );
        } else {
          _updateItemStatus(
            i,
            isFailed: true,
            isProcessing: false,
            statusText: 'Thất bại',
            errorMessage: result.errorMessage,
          );
        }
      } catch (e) {
        _updateItemStatus(
          i,
          isFailed: true,
          isProcessing: false,
          statusText: 'Lỗi',
          errorMessage: e.toString(),
        );
      }

      final completedBatch = (i + 1) / state.queue.length;
      state = state.copyWith(overallProgress: completedBatch);
    }

    state = state.copyWith(
      isRunning: false,
      isCancelled: _cancelRequested,
      currentStatus: _cancelRequested ? 'Đã hủy tiến trình' : 'Đã hoàn thành tất cả tác vụ!',
    );
  }

  void cancelConversion() {
    if (!state.isRunning) return;
    _cancelRequested = true;
    state = state.copyWith(
      isRunning: false,
      isCancelled: true,
      currentStatus: 'Đang hủy tiến trình...',
    );
  }

  void cancel() => cancelConversion();

  void _updateItemStatus(
    int index, {
    bool? isProcessing,
    bool? isCompleted,
    bool? isFailed,
    bool? isCancelled,
    double? progress,
    String? statusText,
    String? docxPath,
    String? xlsxPath,
    String? pptxPath,
    String? errorMessage,
  }) {
    if (index < 0 || index >= state.queue.length) return;
    final updatedQueue = [...state.queue];
    final item = updatedQueue[index];
    updatedQueue[index] = item.copyWith(
      isProcessing: isProcessing,
      isCompleted: isCompleted,
      isFailed: isFailed,
      isCancelled: isCancelled,
      progress: progress,
      statusText: statusText,
      docxPath: docxPath,
      xlsxPath: xlsxPath,
      pptxPath: pptxPath,
      errorMessage: errorMessage,
    );
    state = state.copyWith(queue: updatedQueue);
  }
}

/// Service provider for PdfConverterService.
final pdfConverterServiceProvider = Provider<PdfConverterService>((ref) {
  final ws = ref.watch(workspaceManagerProvider);
  final db = ref.watch(databaseProvider);
  return PdfConverterService(workspaceManager: ws, database: db);
});

/// Riverpod StateNotifierProvider for PdfConverterNotifier.
final pdfConverterNotifierProvider =
    StateNotifierProvider<PdfConverterNotifier, PdfConverterState>((ref) {
  final service = ref.watch(pdfConverterServiceProvider);
  final ws = ref.watch(workspaceManagerProvider);
  return PdfConverterNotifier(service, ws);
});
