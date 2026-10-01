import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/diagnostics/diagnostic_status.dart';
import '../../../core/diagnostics/system_diagnostics_service.dart';
import '../../../core/filesystem/workspace_manager.dart';
import '../../../core/product/product_info.dart';
import '../../../core/providers/app_providers.dart';

/// First-run onboarding wizard for new users (Section 11 & 12).
/// Step-by-step guidance without technical jargon.
class FirstRunWizardScreen extends ConsumerStatefulWidget {
  final VoidCallback onCompleted;

  const FirstRunWizardScreen({super.key, required this.onCompleted});

  @override
  ConsumerState<FirstRunWizardScreen> createState() => _FirstRunWizardScreenState();
}

class _FirstRunWizardScreenState extends ConsumerState<FirstRunWizardScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isRunningDiagnostics = false;
  List<SystemDiagnosticItem> _diagnosticItems = [];

  final List<String> _pageTitles = [
    'Chào mừng (Welcome)',
    'Thư mục làm việc (Workspace)',
    'Kiểm tra hệ thống (System Check)',
    'Ngôn ngữ & OCR (Language)',
    'Giọng đọc (TTS Voices)',
    'Động cơ Video (Video Engine)',
    'Hoàn tất (Finish)',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 6) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishWizard();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finishWizard() async {
    await ref.read(settingsNotifierProvider.notifier).completeFirstRun();
    widget.onCompleted();
  }

  Future<void> _runDiagnostics() async {
    setState(() => _isRunningDiagnostics = true);
    final ws = ref.read(workspaceManagerProvider);
    final diag = SystemDiagnosticsService(workspaceManager: ws);
    final items = await diag.runFullDiagnostics(
      appVersion: ProductInfo.version,
      databaseSchemaVersion: ProductInfo.schemaVersion,
    );
    if (mounted) {
      setState(() {
        _diagnosticItems = items;
        _isRunningDiagnostics = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Top Stepper Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.accentViolet],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.school_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NguyenDu Tool - Hướng dẫn thiết lập ban đầu',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Bước ${_currentPage + 1}/7: ${_pageTitles[_currentPage]}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _finishWizard,
                    child: const Text('Bỏ qua (Dùng mặc định)'),
                  ),
                ],
              ),
            ),

            // Main Content Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                  if (page == 2 && _diagnosticItems.isEmpty && !_isRunningDiagnostics) {
                    _runDiagnostics();
                  }
                },
                children: [
                  _buildWelcomePage(isDark),
                  _buildWorkspacePage(isDark),
                  _buildSystemCheckPage(isDark),
                  _buildLanguageOcrPage(isDark),
                  _buildTtsVoicesPage(isDark),
                  _buildVideoEnginePage(isDark),
                  _buildFinishPage(isDark),
                ],
              ),
            ),

            // Bottom Navigation Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
              ),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    OutlinedButton.icon(
                      onPressed: _prevPage,
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: const Text('Quay lại'),
                    ),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: _nextPage,
                    icon: Icon(
                      _currentPage == 6 ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                      size: 16,
                    ),
                    label: Text(_currentPage == 6 ? 'Bắt đầu sử dụng' : 'Tiếp tục'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 1. Welcome Page
  Widget _buildWelcomePage(bool isDark) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.accentViolet],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 44),
            ),
            const SizedBox(height: 24),
            const Text(
              'Chào mừng bạn đến với NguyenDu Tool',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Bộ công cụ xử lý văn bản, tài liệu, sách scan số hóa, tổng hợp giọng đọc tiếng Việt và dựng video tự động dành cho giáo dục và quản trị trường học.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 28),
            _buildFeaturePill(Icons.picture_as_pdf_rounded, 'Chuyển đổi PDF, Word, Excel & OCR tiếng Việt cục bộ'),
            const SizedBox(height: 10),
            _buildFeaturePill(Icons.scanner_rounded, 'Số hóa tài liệu với Máy quét Scanner & Camera'),
            const SizedBox(height: 10),
            _buildFeaturePill(Icons.record_voice_over_rounded, 'Tổng hợp giọng đọc tiếng Việt tự nhiên (TTS)'),
            const SizedBox(height: 10),
            _buildFeaturePill(Icons.video_library_rounded, 'Dựng bài giảng video tự động với FFmpeg tích hợp sẵn'),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturePill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryLight),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  // 2. Workspace Page
  Widget _buildWorkspacePage(bool isDark) {
    final workspace = ref.watch(workspaceManagerProvider);
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640),
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_special_rounded, size: 48, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text(
              'Không gian làm việc (Workspace)',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Tất cả tài liệu dự án, tệp scan, âm thanh và video kết xuất sẽ được lưu trữ an toàn trong thư mục máy tính của bạn (Local-First).',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Đường dẫn mặc định:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  SelectableText(
                    workspace.rootPath,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => WorkspaceManager.openFolder(workspace.rootPath),
                  icon: const Icon(Icons.folder_open_rounded, size: 16),
                  label: const Text('Mở trong Windows Explorer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 3. System Check Page
  Widget _buildSystemCheckPage(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Kiểm tra tính tương thích hệ thống',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_isRunningDiagnostics)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                OutlinedButton.icon(
                  onPressed: _runDiagnostics,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Kiểm tra lại'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Ứng dụng đang kiểm tra các tài nguyên cần thiết: Windows OCR, giọng đọc TTS, động cơ FFmpeg tích hợp...',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _diagnosticItems.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: _diagnosticItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _diagnosticItems[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        ),
                        child: Row(
                          children: [
                            _buildStatusIcon(item.status),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.details,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                  if (item.recommendation != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      item.recommendation!,
                                      style: const TextStyle(fontSize: 11, color: AppColors.warning),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(DiagnosticStatus status) {
    switch (status) {
      case DiagnosticStatus.ready:
        return const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22);
      case DiagnosticStatus.optionalNotAvailable:
        return const Icon(Icons.info_outline_rounded, color: AppColors.info, size: 22);
      case DiagnosticStatus.actionRequired:
        return const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 22);
      case DiagnosticStatus.failed:
        return const Icon(Icons.cancel_rounded, color: AppColors.error, size: 22);
    }
  }

  // 4. Language & OCR Page
  Widget _buildLanguageOcrPage(bool isDark) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640),
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.translate_rounded, size: 48, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text('Ngôn ngữ giao diện & Nhận dạng OCR', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'NguyenDu Tool sử dụng công nghệ nhận dạng ký tự quang học WinRT OCR bản địa của Windows 10/11 để số hóa tài liệu tiếng Việt hoàn toàn offline.',
              style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_rounded, color: AppColors.success, size: 24),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Gói ngôn ngữ tiếng Việt (vi-VN)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        Text('Sẵn sàng cho trích xuất PDF sang Word/Excel và scan sách giáo khoa.', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 5. TTS Voices Page
  Widget _buildTtsVoicesPage(bool isDark) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640),
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.record_voice_over_rounded, size: 48, color: AppColors.accentViolet),
            const SizedBox(height: 16),
            const Text('Giọng đọc văn bản (Text to Speech)', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Ứng dụng tự động kết nối các giọng đọc chuẩn SAPI5 và WinRT OneCore có sẵn trong Windows (Microsoft An, Microsoft HoaiMy) để tạo bài giảng audio, podcast và sách nói.',
              style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: const Row(
                children: [
                  Icon(Icons.mic_rounded, color: AppColors.primary, size: 24),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Động cơ phát âm thanh cục bộ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        Text('Xuất tệp WAV, MP3 chất lượng cao kèm tệp phụ đề SRT / VTT đồng bộ.', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 6. Video Engine Page
  Widget _buildVideoEnginePage(bool isDark) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640),
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.movie_creation_rounded, size: 48, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text('Động cơ dựng Video FFmpeg Tích Hợp', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'NguyenDu Tool đi kèm bộ công cụ FFmpeg 8.0.1 và FFprobe được đóng gói sẵn trong thư mục bin/ của ứng dụng. Bạn KHÔNG cần phải cài đặt thêm bất kỳ phần mềm lập trình nào.',
              style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 24),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tự động nhận diện Động cơ FFmpeg Đóng gói', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        Text('Hỗ trợ H.264, AAC, MP3, bộ lọc hiệu ứng xfade, âm thanh ducking và phụ đề libass.', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 7. Finish Page
  Widget _buildFinishPage(bool isDark) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: AppColors.success, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'Thiết lập hoàn tất!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Mọi tài nguyên đã sẵn sàng. Thầy cô có thể bắt đầu Chuyển đổi PDF, Tạo giọng nói AI và Gỡ băng bài giảng ngay bây giờ.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
