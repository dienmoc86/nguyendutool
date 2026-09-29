import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/ai/google_auth_service.dart';
import '../../../core/filesystem/workspace_manager.dart';
import '../application/lesson_planner_notifier.dart';
import '../domain/lesson_plan_models.dart';

/// Screen for generating Vietnamese Ministry of Education (MOET) 5512 compliant lesson plans
/// powered by Google Gemini AI with 1-click Google authentication and Word (.docx) export.
class LessonPlannerScreen extends ConsumerStatefulWidget {
  const LessonPlannerScreen({super.key});

  @override
  ConsumerState<LessonPlannerScreen> createState() => _LessonPlannerScreenState();
}

class _LessonPlannerScreenState extends ConsumerState<LessonPlannerScreen> {
  final _formKey = GlobalKey<FormState>();

  String _selectedSubject = SchoolSubjects.subjects.first;
  String _selectedGrade = 'Lớp 6';
  String _selectedBookSeries = SchoolSubjects.bookSeriesList.first;
  String _selectedDuration = SchoolSubjects.durations.first;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _requirementsController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();

  bool _showApiKeyInput = false;

  @override
  void dispose() {
    _titleController.dispose();
    _requirementsController.dispose();
    _referenceController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _generateLessonPlan() {
    if (!_formKey.currentState!.validate()) return;

    final request = LessonPlanRequest(
      subject: _selectedSubject,
      grade: _selectedGrade,
      bookSeries: _selectedBookSeries,
      lessonTitle: _titleController.text.trim(),
      duration: _selectedDuration,
      customRequirements: _requirementsController.text.trim().isNotEmpty
          ? _requirementsController.text.trim()
          : null,
      referenceText: _referenceController.text.trim().isNotEmpty
          ? _referenceController.text.trim()
          : null,
    );

    ref.read(lessonPlannerNotifierProvider.notifier).generateLessonPlan(request);
  }

  Future<void> _handleExportWord() async {
    final path = await ref.read(lessonPlannerNotifierProvider.notifier).exportToWord();
    if (path != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xuất giáo án Word thành công: $path'),
          backgroundColor: AppColors.success,
          action: SnackBarAction(
            label: 'Mở tệp',
            textColor: Colors.white,
            onPressed: () {
              if (Platform.isWindows) {
                Process.run('cmd.exe', ['/c', 'start', '', path]);
              }
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(lessonPlannerNotifierProvider);
    final notifier = ref.read(lessonPlannerNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            _buildHeader(isDark),
            const SizedBox(height: 20),

            // Google Account Connection Card
            _buildGoogleAuthCard(isDark, state, notifier),
            const SizedBox(height: 24),

            // Error banner if any
            if (state.errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        state.errorMessage!,
                        style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Main Two-Panel Layout
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: Form Inputs
                      Expanded(
                        flex: 4,
                        child: _buildFormCard(isDark, state),
                      ),
                      const SizedBox(width: 24),
                      // Right: Generated Plan Preview & Exporter
                      Expanded(
                        flex: 6,
                        child: _buildPreviewCard(isDark, state),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildFormCard(isDark, state),
                      const SizedBox(height: 24),
                      _buildPreviewCard(isDark, state),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.accentViolet],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Soạn Giáo án AI Chuẩn Công văn 5512/BGDĐT-GDTrH',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Tự động thiết kế Kế hoạch bài dạy chuẩn 4 hoạt động, tích hợp rubric đánh giá và xuất Word (.docx) chuẩn Nghị định 30',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleAuthCard(bool isDark, LessonPlannerState state, LessonPlannerNotifier notifier) {
    if (state.isConnected && state.userProfile != null && !_showApiKeyInput) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.success.withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Đã kết nối Google Gemini AI',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Sẵn sàng hoạt động',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tài khoản: ${state.userProfile!.displayName} (${state.userProfile!.email}) • Bảo mật Windows DPAPI',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _showApiKeyInput = true),
              icon: const Icon(Icons.swap_horiz_rounded, size: 16),
              label: const Text('Đổi tài khoản / Khóa'),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Đăng xuất tài khoản Google',
              onPressed: () => notifier.signOut(),
              icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
            ),
          ],
        ),
      );
    }

    // Unconnected or Editing API Key Card
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_circle_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kết nối Google Gemini AI để bắt đầu soạn giáo án',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Hoàn toàn miễn phí. Dữ liệu khóa được bảo vệ bằng mã hóa phần cứng Windows DPAPI trên máy tính.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => GoogleAuthService.openGoogleKeyPortal(),
                icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                label: const Text('1. Mở trang Google lấy khóa miễn phí'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _apiKeyController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: '2. Dán mã khóa Google Gemini API Key tại đây (bắt đầu bằng AIzaSy...)',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                    isDense: true,
                    prefixIcon: const Icon(Icons.vpn_key_rounded, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  final key = _apiKeyController.text.trim();
                  if (key.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vui lòng dán mã khóa Google API Key.'),
                        backgroundColor: AppColors.warning,
                      ),
                    );
                    return;
                  }
                  notifier.connectWithGoogleKey(key);
                  setState(() => _showApiKeyInput = false);
                },
                icon: const Icon(Icons.link_rounded, size: 18),
                label: const Text('Lưu & Kết nối'),
              ),
              if (_showApiKeyInput && state.isConnected) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() => _showApiKeyInput = false),
                  child: const Text('Hủy'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(bool isDark, LessonPlannerState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Thông tin Thiết kế Bài dạy',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Subject Selector
            _buildDropdownField(
              label: 'Môn học',
              value: _selectedSubject,
              items: SchoolSubjects.subjects,
              onChanged: (val) => setState(() => _selectedSubject = val!),
            ),
            const SizedBox(height: 14),

            // Grade & Duration Row
            Row(
              children: [
                Expanded(
                  child: _buildDropdownField(
                    label: 'Khối lớp',
                    value: _selectedGrade,
                    items: SchoolSubjects.grades,
                    onChanged: (val) => setState(() => _selectedGrade = val!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdownField(
                    label: 'Thời lượng',
                    value: _selectedDuration,
                    items: SchoolSubjects.durations,
                    onChanged: (val) => setState(() => _selectedDuration = val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Book Series Selector
            _buildDropdownField(
              label: 'Bộ sách giáo khoa',
              value: _selectedBookSeries,
              items: SchoolSubjects.bookSeriesList,
              onChanged: (val) => setState(() => _selectedBookSeries = val!),
            ),
            const SizedBox(height: 14),

            // Lesson Title Input
            Text(
              'Tên bài học / Tiết dạy *',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'VD: Bài 3: Lũy thừa với số mũ tự nhiên (Toán 6)',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Vui lòng nhập tên bài dạy.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Special Requirements Input
            Text(
              'Yêu cầu sư phạm & Tích hợp (Tùy chọn)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _requirementsController,
              decoration: InputDecoration(
                hintText: 'VD: Tích hợp giáo dục STEM, tăng cường thực hành nhóm, trò chơi khởi động sôi nổi...',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 14),

            // Textbook/Reference Text Input
            Text(
              'Trích yếu nội dung SGK / Đề cương (Tùy chọn)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _referenceController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Dán tóm tắt nội dung sách giáo khoa hoặc các khái niệm cốt lõi cần dạy tại đây...',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 22),

            // Generate Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
                onPressed: state.isGenerating ? null : _generateLessonPlan,
                icon: state.isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  state.isGenerating ? 'AI đang soạn giáo án...' : 'Soạn Giáo án AI chuẩn 5512',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              items: items.map((e) => DropdownMenuItem(
                value: e,
                child: Text(
                  e,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              )).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewCard(bool isDark, LessonPlannerState state) {
    return Container(
      constraints: const BoxConstraints(minHeight: 520),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.menu_book_rounded, color: AppColors.secondary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Kế hoạch bài dạy (Công văn 5512)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              if (state.generatedPlan != null)
                Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.modulePdf,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: state.isExporting ? null : _handleExportWord,
                      icon: state.isExporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.description_rounded, size: 16),
                      label: Text(state.isExporting ? 'Đang xuất...' : 'Xuất Word (.docx)'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: state.generatedPlan!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã sao chép nội dung giáo án vào Clipboard.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Sao chép'),
                    ),
                  ],
                ),
            ],
          ),
          const Divider(height: 24),

          // Body Content
          if (state.isGenerating) ...[
            _buildGeneratingState(isDark),
          ] else if (state.generatedPlan != null) ...[
            _buildExportSuccessCard(isDark, state),
            _buildPlanContent(isDark, state.generatedPlan!),
          ] else ...[
            _buildEmptyState(isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildExportSuccessCard(bool isDark, LessonPlannerState state) {
    if (state.exportedFilePath == null) return const SizedBox.shrink();

    final path = state.exportedFilePath!;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Đã tạo tệp Word (.docx) chuẩn Nghị định 30 thành công!',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.success),
                ),
                Text(
                  path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () {
              if (Platform.isWindows) {
                Process.run('cmd.exe', ['/c', 'start', '', path]);
              }
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Mở file Word'),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Mở thư mục chứa',
            onPressed: () => WorkspaceManager.openContainingFolder(path),
            icon: const Icon(Icons.folder_open_rounded, color: AppColors.success),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratingState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
            const SizedBox(height: 24),
            Text(
              'Trợ lý AI đang thiết kế Giáo án 5512...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxWidth: 460),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _GenerationStepItem(label: '1. Phân tích mục tiêu (Kiến thức, Năng lực, Phẩm chất)', isDone: true),
                  SizedBox(height: 8),
                  _GenerationStepItem(label: '2. Thiết lập thiết bị dạy học & học liệu', isDone: true),
                  SizedBox(height: 8),
                  _GenerationStepItem(label: '3. Thiết kế 4 hoạt động dạy học chuẩn Công văn 5512', isDone: false),
                  SizedBox(height: 8),
                  _GenerationStepItem(label: '4. Xây dựng Phiếu học tập & Bảng tiêu chí đánh giá (Rubric)', isDone: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.school_rounded, color: AppColors.primary, size: 48),
            ),
            const SizedBox(height: 18),
            Text(
              'Kế hoạch bài dạy chuẩn Công văn 5512/BGDĐT-GDTrH',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(
                'Điền thông tin môn học, lớp và tên bài dạy ở cột bên trái, sau đó nhấn "Soạn Giáo án AI chuẩn 5512". Trợ lý sẽ tự động phân tích và tạo kế hoạch hoàn chỉnh với 4 hoạt động (Khởi động, Hình thành kiến thức, Luyện tập, Vận dụng), kèm theo Phiếu học tập và Bảng tiêu chí đánh giá.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanContent(bool isDark, String content) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161F30) : const Color(0xFFFBFBFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: SelectableText(
        content,
        style: TextStyle(
          fontFamily: 'Segoe UI',
          fontSize: 14,
          height: 1.6,
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
      ),
    );
  }
}

class _GenerationStepItem extends StatelessWidget {
  final String label;
  final bool isDone;

  const _GenerationStepItem({required this.label, required this.isDone});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          color: isDone ? AppColors.success : AppColors.primaryLight,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isDone ? FontWeight.w600 : FontWeight.w400,
              color: isDone ? AppColors.success : null,
            ),
          ),
        ),
      ],
    );
  }
}
