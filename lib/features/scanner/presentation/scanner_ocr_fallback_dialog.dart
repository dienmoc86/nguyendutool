import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';

/// Modal dialog shown when Vietnamese OCR language pack is not installed on Windows.
/// Satisfies Entry Remediation 0.A: Explicit fallback consent with 3 distinct options.
class ScannerOcrFallbackDialog extends StatelessWidget {
  final VoidCallback onInstallGuide;
  final VoidCallback onContinueWithExisting;
  final VoidCallback onCancel;

  const ScannerOcrFallbackDialog({
    super.key,
    required this.onInstallGuide,
    required this.onContinueWithExisting,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Gói OCR tiếng Việt chưa được cài đặt',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hệ điều hành Windows hiện chưa có gói nhận dạng chữ viết tiếng Việt (vi-VN). '
            'Để đạt độ chính xác cao nhất cho tài liệu tiếng Việt có dấu, bạn nên cài đặt gói ngôn ngữ tiếng Việt từ Windows Settings.',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          SizedBox(height: 12),
          Text(
            'Bạn muốn xử lý như thế nào?',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
        ),
        OutlinedButton.icon(
          onPressed: onInstallGuide,
          icon: const Icon(Icons.help_outline_rounded, size: 18),
          label: const Text('1. Hướng dẫn cài gói tiếng Việt'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
          ),
        ),
        FilledButton.icon(
          onPressed: onContinueWithExisting,
          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          label: const Text('2. Tiếp tục bằng OCR hiện có'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.moduleScanner,
          ),
        ),
      ],
    );
  }
}
