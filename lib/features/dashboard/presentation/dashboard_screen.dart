import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/jobs/domain/job_status.dart';
import '../../../core/providers/app_providers.dart';
import 'widgets/quick_stats_card.dart';
import 'widgets/recent_jobs_card.dart';

/// Streamlined Teacher Dashboard for NguyenDu Tool.
/// Focuses squarely on the 2 core productivity tools for school teachers:
/// 1. PDF to Word/Excel Converter (preserved, high-fidelity ECMA-376)
/// 2. Natural Vietnamese Text-to-Speech (Hoài My & Nam Minh Neural)
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final jobsAsync = ref.watch(jobNotifierProvider);

    final totalJobs = jobsAsync.maybeWhen(data: (j) => j.length, orElse: () => 0);
    final completedJobs = jobsAsync.maybeWhen(
      data: (j) => j.where((item) => item.status == JobStatus.completed).length,
      orElse: () => 0,
    );

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
                        'Phần mềm hỗ trợ Thầy Cô: Chuyển đổi PDF sang Word chuẩn và Chuyển văn bản thành giọng nói tiếng Việt tự nhiên.',
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
            const SizedBox(height: 24),

            // 2. FEATURED CORE TEACHER TOOLS (2 công cụ trọng tâm)
            _buildSectionHeader(
              '2 Công cụ Trọng tâm Sư phạm',
              'Được tinh gọn và thiết kế riêng biệt theo nhu cầu thực tế của Thầy Cô trong trường học',
              isDark,
            ),
            const SizedBox(height: 14),
            _buildCoreTeacherToolsSection(isDark),
            const SizedBox(height: 28),

            // 3. Quick Stats Row
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
                const QuickStatItem(
                  title: 'Công cụ giáo viên',
                  value: '2 công cụ chính',
                  icon: Icons.school_rounded,
                  color: AppColors.secondary,
                ),
              ],
            ),
            const SizedBox(height: 28),

            // 4. SECTION: Recent Jobs
            const RecentJobsCard(),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildCoreTeacherToolsSection(bool isDark) {
    const tools = [
      _CoreTool(
        title: 'Chuyển đổi File PDF sang Word',
        subtitle: 'Kéo thả file PDF giáo án, tài liệu để chuyển sang Word (.docx) và Excel (.xlsx). Giữ nguyên định dạng bảng biểu, tự nắn thẳng trang, mở xem ngay sau khi chuyển.',
        badge: 'Trọng tâm 📄',
        badgeColor: AppColors.modulePdf,
        icon: Icons.picture_as_pdf_rounded,
        gradientStart: Color(0xFFDC2626),
        gradientEnd: Color(0xFFEA580C),
        route: AppRoutes.pdfConverter,
        actionTitle: 'Mở Chuyển đổi PDF',
      ),
      _CoreTool(
        title: 'Chuyển Văn bản thành Giọng nói (TTS)',
        subtitle: 'Đọc văn bản bài giảng, thông báo thành giọng nói tiếng Việt chuẩn tự nhiên (Hoài My - Nữ, Nam Minh - Nam). Nghe thử tức thì và xuất file MP3 chất lượng cao.',
        badge: 'Giọng đọc AI 🎙️',
        badgeColor: AppColors.moduleTts,
        icon: Icons.record_voice_over_rounded,
        gradientStart: Color(0xFF059669),
        gradientEnd: Color(0xFF10B981),
        route: AppRoutes.textToSpeech,
        actionTitle: 'Mở Đọc văn bản (TTS)',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        final cardWidth = isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
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
