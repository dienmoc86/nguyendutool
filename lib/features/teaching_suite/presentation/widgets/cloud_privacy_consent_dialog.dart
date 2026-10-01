import 'package:flutter/material.dart';

/// Modal dialog ensuring user consent before sending educational data to cloud AI providers.
class CloudPrivacyConsentDialog extends StatefulWidget {
  final String providerName;
  final String modelName;

  const CloudPrivacyConsentDialog({
    super.key,
    required this.providerName,
    required this.modelName,
  });

  static Future<bool> show(BuildContext context, {required String providerName, required String modelName}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CloudPrivacyConsentDialog(
        providerName: providerName,
        modelName: modelName,
      ),
    );
    return result ?? false;
  }

  @override
  State<CloudPrivacyConsentDialog> createState() => _CloudPrivacyConsentDialogState();
}

class _CloudPrivacyConsentDialogState extends State<CloudPrivacyConsentDialog> {
  bool _rememberChoice = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.shield_outlined, color: theme.colorScheme.primary, size: 28),
          const SizedBox(width: 10),
          const Text('Thông báo Quyền riêng tư & AI'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nội dung bạn nhập (thông tin bài học, yêu cầu sư phạm và tài liệu tham khảo đính kèm) sẽ được gửi tới nhà cung cấp AI đã cấu hình để xử lý:',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Nhà cung cấp: ${widget.providerName.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('• Mô hình xử lý: ${widget.modelName}', style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  const Text('• Phạm vi dữ liệu: Chỉ nội dung bài dạy hiện tại, KHÔNG gửi dữ liệu cá nhân hay toàn bộ hệ thống tệp.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: _rememberChoice,
                  onChanged: (val) {
                    setState(() {
                      _rememberChoice = val ?? true;
                    });
                  },
                ),
                const Expanded(
                  child: Text('Ghi nhớ sự đồng ý này cho các thao tác tiếp theo trong phiên làm việc.', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Hủy bỏ'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Tiếp tục gửi AI'),
        ),
      ],
    );
  }
}
