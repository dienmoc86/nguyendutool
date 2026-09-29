import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../app/theme/app_colors.dart';
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
                        onScanClick: () => notifier.scanFromHardware(),
                        onImportImagesClick: () => _pickAndImportImages(context, notifier),
                        onCaptureCameraClick: () => notifier.captureFromCamera(),
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
                            onAddPage: () => _showAddPageDialog(context, notifier),
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
            onPressed: () => _showAddPageDialog(context, notifier),
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
            onPressed: () => notifier.captureFromCamera(),
            icon: const Icon(Icons.camera_alt_outlined, size: 18),
            label: const Text('Chụp Camera'),
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

  void _showAddPageDialog(BuildContext context, ScannerNotifier notifier) {
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
                title: const Text('Chụp từ Camera / Webcam'),
                onTap: () {
                  Navigator.pop(ctx);
                  notifier.captureFromCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Colors.green),
                title: const Text('Nhập tệp hình ảnh (JPG, PNG, TIFF, ...)'),
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Xuất tài liệu thành công: ${p.basename(outPath)}'),
                backgroundColor: Colors.green,
                action: SnackBarAction(
                  label: 'Mở thư mục',
                  textColor: Colors.white,
                  onPressed: () {
                    Process.run('explorer.exe', ['/select,', outPath]);
                  },
                ),
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
