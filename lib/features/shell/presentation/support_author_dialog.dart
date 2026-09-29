import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../app/theme/app_colors.dart';

/// Elegant, respectful Dialog presenting Author details, Free software philosophy,
/// custom tool development contact, and optional "Buy Me a Coffee" QR support.
class SupportAuthorDialog extends StatelessWidget {
  const SupportAuthorDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const SupportAuthorDialog(),
    );
  }

  void _openWebsite() {
    if (Platform.isWindows) {
      Process.run('cmd.exe', ['/c', 'start', 'https://ibestgroup.vn']);
    }
  }

  void _openZalo() {
    if (Platform.isWindows) {
      Process.run('cmd.exe', ['/c', 'start', 'https://zalo.me/0917764111']);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF141A28) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with Coffee & Heart Icon
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4CAF50).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/ibest_logo.png',
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Đồng hành & Ủng hộ Tác giả',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.green.withOpacity(0.4)),
                              ),
                              child: const Text(
                                'Miễn phí 100%',
                                style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'NguyenDu Tool — Bộ công cụ số hóa & trợ lý giáo viên',
                          style: TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Đóng',
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Heartwarming letter to teachers
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1B2336) : const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF28344E) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.favorite_rounded, color: Color(0xFFE91E63), size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Kính gửi quý Thầy/Cô & các Nhà trường,',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Phần mềm Nguyen Du Tool được phát triển hoàn toàn phi lợi nhuận với tâm huyết giúp công việc giảng dạy, soạn giáo án chuẩn 5512, tạo video bài giảng và chuyển đổi tài liệu của Thầy/Cô trở nên nhẹ nhàng, hiệu quả và hiện đại hơn.',
                      style: TextStyle(fontSize: 12.5, height: 1.45),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Phần mềm được trao gửi MIỄN PHÍ 100% đến cộng đồng giáo dục mà không thu bất kỳ khoản phí bản quyền nào.',
                      style: TextStyle(fontSize: 12.5, height: 1.45, fontWeight: FontWeight.w600, color: Color(0xFFFFB74D)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Author info & Custom Tool Development Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E283D), const Color(0xFF161F30)]
                        : [const Color(0xFFF0F4FF), const Color(0xFFE8EEFA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.badge_rounded, color: AppColors.primaryLight, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Thông tin Tác giả & Hỗ trợ Kỹ thuật',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Hỗ trợ tận tình',
                            style: TextStyle(fontSize: 11, color: AppColors.primaryLight, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildContactItem(
                      icon: Icons.person_rounded,
                      label: 'Tác giả phát triển:',
                      value: 'Mr. Điện',
                      onCopy: null,
                    ),
                    const SizedBox(height: 8),
                    _buildContactItem(
                      icon: Icons.phone_android_rounded,
                      label: 'Điện thoại / Zalo:',
                      value: '0917.764.111',
                      isClickable: true,
                      onCopy: () {
                        Clipboard.setData(const ClipboardData(text: '0917764111'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã sao chép số điện thoại: 0917.764.111')),
                        );
                      },
                      onTap: _openZalo,
                    ),
                    const SizedBox(height: 8),
                    _buildContactItem(
                      icon: Icons.language_rounded,
                      label: 'Website công nghệ:',
                      value: 'ibestgroup.vn',
                      isClickable: true,
                      onTap: _openWebsite,
                      onCopy: () {
                        Clipboard.setData(const ClipboardData(text: 'https://ibestgroup.vn'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã sao chép địa chỉ website: https://ibestgroup.vn')),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.handshake_rounded, color: Colors.blueAccent, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Nhận tùy biến, nâng cấp tính năng hoặc viết phần mềm/công cụ tiện ích theo yêu cầu riêng của từng trường học và Thầy/Cô.',
                              style: TextStyle(fontSize: 11.5, color: Colors.lightBlueAccent, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // "Buy Me a Coffee" Support Section with Official VietQR Code
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1A29) : const Color(0xFFFFF9F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFFB74D).withOpacity(0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Official VietQR / Napas 247 Image Container
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/images/author_qr.jpg',
                          width: 145,
                          height: 154,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return QrImageView(
                              data: '00020101021138540010A00000072701240006970436011010793288880208QRIBFTTA53037045802VN63043BE8',
                              version: QrVersions.auto,
                              size: 140,
                              backgroundColor: Colors.white,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Text(
                                'Mời tác giả tách Cà phê ☕',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFFA726),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Sự động viên của quý Thầy/Cô (dù là một lời chúc hay một ly cà phê) là món quà quý giá tiếp thêm năng lượng cho tác giả!',
                            style: TextStyle(fontSize: 12, height: 1.4),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF141923) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? const Color(0xFF232D42) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Text('Ngân hàng: ', style: TextStyle(fontSize: 11.5, color: AppColors.darkTextSecondary)),
                                    Text('Vietcombank (VCB)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Text('Số tài khoản: ', style: TextStyle(fontSize: 11.5, color: AppColors.darkTextSecondary)),
                                    const Text('1079328888', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFFFA726))),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () {
                                        Clipboard.setData(const ClipboardData(text: '1079328888'));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Đã sao chép STK Vietcombank: 1079328888'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                      child: const Icon(Icons.copy_rounded, size: 14, color: AppColors.primary),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                const Row(
                                  children: [
                                    Text('Chủ tài khoản: ', style: TextStyle(fontSize: 11.5, color: AppColors.darkTextSecondary)),
                                    Text('NGUYỄN KHẮC ĐIỆN (Mr. Điện)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () {
                                  Clipboard.setData(const ClipboardData(text: '1079328888'));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Đã sao chép STK Vietcombank: 1079328888'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy_rounded, size: 13),
                                label: const Text('Sao chép STK VCB'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFFFA726),
                                  side: const BorderSide(color: Color(0xFFFFA726)),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  textStyle: const TextStyle(fontSize: 11),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () {
                                  Clipboard.setData(const ClipboardData(text: '0917764111'));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Đã sao chép SĐT / Zalo / MoMo: 0917.764.111'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.phone_iphone_rounded, size: 13),
                                label: const Text('Sao chép SĐT'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.blueAccent,
                                  side: const BorderSide(color: Colors.blueAccent),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  textStyle: const TextStyle(fontSize: 11),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _openZalo,
                                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 13),
                                label: const Text('Nhắn Zalo tác giả'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0288D1),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  textStyle: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action buttons footer
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: _openWebsite,
                    icon: const Icon(Icons.public_rounded, size: 16),
                    label: const Text('Ghé thăm ibestgroup.vn'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text('Đóng'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String label,
    required String value,
    bool isClickable = false,
    VoidCallback? onCopy,
    VoidCallback? onTap,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.darkTextSecondary),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.darkTextSecondary)),
        const SizedBox(width: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: isClickable ? Colors.blueAccent : null,
                decoration: isClickable ? TextDecoration.underline : null,
              ),
            ),
          ),
        ),
        if (onCopy != null) ...[
          const SizedBox(width: 4),
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.copy_rounded, size: 14, color: AppColors.darkTextSecondary),
            ),
          ),
        ],
      ],
    );
  }
}
