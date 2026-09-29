import '../domain/models/document_quad.dart';
import '../domain/models/scan_page.dart';
import '../domain/models/scan_profile.dart';
import '../domain/models/scan_session.dart';
import '../domain/models/scanner_device.dart';
import '../infrastructure/windows_camera_service.dart';

enum ScanPreviewMode {
  processed,
  original,
  ocrOverlay,
}

class ScannerState {
  final ScanSession? currentSession;
  final int selectedPageIndex;
  final List<ScannerDevice> availableScanners;
  final ScannerDevice? selectedScanner;
  final List<CameraDeviceInfo> availableCameras;
  final CameraDeviceInfo? selectedCamera;
  final List<ScanProfile> profiles;
  final ScanProfile activeProfile;
  final ScanPreviewMode previewMode;
  final bool isManualCropMode;
  final DocumentQuad? pendingManualQuad;
  final bool isLoading;
  final String? loadingMessage;
  final double progress;
  final String? errorMessage;
  final bool showOcrFallbackDialog;
  final List<ScanSession> unfinishedSessions;
  final bool showRecoveryPrompt;

  const ScannerState({
    this.currentSession,
    this.selectedPageIndex = 0,
    this.availableScanners = const [],
    this.selectedScanner,
    this.availableCameras = const [],
    this.selectedCamera,
    this.profiles = ScanProfile.defaultProfiles,
    this.activeProfile = ScanProfile.documentHighQuality,
    this.previewMode = ScanPreviewMode.processed,
    this.isManualCropMode = false,
    this.pendingManualQuad,
    this.isLoading = false,
    this.loadingMessage,
    this.progress = 0.0,
    this.errorMessage,
    this.showOcrFallbackDialog = false,
    this.unfinishedSessions = const [],
    this.showRecoveryPrompt = false,
  });

  ScanPage? get selectedPage {
    if (currentSession == null || currentSession!.isEmpty) return null;
    if (selectedPageIndex < 0 || selectedPageIndex >= currentSession!.pages.length) return null;
    return currentSession!.pages[selectedPageIndex];
  }

  ScannerState copyWith({
    ScanSession? currentSession,
    int? selectedPageIndex,
    List<ScannerDevice>? availableScanners,
    ScannerDevice? selectedScanner,
    bool clearSelectedScanner = false,
    List<CameraDeviceInfo>? availableCameras,
    CameraDeviceInfo? selectedCamera,
    bool clearSelectedCamera = false,
    List<ScanProfile>? profiles,
    ScanProfile? activeProfile,
    ScanPreviewMode? previewMode,
    bool? isManualCropMode,
    DocumentQuad? pendingManualQuad,
    bool clearPendingManualQuad = false,
    bool? isLoading,
    String? loadingMessage,
    bool clearLoadingMessage = false,
    double? progress,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? showOcrFallbackDialog,
    List<ScanSession>? unfinishedSessions,
    bool? showRecoveryPrompt,
  }) {
    return ScannerState(
      currentSession: currentSession ?? this.currentSession,
      selectedPageIndex: selectedPageIndex ?? this.selectedPageIndex,
      availableScanners: availableScanners ?? this.availableScanners,
      selectedScanner: clearSelectedScanner ? null : (selectedScanner ?? this.selectedScanner),
      availableCameras: availableCameras ?? this.availableCameras,
      selectedCamera: clearSelectedCamera ? null : (selectedCamera ?? this.selectedCamera),
      profiles: profiles ?? this.profiles,
      activeProfile: activeProfile ?? this.activeProfile,
      previewMode: previewMode ?? this.previewMode,
      isManualCropMode: isManualCropMode ?? this.isManualCropMode,
      pendingManualQuad: clearPendingManualQuad ? null : (pendingManualQuad ?? this.pendingManualQuad),
      isLoading: isLoading ?? this.isLoading,
      loadingMessage: clearLoadingMessage ? null : (loadingMessage ?? this.loadingMessage),
      progress: progress ?? this.progress,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      showOcrFallbackDialog: showOcrFallbackDialog ?? this.showOcrFallbackDialog,
      unfinishedSessions: unfinishedSessions ?? this.unfinishedSessions,
      showRecoveryPrompt: showRecoveryPrompt ?? this.showRecoveryPrompt,
    );
  }
}
