import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/ai/gemini_service.dart';
import '../../../core/jobs/domain/job_status.dart';
import '../../../core/modules/module_category.dart';
import '../../../core/modules/module_definition.dart';
import '../../../core/modules/module_registry.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/security/credential_service.dart';
import 'widgets/module_card.dart';
import 'widgets/quick_stats_card.dart';
import 'widgets/recent_jobs_card.dart';

/// Redesigned Teacher-First Dashboard for NguyenDu Tool.
/// Focuses squarely on the core productivity tools requested by teachers:
/// 1. PDF to Word/Excel Converter (preserved & enhanced)
/// 2. Text to Speech AI (Vietnamese natural voices)
/// 3. Speech-to-Text & Video Transcription (powered by Google Gemini AI)
/// Plus Google Gemini API Key management and quick stats.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _hasGeminiKey = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final key = await CredentialService().getGeminiApiKey();
      if (mounted) {
        setState(() {
          _hasGeminiKey = key != null && key.trim().isNotEmpty;
        });
      }
    } catch (_) {
      // Graceful fallback
    }
  }

  void _openModule(ModuleDefinition module) {
    if (module.isLaunchable && module.route != null) {
      ref.read(moduleUsageServiceProvider).recordModuleOpened(module.id);
      context.go(module.route!);
    }
  }

  Future<void> _showApiKeyDialog(BuildContext context) async {
    final credService = CredentialService();
    final currentKey = await credService.getGeminiApiKey();
    final keyController = TextEditingController(text: currentKey ?? '');
    bool isTesting = false;
    String? testResult;
    bool? testSuccess;

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.vpn_key_rounded, color: AppColors.primary),
                SizedBox(width: 10),
                Text('Cấu hình Google Gemini API'),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gán Google Gemini API Key để mở khóa toàn bộ sức mạnh nhận dạng giọng nói, '
                    'gỡ băng ghi âm/video bài giảng và tóm tắt sư phạm chuẩn xác.',
                    style: TextStyle(fontSize: 13, color: AppColors.darkTextSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: keyController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Google Gemini API Key',
                      hintText: 'Dán khóa AIzaSy... tại đây',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.paste_rounded, size: 20),
                        tooltip: 'Dán từ clipboard',
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data != null && data.text != null) {
                            setDialogState(() {
                              keyController.text = data.text!.trim();
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: isTesting
                            ? null
                            : () async {
                                final inputKey = keyController.text.trim();
                                if (inputKey.isEmpty) {
                                  setDialogState(() {
                                    testResult = 'Vui lòng nhập mã khóa trước khi kiểm tra.';
                                    testSuccess = false;
                                  });
                                  return;
                                }
                                setDialogState(() {
                                  isTesting = true;
                                  testResult = null;
                                });
                                final ok = await GeminiService.validateKey(inputKey);
                                setDialogState(() {
                                  isTesting = false;
                                  testSuccess = ok;
                                  testResult = ok
                                      ? 'Kết nối Google Gemini thành công! Khóa API hợp lệ.'
                                      : 'Không thể kết nối. Vui lòng kiểm tra lại khóa API hoặc mạng.';
                                });
                              },
                        icon: isTesting
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.network_check_rounded, size: 16),
                        label: const Text('Kiểm tra khóa (Test API)'),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          if (Platform.isWindows) {
                            Process.run('cmd.exe', ['/c', 'start', 'https://aistudio.google.com/app/apikey']);
                          }
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 14),
                        label: const Text('Lấy khóa miễn phí (10s)'),
                      ),
                    ],
                  ),
                  if (testResult != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: (testSuccess == true ? Colors.green : Colors.red).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (testSuccess == true ? Colors.green : Colors.red).withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            testSuccess == true ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                            size: 16,
                            color: testSuccess == true ? Colors.green : Colors.redAccent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              testResult!,
                              style: TextStyle(
                                fontSize: 12,
                                color: testSuccess == true ? Colors.green : Colors.redAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
              FilledButton(
                onPressed: () async {
                  final key = keyController.text.trim();
                  if (key.isNotEmpty) {
                    await credService.setGeminiApiKey(key);
                    await _loadData();
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã mã hóa và lưu Google Gemini API Key an toàn!')),
                    );
                  }
                },
                child: const Text('Lưu khóa'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final jobsAsync = ref.watch(jobNotifierProvider);
    final filesAsync = ref.watch(fileLibraryNotifierProvider);

    final totalJobs = jobsAsync.maybeWhen(data: (j) => j.length, orElse: () => 0);
    final completedJobs = jobsAsync.maybeWhen(
      data: (j) => j.where((item) => item.status == JobStatus.completed).length,
      orElse: () => 0,
    );
    final totalFiles = filesAsync.maybeWhen(data: (f) => f.length, orElse: () => 0);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Welcome Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chào mừng đến với NguyenDu Tool',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Bàn làm việc số hỗ trợ Giáo viên & Nhà trường: Chuyển đổi PDF, Đọc văn bản AI và Gỡ băng Ghi âm/Video bằng Google Gemini.',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => context.go(AppRoutes.settings),
                  icon: const Icon(Icons.settings_rounded, size: 18),
                  label: const Text('Cài đặt hệ thống'),
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
            const SizedBox(height: 20),

            // 2. Google Gemini Hub Card
            _buildGeminiBanner(isDark),
            const SizedBox(height: 24),

            // 3. FEATURED CORE TEACHER TOOLS (Bộ 3 công cụ trọng tâm)
            _buildSectionHeader(
              'Bộ 3 Công cụ Trọng tâm Sư phạm',
              'Được tinh gọn và thiết kế riêng biệt theo nhu cầu thực tế của Thầy Cô trong trường học',
              isDark,
            ),
            const SizedBox(height: 14),
            _buildCoreTeacherToolsSection(isDark),
            const SizedBox(height: 28),

            // 4. Quick Stats Row
            Row(
              children: [
                QuickStatItem(
                  title: 'Tác vụ đã xử lý',
                  value: totalJobs.toString(),
                  icon: Icons.layers_rounded,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 14),
                QuickStatItem(
                  title: 'Hoàn tất thành công',
                  value: completedJobs.toString(),
                  icon: Icons.check_circle_rounded,
                  color: AppColors.success,
                ),
                const SizedBox(width: 14),
                QuickStatItem(
                  title: 'Kho học liệu số',
                  value: totalFiles.toString(),
                  icon: Icons.folder_rounded,
                  color: AppColors.moduleLibrary,
                ),
                const SizedBox(width: 14),
                const QuickStatItem(
                  title: 'Công cụ giáo viên',
                  value: '3 công cụ chính',
                  icon: Icons.school_rounded,
                  color: AppColors.secondary,
                ),
              ],
            ),
            const SizedBox(height: 28),

            // 5. SECTION: "Bạn muốn làm gì?" - Intent Quick Start
            _buildSectionHeader('Bạn muốn làm gì hôm nay?', 'Bắt đầu nhanh theo nhu cầu nghiệp vụ thực tế', isDark),
            const SizedBox(height: 12),
            _buildQuickStartIntents(isDark),
            const SizedBox(height: 28),

            // 6. SECTION: Recent Jobs
            const RecentJobsCard(),
            const SizedBox(height: 28),

            // 7. SECTION: All Modules (Preserved for compatibility and full suite access)
            _buildSectionHeader(
              'Tất cả phân hệ chuyên môn',
              'Được phân nhóm theo nghiệp vụ sư phạm & quản trị',
              isDark,
            ),
            const SizedBox(height: 12),
            _buildCategorizedModules(isDark),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildGeminiBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _hasGeminiKey
            ? const Color(0xFF1E3A8A).withOpacity(0.12)
            : const Color(0xFFD97706).withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _hasGeminiKey
              ? const Color(0xFF3B82F6).withOpacity(0.4)
              : const Color(0xFFD97706).withOpacity(0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (_hasGeminiKey ? const Color(0xFF3B82F6) : const Color(0xFFD97706)).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _hasGeminiKey ? Icons.auto_awesome_rounded : Icons.vpn_key_rounded,
              color: _hasGeminiKey ? const Color(0xFF60A5FA) : const Color(0xFFFBBF24),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      _hasGeminiKey
                          ? 'Google Gemini AI đã được kích hoạt'
                          : 'Gán Google Gemini API Key để dùng tính năng AI tốt nhất',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: _hasGeminiKey
                            ? (isDark ? Colors.white : const Color(0xFF1E3A8A))
                            : (isDark ? Colors.amber : const Color(0xFFB45309)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (_hasGeminiKey ? Colors.green : Colors.amber).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _hasGeminiKey ? 'Đã kết nối 🟢' : 'Chưa cấu hình 🟠',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _hasGeminiKey ? Colors.greenAccent : Colors.amber,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _hasGeminiKey
                      ? 'Đang cấp nguồn cho: Gỡ băng âm thanh/video bài giảng, nhận dạng tiếng Việt có dấu, tạo mốc thời gian và tóm tắt sư phạm.'
                      : 'Hoàn toàn miễn phí, nhận mã khóa tại Google AI Studio trong 10 giây để gỡ băng ghi âm bài giảng và video mượt mà.',
                  style: TextStyle(fontSize: 12.5, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => _showApiKeyDialog(context),
            icon: Icon(_hasGeminiKey ? Icons.check_circle_outline_rounded : Icons.add_rounded, size: 16),
            label: Text(_hasGeminiKey ? 'Quản lý khóa API' : 'Gán API Key ngay'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _hasGeminiKey ? const Color(0xFF2563EB) : const Color(0xFFD97706),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoreTeacherToolsSection(bool isDark) {
    const tools = [
      _CoreTool(
        title: 'Chuyển đổi File PDF',
        subtitle: 'Chuyển PDF sang Word (.docx), Excel (.xlsx) chỉnh sửa được, giữ nguyên lề và định dạng bảng biểu không cần Office.',
        badge: 'Giữ nguyên 📄',
        badgeColor: AppColors.modulePdf,
        icon: Icons.picture_as_pdf_rounded,
        gradientStart: Color(0xFFDC2626),
        gradientEnd: Color(0xFFEA580C),
        route: AppRoutes.pdfConverter,
        actionTitle: 'Mở Chuyển đổi PDF',
      ),
      _CoreTool(
        title: 'Văn bản thành Giọng nói AI',
        subtitle: 'Chuyển bài đọc, thông báo thành giọng nói tiếng Việt truyền cảm (Hoài My, Nam Minh), đồng bộ phụ đề và xuất file MP3.',
        badge: 'Giọng đọc AI 🎙️',
        badgeColor: AppColors.moduleTts,
        icon: Icons.record_voice_over_rounded,
        gradientStart: Color(0xFF059669),
        gradientEnd: Color(0xFF10B981),
        route: AppRoutes.textToSpeech,
        actionTitle: 'Mở Tạo Giọng nói',
      ),
      _CoreTool(
        title: 'Ghi âm & Video thành Văn bản',
        subtitle: 'Gỡ băng bài giảng, tiết dạy, cuộc họp từ tệp MP3, MP4, MKV thành Word (.docx), gắn mốc thời gian [mm:ss] và tóm tắt ý chính qua Gemini.',
        badge: 'Google Gemini 🎧',
        badgeColor: Color(0xFF3B82F6),
        icon: Icons.mic_rounded,
        gradientStart: Color(0xFF2563EB),
        gradientEnd: Color(0xFF7C3AED),
        route: AppRoutes.speechToText,
        actionTitle: 'Mở Gỡ băng AI',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        final cardWidth = isWide ? (constraints.maxWidth - 28) / 3 : constraints.maxWidth;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: tools.map((tool) {
            return SizedBox(
              width: cardWidth,
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () => context.go(tool.route),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [tool.gradientStart, tool.gradientEnd],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: tool.gradientStart.withOpacity(0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(tool.icon, color: Colors.white, size: 26),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: tool.badgeColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: tool.badgeColor.withOpacity(0.3)),
                              ),
                              child: Text(
                                tool.badge,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: tool.badgeColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          tool.title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tool.subtitle,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.45,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Text(
                              tool.actionTitle,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: tool.gradientStart,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.arrow_forward_rounded, size: 16, color: tool.gradientStart),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12.5,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStartIntents(bool isDark) {
    const intents = [
      _IntentAction(
        title: 'Chuyển PDF sang Word',
        subtitle: 'Giữ định dạng văn bản & bảng biểu',
        icon: Icons.picture_as_pdf_rounded,
        color: AppColors.modulePdf,
        route: AppRoutes.pdfConverter,
        moduleId: 'pdf_converter',
      ),
      _IntentAction(
        title: 'Tạo giọng đọc AI',
        subtitle: 'Chuyển bài đọc sang file âm thanh MP3',
        icon: Icons.record_voice_over_rounded,
        color: AppColors.moduleTts,
        route: AppRoutes.textToSpeech,
        moduleId: 'text_to_speech',
      ),
      _IntentAction(
        title: 'Gỡ băng Ghi âm / Video',
        subtitle: 'Nhận dạng lời nói tiếng Việt qua Gemini',
        icon: Icons.mic_rounded,
        color: Color(0xFF2563EB),
        route: AppRoutes.speechToText,
        moduleId: 'speech_to_text',
      ),
      _IntentAction(
        title: 'Cài đặt & Khóa Gemini',
        subtitle: 'Quản lý khóa API và thư mục làm việc',
        icon: Icons.settings_rounded,
        color: AppColors.secondary,
        route: AppRoutes.settings,
        moduleId: 'settings',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1100 ? 4 : (constraints.maxWidth > 650 ? 2 : 1);
        final itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * 12) / crossAxisCount;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: intents.map((item) {
            return SizedBox(
              width: itemWidth,
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () {
                    ref.read(moduleUsageServiceProvider).recordModuleOpened(item.moduleId);
                    context.go(item.route);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: item.color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(item.icon, size: 20, color: item.color),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.subtitle,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCategorizedModules(bool isDark) {
    final registry = ModuleRegistry.instance;
    final categories = [
      ModuleCategory.teaching,
      ModuleCategory.documents,
      ModuleCategory.media,
      ModuleCategory.system,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final cat in categories) ...[
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  cat.displayName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          _buildModuleGrid(registry.getModulesByCategory(cat), isDark),
        ],
      ],
    );
  }

  Widget _buildModuleGrid(List<ModuleDefinition> modules, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1100 ? 3 : (constraints.maxWidth > 700 ? 2 : 1);
        final itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * 12) / crossAxisCount;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: modules.map((module) {
            return SizedBox(
              width: itemWidth,
              child: ModuleCard.fromDefinition(
                module: module,
                onTap: () => _openModule(module),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _CoreTool {
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final IconData icon;
  final Color gradientStart;
  final Color gradientEnd;
  final String route;
  final String actionTitle;

  const _CoreTool({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.icon,
    required this.gradientStart,
    required this.gradientEnd,
    required this.route,
    required this.actionTitle,
  });
}

class _IntentAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
  final String moduleId;

  const _IntentAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
    required this.moduleId,
  });
}
