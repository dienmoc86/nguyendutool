import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../domain/models/scanner_device.dart';
import '../infrastructure/windows_camera_service.dart';

/// First-run onboarding screen offering clear quick actions to start scanning or importing.
class ScannerFirstRunView extends StatelessWidget {
  final List<ScannerDevice> availableScanners;
  final List<CameraDeviceInfo> availableCameras;
  final VoidCallback onRefreshDevices;
  final VoidCallback onScanClick;
  final VoidCallback onImportImagesClick;
  final VoidCallback onCaptureCameraClick;
  final VoidCallback onImportPdfClick;

  const ScannerFirstRunView({
    super.key,
    required this.availableScanners,
    this.availableCameras = const [],
    required this.onRefreshDevices,
    required this.onScanClick,
    required this.onImportImagesClick,
    required this.onCaptureCameraClick,
    required this.onImportPdfClick,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasScanner = availableScanners.isNotEmpty;
    final hasCamera = availableCameras.isNotEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
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
              const SizedBox(height: 18),
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
                'Hỗ trợ máy scan bàn WIA, camera điện thoại (DroidCam/Iriun/USB) và chọn ảnh trực tiếp từ điện thoại / máy tính.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),

              // Hardware Status Bar & Device Refresh
              Container(
                margin: const EdgeInsets.only(bottom: 28),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    // Scanner Status Chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: hasScanner ? Colors.green.withOpacity(0.12) : Colors.amber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasScanner ? Icons.check_circle_rounded : Icons.info_outline,
                            size: 15,
                            color: hasScanner ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            hasScanner ? 'Máy scan: ${availableScanners.first.name}' : 'Chưa có máy scan WIA',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: hasScanner
                                  ? (isDark ? const Color(0xFF34D399) : const Color(0xFF065F46))
                                  : (isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Camera Status Chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: hasCamera ? Colors.blue.withOpacity(0.12) : Colors.grey.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasCamera ? Icons.camera_alt_rounded : Icons.camera_alt_outlined,
                            size: 15,
                            color: hasCamera ? const Color(0xFF0284C7) : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            hasCamera ? 'Camera: ${availableCameras.first.name}' : 'Chưa nhận camera',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: hasCamera
                                  ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1))
                                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Refresh Button
                    TextButton.icon(
                      onPressed: onRefreshDevices,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Tìm lại thiết bị (F5)', style: TextStyle(fontSize: 12.5)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                    title: 'Quét từ máy scan WIA',
                    subtitle: hasScanner
                        ? 'Kết nối trực tiếp ${availableScanners.first.name}'
                        : 'Dùng cho máy scan bàn Canon, HP, Epson cắm cổng USB',
                    icon: Icons.scanner_rounded,
                    color: const Color(0xFF0284C7),
                    isEnabled: hasScanner,
                    onTap: onScanClick,
                  ),
                  _ActionCard(
                    title: 'Chụp bằng camera & ĐT',
                    subtitle: hasCamera
                        ? 'Chụp ngay từ ${availableCameras.first.name}'
                        : 'Dùng camera điện thoại (DroidCam/Iriun/USB) hoặc webcam',
                    icon: Icons.camera_alt_rounded,
                    color: const Color(0xFF8B5CF6),
                    isEnabled: true,
                    onTap: onCaptureCameraClick,
                  ),
                  _ActionCard(
                    title: 'Nhập ảnh từ ĐT / Máy tính',
                    subtitle: 'Cắm cáp USB chọn ảnh từ điện thoại hoặc máy (JPG, PNG, HEIC, TIFF)',
                    icon: Icons.photo_library_rounded,
                    color: const Color(0xFF10B981),
                    isEnabled: true,
                    onTap: onImportImagesClick,
                  ),
                  _ActionCard(
                    title: 'Nhập tài liệu PDF',
                    subtitle: 'Nắn thẳng góc tài liệu, khử bóng, làm trắng nền và OCR xuất Word/PDF',
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
