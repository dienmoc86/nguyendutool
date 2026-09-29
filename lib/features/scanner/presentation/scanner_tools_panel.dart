import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../domain/models/scan_options.dart';
import '../domain/models/scan_page.dart';
import '../domain/models/scan_profile.dart';

/// Right sidebar providing processing tools, enhancement presets, rotation, crop triggers, and quality warnings.
class ScannerToolsPanel extends StatelessWidget {
  final ScanPage? page;
  final List<ScanProfile> profiles;
  final ScanProfile activeProfile;
  final bool isManualCropMode;
  final ValueChanged<ScanProfile> onSelectProfile;
  final ValueChanged<bool> onToggleManualCrop;
  final ValueChanged<int> onRotate;
  final ValueChanged<ScanProcessingOptions> onUpdateProcessing;
  final VoidCallback onTriggerOcr;
  final VoidCallback onDeleteCurrentPage;

  const ScannerToolsPanel({
    super.key,
    required this.page,
    required this.profiles,
    required this.activeProfile,
    required this.isManualCropMode,
    required this.onSelectProfile,
    required this.onToggleManualCrop,
    required this.onRotate,
    required this.onUpdateProcessing,
    required this.onTriggerOcr,
    required this.onDeleteCurrentPage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        border: Border(
          left: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: page == null
          ? const Center(
              child: Text(
                'Chọn trang để chỉnh sửa',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Quality & Blank Page Warnings
                  if (page!.isLikelyBlank) ...[
                    _buildWarningCard(
                      icon: Icons.warning_amber_rounded,
                      color: Colors.orange,
                      title: 'Trang này có vẻ trống',
                      message: 'Phát hiện trang có rất ít nội dung hoặc trang trắng.',
                      actionLabel: 'Xóa trang này',
                      onAction: onDeleteCurrentPage,
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (page!.quality != null && page!.quality!.warnings.isNotEmpty) ...[
                    _buildWarningCard(
                      icon: Icons.info_outline,
                      color: Colors.amber,
                      title: 'Chất lượng trang quét',
                      message: page!.quality!.warnings.join('\n'),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Profile Presets Section
                  _buildSectionHeader('Cấu hình mẫu (Preset)'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<ScanProfile>(
                    value: activeProfile,
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: profiles.map((p) {
                      return DropdownMenuItem(
                        value: p,
                        child: Text(p.name, style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (p) {
                      if (p != null) onSelectProfile(p);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Geometry & Rotation Section
                  _buildSectionHeader('Hình học & Hướng trang'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => onRotate(-90),
                          icon: const Icon(Icons.rotate_left_rounded, size: 18),
                          label: const Text('Xoay trái'),
                          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => onRotate(90),
                          icon: const Icon(Icons.rotate_right_rounded, size: 18),
                          label: const Text('Xoay phải'),
                          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: () => onToggleManualCrop(!isManualCropMode),
                    icon: Icon(
                      isManualCropMode ? Icons.check : Icons.crop_free_rounded,
                      size: 18,
                    ),
                    label: Text(isManualCropMode ? 'Đang căn góc thủ công' : 'Cắt & nắn góc 4 điểm'),
                    style: FilledButton.styleFrom(
                      backgroundColor: isManualCropMode
                          ? AppColors.moduleScanner.withOpacity(0.2)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Image Enhancement Filter Presets
                  _buildSectionHeader('Bộ lọc hình ảnh'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: EnhancementPreset.values.map((preset) {
                      final isSelected = page!.processingOptions.preset == preset;
                      return ChoiceChip(
                        label: Text(preset.label, style: const TextStyle(fontSize: 11)),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            onUpdateProcessing(page!.processingOptions.copyWith(preset: preset));
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // Sliders: Contrast & Brightness
                  Text(
                    'Độ tương phản (${page!.processingOptions.contrast.toStringAsFixed(2)})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  Slider(
                    value: page!.processingOptions.contrast,
                    min: 0.8,
                    max: 1.8,
                    divisions: 10,
                    onChanged: (val) {
                      onUpdateProcessing(page!.processingOptions.copyWith(contrast: val));
                    },
                  ),
                  Text(
                    'Độ sáng (${page!.processingOptions.brightness.toStringAsFixed(2)})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  Slider(
                    value: page!.processingOptions.brightness,
                    min: 0.8,
                    max: 1.4,
                    divisions: 6,
                    onChanged: (val) {
                      onUpdateProcessing(page!.processingOptions.copyWith(brightness: val));
                    },
                  ),

                  // Sharpen & Clean toggles
                  SwitchListTile(
                    title: const Text('Làm nét chữ (Sharpen)', style: TextStyle(fontSize: 12)),
                    value: page!.processingOptions.sharpen,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      onUpdateProcessing(page!.processingOptions.copyWith(sharpen: val));
                    },
                  ),
                  const SizedBox(height: 16),

                  // OCR Action Button
                  _buildSectionHeader('Nhận dạng chữ viết'),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: onTriggerOcr,
                    icon: const Icon(Icons.document_scanner_outlined, size: 18),
                    label: Text(
                      page!.ocrStatus == 'done' ? 'Nhận dạng lại OCR' : 'Nhận dạng chữ (OCR)',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  if (page!.ocrStatus == 'done' && page!.ocrResult != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle, size: 14, color: Colors.green),
                              const SizedBox(width: 6),
                              Text(
                                'Ngôn ngữ: ${page!.ocrResult!.languageUsed ?? "vi-VN"}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Phát hiện ${page!.ocrResult!.blocks.length} khối văn bản (${page!.ocrResult!.durationMs} ms)',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildWarningCard({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(fontSize: 11, height: 1.3)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                foregroundColor: color,
              ),
              child: Text(actionLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }
}
