import 'package:flutter/material.dart';
import '../domain/models/scanner_device.dart';

/// First-run onboarding screen offering clear quick actions to start scanning or importing.
class ScannerFirstRunView extends StatelessWidget {
  final List<ScannerDevice> availableScanners;
  final VoidCallback onScanClick;
  final VoidCallback onImportImagesClick;
  final VoidCallback onCaptureCameraClick;
  final VoidCallback onImportPdfClick;

  const ScannerFirstRunView({
    super.key,
    required this.availableScanners,
    required this.onScanClick,
    required this.onImportImagesClick,
    required this.onCaptureCameraClick,
    required this.onImportPdfClick,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasScanner = availableScanners.isNotEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Hero Icon & Title
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 38),
              ),
              const SizedBox(height: 20),
              const Text(
                'Quét & Số Hóa Tài Liệu',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Chuyển đổi văn bản giấy thành PDF có thể tìm kiếm chữ (Searchable PDF), Word (.docx) hoặc ảnh sắc nét.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 36),

              // Hardware Scanner Status Alert
              if (!hasScanner)
                Container(
                  margin: const EdgeInsets.only(bottom: 28),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF332A15) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF785E1A) : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber[800], size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Không tìm thấy máy scan vật lý được kết nối (WIA 2.0). Bạn vẫn có thể nhập ảnh, PDF hoặc camera.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                ),

              // 4 Quick-Action Cards Grid
              Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: [
                  _ActionCard(
                    title: 'Quét từ máy scan',
                    subtitle: hasScanner
                        ? 'Kết nối trực tiếp ${availableScanners.first.name}'
                        : 'Không tìm thấy máy scan vật lý',
                    icon: Icons.scanner_rounded,
                    color: const Color(0xFF0284C7),
                    isEnabled: hasScanner,
                    onTap: onScanClick,
                  ),
                  _ActionCard(
                    title: 'Nhập tệp hình ảnh',
                    subtitle: 'Hỗ trợ JPG, PNG, BMP, TIFF, WebP (chọn nhiều ảnh cùng lúc)',
                    icon: Icons.photo_library_rounded,
                    color: const Color(0xFF10B981),
                    isEnabled: true,
                    onTap: onImportImagesClick,
                  ),
                  _ActionCard(
                    title: 'Chụp bằng camera',
                    subtitle: 'Sử dụng webcam hoặc camera chụp tài liệu USB',
                    icon: Icons.camera_alt_rounded,
                    color: const Color(0xFF8B5CF6),
                    isEnabled: true,
                    onTap: onCaptureCameraClick,
                  ),
                  _ActionCard(
                    title: 'Nhập tài liệu PDF',
                    subtitle: 'Rasterize PDF để căn chỉnh góc, khử nghiêng, làm sạch và OCR',
                    icon: Icons.picture_as_pdf_rounded,
                    color: const Color(0xFFF59E0B),
                    isEnabled: true,
                    onTap: onImportPdfClick,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isEnabled;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 210,
          height: 220,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isEnabled ? color.withOpacity(0.12) : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: isEnabled ? color : Colors.grey, size: 24),
              ),
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isEnabled ? null : Colors.grey,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
