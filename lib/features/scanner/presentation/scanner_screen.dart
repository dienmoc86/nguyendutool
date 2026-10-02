import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../app/theme/app_colors.dart';
import '../../../core/filesystem/workspace_manager.dart';
import '../../../core/platform/native_file_dialog.dart';
import '../application/scanner_notifier.dart';
import '../application/scanner_providers.dart';
import '../application/scanner_state.dart';
import 'scanner_export_dialog.dart';
import 'scanner_first_run_view.dart';
import 'scanner_ocr_fallback_dialog.dart';
import 'scanner_preview_viewport.dart';
import 'scanner_thumbnail_strip.dart';
import 'scanner_tools_panel.dart';

/// Document Scanner primary screen replacing the Phase 0 shell.
/// Desktop-first 3-pane architecture with physical scanner discovery, multi-image import,
/// PDF rasterization, 4-corner perspective editing, and searchable PDF export.
class ScannerScreen extends ConsumerWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scannerNotifierProvider);
    final notifier = ref.read(scannerNotifierProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final session = state.currentSession;
    final hasPages = session != null && session.isNotEmpty;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          Column(
            children: [
              // Unfinished Session Recovery Prompt Banner
              if (state.showRecoveryPrompt && state.unfinishedSessions.isNotEmpty)
                _buildRecoveryBanner(context, ref, state, notifier),

              // Main Workspace View (First-run or 3-pane layout)
              Expanded(
                child: !hasPages
                    ? ScannerFirstRunView(
                        availableScanners: state.availableScanners,
                        availableCameras: state.availableCameras,
                        onRefreshDevices: () => notifier.initialize(),
                        onScanClick: () => notifier.scanFromHardware(),
                        onImportImagesClick: () => _pickAndImportImages(context, notifier),
                        onCaptureCameraClick: () => _handleCameraCapture(context, notifier, state),
                        onImportPdfClick: () => _pickAndImportPdf(context, notifier),
                      )
                    : Row(
                        children: [
                          // Left Pane: Thumbnails
                          ScannerThumbnailStrip(
                            pages: session.pages,
                            selectedIndex: state.selectedPageIndex,
                            onSelectPage: (idx) => notifier.selectPage(idx),
                            onDeletePage: (idx) => notifier.deleteCurrentPage(),
                            onDuplicatePage: (idx) => notifier.duplicateCurrentPage(),
                            onReorder: (oldIdx, newIdx) => notifier.reorderPages(oldIdx, newIdx),
                            onAddPage: () => _showAddPageDialog(context, notifier, state),
                          ),

                          // Center Pane: Document Preview Viewport
                          Expanded(
                            child: ScannerPreviewViewport(
                              page: state.selectedPage,
                              previewMode: state.previewMode,
                              isManualCropMode: state.isManualCropMode,
                              pendingManualQuad: state.pendingManualQuad,
                              onManualQuadChanged: (q) => notifier.updatePendingManualQuad(q),
                              onApplyCrop: () => notifier.applyManualCrop(),
                              onCancelCrop: () => notifier.setManualCropMode(false),
                              onPreviewModeChanged: (mode) => notifier.setPreviewMode(mode),
                            ),
                          ),

                          // Right Pane: Tools & Adjustments
                          ScannerToolsPanel(
                            page: state.selectedPage,
                            profiles: state.profiles,
                            activeProfile: state.activeProfile,
                            isManualCropMode: state.isManualCropMode,
                            onSelectProfile: (prof) => notifier.selectProfile(prof),
                            onToggleManualCrop: (en) => notifier.setManualCropMode(en),
                            onRotate: (deg) => notifier.rotateCurrentPage(deg),
                            onUpdateProcessing: (opts) => notifier.updateCurrentPageEnhancement(opts),
                            onTriggerOcr: () => notifier.runOcrOnCurrentPage(),
                            onDeleteCurrentPage: () => notifier.deleteCurrentPage(),
                          ),
                        ],
                      ),
              ),

              // Bottom Action Bar
              _buildBottomActionBar(context, notifier, state, hasPages),
            ],
          ),

          // Loading Progress Overlay
          if (state.isLoading)
            _buildLoadingOverlay(context, state, notifier),

          // Explicit OCR Fallback Dialog (Entry Remediation 0.A)
          if (state.showOcrFallbackDialog)
            ScannerOcrFallbackDialog(
              onInstallGuide: () {
                notifier.dismissOcrFallbackDialog();
                _showWindowsLanguageGuide(context);
              },
              onContinueWithExisting: () {
                notifier.dismissOcrFallbackDialog();
                // Continue with existing available OCR engine
                notifier.runOcrOnCurrentPage(language: 'vie', allowFallbackLanguage: true);
              },
              onCancel: () {
                notifier.dismissOcrFallbackDialog();
              },
            ),

          // Error Toast
          if (state.errorMessage != null)
            _buildErrorToast(context, state.errorMessage!, notifier),
        ],
      ),
    );
  }

  Widget _buildRecoveryBanner(
    BuildContext context,
    WidgetRef ref,
    ScannerState state,
    ScannerNotifier notifier,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: Colors.blue.shade800,
      child: Row(
        children: [
          const Icon(Icons.history_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tìm thấy ${state.unfinishedSessions.length} phiên quét chưa hoàn thành. Bạn có muốn khôi phục phiên gần nhất?',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          FilledButton.tonal(
            onPressed: () => notifier.recoverSession(state.unfinishedSessions.first),
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.blue.shade900),
            child: const Text('Khôi phục'),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 18),
            onPressed: () => notifier.dismissRecoveryPrompt(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(
    BuildContext context,
    ScannerNotifier notifier,
    ScannerState state,
    bool hasPages,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          // Add Page Dropdown
          FilledButton.tonalIcon(
            onPressed: () => _showAddPageDialog(context, notifier, state),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Thêm trang'),
          ),
          const SizedBox(width: 10),

          // Scan Hardware Button
          FilledButton.icon(
            onPressed: () => notifier.scanFromHardware(),
            icon: const Icon(Icons.scanner_rounded, size: 18),
            label: Text(
              state.availableScanners.isNotEmpty
                  ? 'Quét từ ${state.availableScanners.first.name}'
                  : 'Quét (WIA)',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: state.availableScanners.isNotEmpty ? AppColors.moduleScanner : Colors.grey,
            ),
          ),
          const SizedBox(width: 10),

          // Camera Capture Button
          OutlinedButton.icon(
            onPressed: () => _handleCameraCapture(context, notifier, state),
            icon: const Icon(Icons.camera_alt_outlined, size: 18),
            label: const Text('Chụp Camera / ĐT'),
          ),
          const SizedBox(width: 10),

          // Import Image Button
          OutlinedButton.icon(
            onPressed: () => _pickAndImportImages(context, notifier),
            icon: const Icon(Icons.photo_outlined, size: 18),
            label: const Text('Nhập ảnh'),
          ),
          const SizedBox(width: 10),

          // Import PDF Button
          OutlinedButton.icon(
            onPressed: () => _pickAndImportPdf(context, notifier),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const Text('Nhập PDF'),
          ),

          const Spacer(),

          // Export Button
          FilledButton.icon(
            onPressed: hasPages ? () => _showExportDialog(context, notifier, state) : null,
            icon: const Icon(Icons.file_download_rounded, size: 18),
            label: const Text('Xuất tài liệu (Export)'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay(
    BuildContext context,
    ScannerState state,
    ScannerNotifier notifier,
  ) {
    return Container(
      color: Colors.black.withOpacity(0.55),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E293B)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 8)),
            ],
          ),
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                state.loadingMessage ?? 'Đang xử lý...',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              if (state.progress > 0.0) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(value: state.progress),
                const SizedBox(height: 6),
                Text(
                  '${(state.progress * 100).toInt()}%',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () => notifier.cancelOperation(),
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: const Text('Hủy tác vụ'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorToast(BuildContext context, String message, ScannerNotifier notifier) {
    return Positioned(
      bottom: 70,
      left: 30,
      right: 30,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(10),
        color: Colors.red.shade700,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                onPressed: () => notifier.clearError(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddPageDialog(BuildContext context, ScannerNotifier notifier, ScannerState state) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.scanner_rounded, color: AppColors.moduleScanner),
                title: const Text('Quét trang từ máy quét WIA'),
                onTap: () {
                  Navigator.pop(ctx);
                  notifier.scanFromHardware();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Colors.purple),
                title: const Text('Chụp từ Camera / Điện thoại'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleCameraCapture(context, notifier, state);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Colors.green),
                title: const Text('Nhập tệp hình ảnh từ điện thoại / máy tính'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndImportImages(context, notifier);
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_rounded, color: Colors.orange),
                title: const Text('Nhập tài liệu PDF'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndImportPdf(context, notifier);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleCameraCapture(BuildContext context, ScannerNotifier notifier, ScannerState state) {
    if (state.availableCameras.isEmpty) {
      _showCameraConnectHelpDialog(context, notifier);
    } else if (state.availableCameras.length == 1) {
      notifier.captureFromCamera();
    } else {
      _showCameraPickerDialog(context, notifier, state);
    }
  }

  void _showCameraPickerDialog(BuildContext context, ScannerNotifier notifier, ScannerState state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.camera_alt_rounded, color: Color(0xFF0284C7)),
            SizedBox(width: 10),
            Text('Chọn Camera / Điện thoại'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chọn thiết bị bạn muốn dùng để chụp quét tài liệu:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            for (final cam in state.availableCameras)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: Icon(
                  cam.name.toLowerCase().contains('droidcam') ||
                          cam.name.toLowerCase().contains('iriun') ||
                          cam.name.toLowerCase().contains('phone')
                      ? Icons.phone_android_rounded
                      : Icons.videocam_rounded,
                  color: AppColors.primary,
                ),
                title: Text(cam.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  cam.manufacturer ?? 'Camera / Điện thoại',
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  notifier.selectCamera(cam);
                  notifier.captureFromCamera();
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
        ],
      ),
    );
  }

  void _showCameraConnectHelpDialog(BuildContext context, ScannerNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.phone_android_rounded, color: Color(0xFF8B5CF6)),
            SizedBox(width: 10),
            Expanded(child: Text('Kết nối Camera hoặc Điện thoại')),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chưa phát hiện Camera hoặc Webcam nào trên máy tính. Để quét tài liệu bằng điện thoại:',
                style: TextStyle(fontSize: 13.5, height: 1.4),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📱 Cách 1: Dùng camera điện thoại độ nét cao (Khuyên dùng)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '1. Cài app DroidCam hoặc Iriun Webcam (miễn phí) trên cả điện thoại và máy tính.\n'
                      '2. Cắm dây cáp USB hoặc kết nối cùng mạng Wi-Fi với máy tính.\n'
                      '3. Mở app trên điện thoại, máy tính sẽ nhận điện thoại làm camera chụp quét tài liệu cực nét.',
                      style: TextStyle(fontSize: 12.5, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withOpacity(0.2)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📂 Cách 2: Cắm cáp USB chọn ảnh trực tiếp từ điện thoại',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Chụp sẵn ảnh tài liệu trên điện thoại, cắm cáp sạc USB vào máy tính, chọn "Truyền tệp", rồi bấm nút "Nhập ảnh từ ĐT / Máy tính" bên dưới để đưa ảnh vào số hóa ngay.',
                      style: TextStyle(fontSize: 12.5, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              notifier.initialize();
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Quét lại thiết bị'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _pickAndImportImages(context, notifier);
            },
            icon: const Icon(Icons.photo_library_rounded, size: 16),
            label: const Text('Nhập ảnh từ ĐT / Máy tính'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
          ),
        ],
      ),
    );
  }

  void _pickAndImportImages(BuildContext context, ScannerNotifier notifier) async {
    final res = await NativeFileDialog.pickImageFiles(multiSelect: true);
    if (res.isSelected && res.paths.isNotEmpty) {
      notifier.importImages(res.paths);
    }
  }

  void _pickAndImportPdf(BuildContext context, ScannerNotifier notifier) async {
    final res = await NativeFileDialog.pickPdfFiles(multiSelect: false);
    if (res.isSelected && res.paths.isNotEmpty) {
      notifier.importPdf(res.paths.first);
    }
  }

  void _showExportDialog(BuildContext context, ScannerNotifier notifier, ScannerState state) {
    final session = state.currentSession;
    if (session == null || session.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => ScannerExportDialog(
        totalPages: session.pageCount,
        currentPageIndex: state.selectedPageIndex,
        onExport: (options) async {
          final outPath = await notifier.exportSession(options);
          if (outPath != null && context.mounted) {
            showDialog(
              context: context,
              builder: (dCtx) => AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
                    SizedBox(width: 10),
                    Text('Xuất tài liệu thành công!'),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tệp tài liệu: ${p.basename(outPath)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 6),
                    Text(outPath, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                actions: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.folder_open_rounded, size: 16),
                    label: const Text('Mở thư mục'),
                    onPressed: () {
                      Navigator.pop(dCtx);
                      WorkspaceManager.openContainingFolder(outPath);
                    },
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Mở tệp ngay'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () {
                      Navigator.pop(dCtx);
                      WorkspaceManager.openFile(outPath);
                    },
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  void _showWindowsLanguageGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hướng dẫn cài gói OCR tiếng Việt'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Để cài đặt gói OCR Tiếng Việt trên Windows 10/11:\n\n'
              '1. Mở Cài đặt Windows (Settings) -> Time & Language -> Language.\n'
              '2. Nhấn "Add a language" và tìm chọn "Tiếng Việt" (Vietnamese).\n'
              '3. Tích chọn "Basic typing" và "Optical Character Recognition".\n'
              '4. Chờ Windows hoàn tất tải về gói nhận dạng chữ viết.\n'
              '5. Khởi động lại phần mềm để áp dụng gói tiếng Việt mới.',
              style: TextStyle(height: 1.4),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }
}
