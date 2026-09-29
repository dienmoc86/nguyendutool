import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/logging/app_logger.dart';
import '../domain/models/document_quad.dart';
import '../domain/models/scan_options.dart';
import '../domain/models/scan_profile.dart';
import '../domain/models/scan_session.dart';
import '../domain/models/scanner_device.dart';
import '../infrastructure/windows_camera_service.dart';
import 'scanner_service.dart';
import 'scanner_state.dart';

class ScannerNotifier extends StateNotifier<ScannerState> {
  final ScannerService service;

  ScannerNotifier(this.service) : super(const ScannerState()) {
    initialize();
  }

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, loadingMessage: 'Đang khởi tạo phân hệ máy quét...');
    try {
      final scanners = await service.deviceProvider.getAvailableScanners();
      final cameras = await service.cameraService.getAvailableCameras();
      final unfinished = await service.sessionRepository.getUnfinishedSessions();

      state = state.copyWith(
        availableScanners: scanners,
        selectedScanner: scanners.isNotEmpty ? scanners.first : null,
        availableCameras: cameras,
        selectedCamera: cameras.isNotEmpty ? cameras.first : null,
        unfinishedSessions: unfinished,
        showRecoveryPrompt: unfinished.isNotEmpty,
        isLoading: false,
        clearLoadingMessage: true,
      );
    } catch (e, st) {
      AppLogger.error('ScannerNotifier initialization error: $e', e, st);
      state = state.copyWith(
        isLoading: false,
        clearLoadingMessage: true,
        errorMessage: 'Lỗi khởi tạo thiết bị: $e',
      );
    }
  }

  void startNewSession(ScanSource source, [String? name]) {
    final newSession = service.createSession(source, name);
    state = state.copyWith(
      currentSession: newSession,
      selectedPageIndex: 0,
      showRecoveryPrompt: false,
      clearErrorMessage: true,
    );
  }

  void recoverSession(ScanSession session) {
    state = state.copyWith(
      currentSession: session,
      selectedPageIndex: 0,
      showRecoveryPrompt: false,
      clearErrorMessage: true,
    );
  }

  void dismissRecoveryPrompt() {
    state = state.copyWith(showRecoveryPrompt: false);
  }

  void selectScanner(ScannerDevice scanner) {
    state = state.copyWith(selectedScanner: scanner);
  }

  void selectCamera(CameraDeviceInfo camera) {
    state = state.copyWith(selectedCamera: camera);
  }

  void selectProfile(ScanProfile profile) {
    state = state.copyWith(activeProfile: profile);
  }

  void selectPage(int index) {
    if (state.currentSession == null) return;
    if (index >= 0 && index < state.currentSession!.pages.length) {
      state = state.copyWith(
        selectedPageIndex: index,
        isManualCropMode: false,
        clearPendingManualQuad: true,
      );
    }
  }

  void setPreviewMode(ScanPreviewMode mode) {
    state = state.copyWith(previewMode: mode);
  }

  void setManualCropMode(bool enabled) {
    final page = state.selectedPage;
    final quad = enabled ? (page?.manualQuad ?? page?.detectedQuad) : null;
    state = state.copyWith(
      isManualCropMode: enabled,
      pendingManualQuad: quad,
    );
  }

  void updatePendingManualQuad(DocumentQuad quad) {
    state = state.copyWith(pendingManualQuad: quad);
  }

  Future<void> applyManualCrop() async {
    final session = state.currentSession;
    final quad = state.pendingManualQuad;
    if (session == null || quad == null) return;

    state = state.copyWith(isLoading: true, loadingMessage: 'Đang áp dụng hiệu chỉnh góc...');
    try {
      final updated = await service.updatePageCrop(
        session: session,
        pageIndex: state.selectedPageIndex,
        quad: quad,
      );
      state = state.copyWith(
        currentSession: updated,
        isManualCropMode: false,
        clearPendingManualQuad: true,
        isLoading: false,
        clearLoadingMessage: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        clearLoadingMessage: true,
        errorMessage: 'Lỗi căn chỉnh góc: $e',
      );
    }
  }

  Future<void> importImages(List<String> filePaths) async {
    var session = state.currentSession ?? service.createSession(ScanSource.imageImport);
    state = state.copyWith(isLoading: true, loadingMessage: 'Đang nhập tệp ảnh...');

    try {
      final updated = await service.importImages(
        session: session,
        filePaths: filePaths,
        onProgress: (p, s) {
          state = state.copyWith(progress: p, loadingMessage: s);
        },
      );
      state = state.copyWith(
        currentSession: updated,
        selectedPageIndex: updated.pages.length - 1,
        isLoading: false,
        clearLoadingMessage: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        clearLoadingMessage: true,
        errorMessage: 'Không thể nhập tệp ảnh: $e',
      );
    }
  }

  Future<void> importPdf(String pdfPath) async {
    var session = state.currentSession ?? service.createSession(ScanSource.pdfImport);
    state = state.copyWith(isLoading: true, loadingMessage: 'Đang nhập tài liệu PDF...');

    try {
      final updated = await service.importPdf(
        session: session,
        pdfPath: pdfPath,
        onProgress: (p, s) {
          state = state.copyWith(progress: p, loadingMessage: s);
        },
      );
      state = state.copyWith(
        currentSession: updated,
        selectedPageIndex: 0,
        isLoading: false,
        clearLoadingMessage: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        clearLoadingMessage: true,
        errorMessage: 'Không thể nhập tệp PDF: $e',
      );
    }
  }

  Future<void> scanFromHardware() async {
    final scanner = state.selectedScanner;
    if (scanner == null) {
      state = state.copyWith(errorMessage: 'Không tìm thấy máy scan hoặc chưa chọn thiết bị.');
      return;
    }

    var session = state.currentSession ?? service.createSession(ScanSource.physicalScanner);
    state = state.copyWith(isLoading: true, loadingMessage: 'Đang kết nối máy quét...');

    try {
      final updated = await service.acquireScannerPage(
        session: session,
        deviceId: scanner.id,
        profile: state.activeProfile,
        onProgress: (p, s) {
          state = state.copyWith(progress: p, loadingMessage: s);
        },
      );
      state = state.copyWith(
        currentSession: updated,
        selectedPageIndex: updated.pages.length - 1,
        isLoading: false,
        clearLoadingMessage: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        clearLoadingMessage: true,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> captureFromCamera() async {
    var session = state.currentSession ?? service.createSession(ScanSource.camera);
    state = state.copyWith(isLoading: true, loadingMessage: 'Đang chụp từ camera...');

    try {
      final updated = await service.captureCameraPage(
        session: session,
        deviceId: state.selectedCamera?.id,
        onProgress: (p, s) {
          state = state.copyWith(progress: p, loadingMessage: s);
        },
      );
      state = state.copyWith(
        currentSession: updated,
        selectedPageIndex: updated.pages.length - 1,
        isLoading: false,
        clearLoadingMessage: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        clearLoadingMessage: true,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> rotateCurrentPage(int deltaDegrees) async {
    final session = state.currentSession;
    if (session == null || session.isEmpty) return;

    try {
      final updated = await service.rotatePage(
        session: session,
        pageIndex: state.selectedPageIndex,
        deltaDegrees: deltaDegrees,
      );
      state = state.copyWith(currentSession: updated);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Lỗi xoay trang: $e');
    }
  }

  Future<void> updateCurrentPageEnhancement(ScanProcessingOptions options) async {
    final session = state.currentSession;
    if (session == null || session.isEmpty) return;

    try {
      final updated = await service.updatePageProcessing(
        session: session,
        pageIndex: state.selectedPageIndex,
        options: options,
      );
      state = state.copyWith(currentSession: updated);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Lỗi xử lý ảnh: $e');
    }
  }

  void deleteCurrentPage() {
    final session = state.currentSession;
    if (session == null || session.isEmpty) return;

    final updated = session.removePageAt(state.selectedPageIndex);
    final newIndex = state.selectedPageIndex >= updated.pages.length
        ? (updated.pages.isNotEmpty ? updated.pages.length - 1 : 0)
        : state.selectedPageIndex;

    state = state.copyWith(
      currentSession: updated,
      selectedPageIndex: newIndex,
    );
    service.sessionRepository.saveSession(updated);
  }

  void duplicateCurrentPage() {
    final session = state.currentSession;
    if (session == null || session.isEmpty) return;

    final updated = session.duplicatePageAt(state.selectedPageIndex, DateTime.now().millisecondsSinceEpoch.toString());
    state = state.copyWith(
      currentSession: updated,
      selectedPageIndex: state.selectedPageIndex + 1,
    );
    service.sessionRepository.saveSession(updated);
  }

  void reorderPages(int oldIndex, int newIndex) {
    final session = state.currentSession;
    if (session == null || session.isEmpty) return;

    final updated = session.reorderPage(oldIndex, newIndex);
    state = state.copyWith(
      currentSession: updated,
      selectedPageIndex: newIndex,
    );
    service.sessionRepository.saveSession(updated);
  }

  Future<void> runOcrOnCurrentPage({String language = 'vie', bool allowFallbackLanguage = false}) async {
    final session = state.currentSession;
    if (session == null || session.isEmpty) return;

    state = state.copyWith(isLoading: true, loadingMessage: 'Đang nhận dạng văn bản OCR...');
    try {
      final updated = await service.runOcrOnPage(
        session: session,
        pageIndex: state.selectedPageIndex,
        language: language,
        allowFallbackLanguage: allowFallbackLanguage,
      );
      state = state.copyWith(
        currentSession: updated,
        previewMode: ScanPreviewMode.ocrOverlay,
        isLoading: false,
        clearLoadingMessage: true,
      );
    } catch (e) {
      if (e.toString().contains('ERROR_LANGUAGE_UNAVAILABLE') ||
          e.toString().contains('chưa được cài đặt')) {
        state = state.copyWith(
          isLoading: false,
          clearLoadingMessage: true,
          showOcrFallbackDialog: true,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          clearLoadingMessage: true,
          errorMessage: 'Lỗi OCR: $e',
        );
      }
    }
  }

  void dismissOcrFallbackDialog() {
    state = state.copyWith(showOcrFallbackDialog: false);
  }

  Future<String?> exportSession(ScanOutputOptions options) async {
    final session = state.currentSession;
    if (session == null || session.isEmpty) {
      state = state.copyWith(errorMessage: 'Không có trang nào trong phiên quét để xuất.');
      return null;
    }

    state = state.copyWith(isLoading: true, loadingMessage: 'Đang chuẩn bị xuất tài liệu...');
    try {
      final resultPath = await service.exportSession(
        session: session,
        options: options,
        onProgress: (p, s) {
          state = state.copyWith(progress: p, loadingMessage: s);
        },
      );
      state = state.copyWith(isLoading: false, clearLoadingMessage: true);
      return resultPath;
    } catch (e) {
      if (e.toString().contains('ERROR_LANGUAGE_UNAVAILABLE') ||
          e.toString().contains('chưa được cài đặt')) {
        state = state.copyWith(
          isLoading: false,
          clearLoadingMessage: true,
          showOcrFallbackDialog: true,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          clearLoadingMessage: true,
          errorMessage: 'Lỗi xuất tài liệu: $e',
        );
      }
      return null;
    }
  }

  Future<void> cancelOperation() async {
    await service.cancelCurrentOperation();
    state = state.copyWith(
      isLoading: false,
      clearLoadingMessage: true,
      errorMessage: 'Tác vụ đã bị hủy.',
    );
  }

  void clearError() {
    state = state.copyWith(clearErrorMessage: true);
  }
}
