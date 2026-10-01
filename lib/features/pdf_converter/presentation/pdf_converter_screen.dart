import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/filesystem/workspace_manager.dart';
import '../../../core/platform/native_drop_handler.dart';
import '../../../core/platform/native_file_dialog.dart';
import '../../../core/providers/app_providers.dart';
import '../application/pdf_converter_notifier.dart';
import '../domain/models/conversion_options.dart';
import '../domain/models/pdf_document_analysis.dart';

/// Full production-grade PDF to Word / Excel & Local OCR Screen.
class PdfConverterScreen extends ConsumerStatefulWidget {
  const PdfConverterScreen({super.key});

  @override
  ConsumerState<PdfConverterScreen> createState() => _PdfConverterScreenState();
}

class _PdfConverterScreenState extends ConsumerState<PdfConverterScreen> {
  @override
  void initState() {
    super.initState();
    NativeDropHandler.initialize();
    NativeDropHandler.addListener(_onFilesDropped);
  }

  @override
  void dispose() {
    NativeDropHandler.removeListener(_onFilesDropped);
    super.dispose();
  }

  void _onFilesDropped(DropValidationResult result) {
    if (!mounted) return;
    final notifier = ref.read(pdfConverterNotifierProvider.notifier);

    if (result.hasValidFiles) {
      notifier.addFiles(result.validPdfFiles);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã nhận ${result.validPdfFiles.length} tệp PDF từ Windows Explorer.'),
          backgroundColor: AppColors.modulePdf,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    if (result.hasRejections) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessages.join('\n')),
          backgroundColor: Colors.amber.shade900,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(pdfConverterNotifierProvider);
    final notifier = ref.read(pdfConverterNotifierProvider.notifier);
    final workspace = ref.watch(workspaceManagerProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.modulePdf.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.modulePdf, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chuyển đổi PDF sang Word / Excel',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Chuyên biệt cho Nhà trường & Giáo viên: Soạn Giáo án (.docx), Sổ điểm (.xlsx), Bài giảng PowerPoint (.pptx) chuẩn ECMA-376 và OCR tiếng Việt cục bộ.',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => WorkspaceManager.openFolder(workspace.exportsDir.path),
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: const Text('Mở thư mục xuất'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    elevation: 0,
                    side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Drop zone / Pick File area
            _buildFilePickerArea(context, isDark, notifier),
            const SizedBox(height: 24),

            // Conversion Options Panel
            _buildOptionsCard(context, isDark, state, notifier),
            const SizedBox(height: 24),

            // Progress / Status Bar
            if (state.isRunning || state.overallProgress > 0)
              _buildProgressCard(context, isDark, state, notifier),

            if (state.isRunning || state.overallProgress > 0)
              const SizedBox(height: 24),

            // File Queue List
            _buildQueueCard(context, isDark, state, notifier),
          ],
        ),
      ),
    );
  }

  Widget _buildFilePickerArea(BuildContext context, bool isDark, PdfConverterNotifier notifier) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.modulePdf.withOpacity(0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.modulePdf.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cloud_upload_rounded, color: AppColors.modulePdf, size: 40),
          ),
          const SizedBox(height: 16),
          const Text(
            'Chọn hoặc kéo thả các tệp PDF vào đây',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Hỗ trợ tài liệu văn bản thông thường, tài liệu scan hình ảnh, bảng biểu, hợp đồng tiếng Việt...',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 20),
            ElevatedButton.icon(
            onPressed: () async {
              final result = await NativeFileDialog.pickPdfFiles(multiSelect: true);
              if (result.isSelected) {
                notifier.addFiles(result.paths);
              } else if (result.isError) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result.errorMessage ?? 'Lỗi khi mở hộp thoại chọn tệp'),
                      backgroundColor: Colors.red.shade800,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.file_open_rounded, size: 18),
            label: const Text('Chọn tệp PDF từ máy tính'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.modulePdf,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsCard(
    BuildContext context,
    bool isDark,
    PdfConverterState state,
    PdfConverterNotifier notifier,
  ) {
    final options = state.options;
    final isRunning = state.isRunning;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune_rounded, size: 20, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('Cấu hình chuyển đổi & Nhận diện OCR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              if (!isRunning)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.school_rounded, size: 14, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text(
                        'Chế độ Nhà trường & Giáo viên',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Teacher quick presets
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.description_rounded, size: 16, color: Colors.blue),
                label: const Text('📘 Soạn Giáo án Word', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                backgroundColor: options.format == OutputFormat.docx ? Colors.blue.withOpacity(0.18) : null,
                side: BorderSide(
                  color: options.format == OutputFormat.docx ? Colors.blue : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                onPressed: isRunning
                    ? null
                    : () {
                        notifier.updateOptions(
                          options.copyWith(
                            format: OutputFormat.docx,
                            detectTables: true,
                            autoDeskew: true,
                            autoEnhance: true,
                          ),
                        );
                      },
              ),
              ActionChip(
                avatar: const Icon(Icons.table_chart_rounded, size: 16, color: Colors.green),
                label: const Text('📊 Sổ điểm & Bảng tính Excel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                backgroundColor: options.format == OutputFormat.xlsx ? Colors.green.withOpacity(0.18) : null,
                side: BorderSide(
                  color: options.format == OutputFormat.xlsx ? Colors.green : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                onPressed: isRunning
                    ? null
                    : () {
                        notifier.updateOptions(
                          options.copyWith(
                            format: OutputFormat.xlsx,
                            detectTables: true,
                          ),
                        );
                      },
              ),
              ActionChip(
                avatar: const Icon(Icons.slideshow_rounded, size: 16, color: Colors.orange),
                label: const Text('🖥️ Bài giảng PowerPoint (.pptx)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                backgroundColor: options.format == OutputFormat.pptx ? Colors.orange.withOpacity(0.18) : null,
                side: BorderSide(
                  color: options.format == OutputFormat.pptx ? Colors.orange : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                onPressed: isRunning
                    ? null
                    : () {
                        notifier.updateOptions(
                          options.copyWith(
                            format: OutputFormat.pptx,
                            autoEnhance: true,
                            dpi: DpiPreset.ultra300,
                          ),
                        );
                      },
              ),
              ActionChip(
                avatar: const Icon(Icons.all_inclusive_rounded, size: 16, color: Colors.purple),
                label: const Text('📦 Xuất trọn bộ (Word, Excel, PPTX)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                backgroundColor: options.format == OutputFormat.all ? Colors.purple.withOpacity(0.18) : null,
                side: BorderSide(
                  color: options.format == OutputFormat.all ? Colors.purple : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                onPressed: isRunning
                    ? null
                    : () {
                        notifier.updateOptions(
                          options.copyWith(
                            format: OutputFormat.all,
                            detectTables: true,
                            autoEnhance: true,
                          ),
                        );
                      },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Output Format
              DropdownButtonHideUnderline(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Định dạng xuất:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: DropdownButton<OutputFormat>(
                        value: options.format,
                        isDense: true,
                        items: OutputFormat.values.map((f) {
                          return DropdownMenuItem(value: f, child: Text(f.label));
                        }).toList(),
                        onChanged: isRunning
                            ? null
                            : (val) {
                                if (val != null) {
                                  notifier.updateOptions(options.copyWith(format: val));
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),

              // OCR Language
              DropdownButtonHideUnderline(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ngôn ngữ OCR:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: DropdownButton<OcrLanguage>(
                        value: options.language,
                        isDense: true,
                        items: OcrLanguage.values.map((l) {
                          return DropdownMenuItem(value: l, child: Text(l.label));
                        }).toList(),
                        onChanged: isRunning
                            ? null
                            : (val) {
                                if (val != null) {
                                  notifier.updateOptions(options.copyWith(language: val));
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),

              // DPI Resolution Preset
              DropdownButtonHideUnderline(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Chất lượng kết xuất (DPI):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: DropdownButton<DpiPreset>(
                        value: options.dpi,
                        isDense: true,
                        items: DpiPreset.values.map((d) {
                          return DropdownMenuItem(value: d, child: Text(d.label));
                        }).toList(),
                        onChanged: isRunning
                            ? null
                            : (val) {
                                if (val != null) {
                                  notifier.updateOptions(options.copyWith(dpi: val));
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),

              // Table detection toggle
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: options.detectTables,
                    onChanged: isRunning
                        ? null
                        : (val) {
                            if (val != null) {
                              notifier.updateOptions(options.copyWith(detectTables: val));
                            }
                          },
                  ),
                  const Text('Tái cấu trúc bảng biểu', style: TextStyle(fontSize: 13)),
                ],
              ),

              // Auto Deskew toggle
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: options.autoDeskew,
                    onChanged: isRunning
                        ? null
                        : (val) {
                            if (val != null) {
                              notifier.updateOptions(options.copyWith(autoDeskew: val));
                            }
                          },
                  ),
                  const Text('Tự động nắn thẳng trang (Deskew)', style: TextStyle(fontSize: 13)),
                ],
              ),

              // Auto Enhance toggle (connected to ImagePreprocessor)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: options.autoEnhance,
                    onChanged: isRunning
                        ? null
                        : (val) {
                            if (val != null) {
                              notifier.updateOptions(options.copyWith(autoEnhance: val));
                            }
                          },
                  ),
                  const Text('Khử nhiễu & Cân bằng tương phản ảnh', style: TextStyle(fontSize: 13)),
                ],
              ),
            ],
          ),

          // Honest OCR language warning banner
          if (state.ocrLanguageWarning != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      state.ocrLanguageWarning!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressCard(
    BuildContext context,
    bool isDark,
    PdfConverterState state,
    PdfConverterNotifier notifier,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (state.isRunning)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  else if (state.isCancelled)
                    const Icon(Icons.cancel_rounded, color: Colors.orange, size: 20)
                  else
                    const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    state.currentStatus,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (state.isRunning)
                OutlinedButton.icon(
                  onPressed: () => notifier.cancel(),
                  icon: const Icon(Icons.close_rounded, size: 16, color: Colors.red),
                  label: const Text('Hủy tiến trình', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: state.overallProgress,
              minHeight: 10,
              backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              color: state.isCancelled ? Colors.orange : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueCard(
    BuildContext context,
    bool isDark,
    PdfConverterState state,
    PdfConverterNotifier notifier,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Danh sách tệp chờ xử lý (${state.queue.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    if (state.queue.isNotEmpty && !state.isRunning)
                      TextButton.icon(
                        onPressed: () => notifier.clearQueue(),
                        icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                        label: const Text('Xóa tất cả'),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                      ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: (state.queue.isEmpty || state.isRunning)
                          ? null
                          : () => notifier.startBatchConversion(),
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: const Text('Bắt đầu chuyển đổi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (state.queue.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'Chưa có tệp PDF nào trong hàng đợi. Nhấn nút chọn tệp bên trên để thêm tệp.',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.queue.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = state.queue[index];
                return _buildQueueItemTile(context, isDark, item, index, notifier);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildQueueItemTile(
    BuildContext context,
    bool isDark,
    PdfQueueItem item,
    int index,
    PdfConverterNotifier notifier,
  ) {
    final sizeKb = (item.fileSize / 1024).toStringAsFixed(1);

    Color badgeColor = Colors.grey;
    String badgeLabel = 'Chưa phân tích';
    if (item.analysis != null) {
      switch (item.analysis!.overallClassification) {
        case PdfClassification.text:
          badgeColor = Colors.blue;
          badgeLabel = 'Văn bản số';
          break;
        case PdfClassification.scanned:
          badgeColor = Colors.orange;
          badgeLabel = 'Tài liệu quét (OCR)';
          break;
        case PdfClassification.mixed:
          badgeColor = Colors.purple;
          badgeLabel = 'Hỗn hợp';
          break;
        case PdfClassification.needsRasterAnalysis:
          badgeColor = Colors.deepOrange;
          badgeLabel = 'Cần OCR';
          break;
      }
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.modulePdf.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.modulePdf, size: 24),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              item.fileName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: badgeColor.withOpacity(0.4)),
            ),
            child: Text(
              badgeLabel,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            'Kích thước: $sizeKb KB • ${item.statusText}',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          if (item.isProcessing) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: item.progress, minHeight: 4),
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.isCompleted) ...[
            if (item.docxPath != null) ...[
              Tooltip(
                message: 'Mở trực tiếp bằng Microsoft Word',
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.description_rounded, size: 16),
                  label: const Text('Mở Word', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => WorkspaceManager.openFile(item.docxPath!),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Mở thư mục chứa tệp Word',
                icon: const Icon(Icons.folder_open_rounded, color: Colors.blue, size: 20),
                onPressed: () => WorkspaceManager.openContainingFolder(item.docxPath!),
              ),
            ],
            if (item.xlsxPath != null)
              Tooltip(
                message: 'Mở sổ điểm / bảng tính Excel (.xlsx)',
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.table_chart_rounded, size: 16),
                  label: const Text('Mở Excel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => WorkspaceManager.openFile(item.xlsxPath!),
                ),
              ),
          ],
          if (!item.isProcessing)
            IconButton(
              tooltip: 'Xóa tệp khỏi danh sách',
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () => notifier.removeFile(index),
            ),
        ],
      ),
    );
  }
}
