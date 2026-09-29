import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/jobs/domain/job_status.dart';
import '../../../core/providers/app_providers.dart';
import 'widgets/module_card.dart';
import 'widgets/quick_stats_card.dart';
import 'widgets/recent_jobs_card.dart';

/// Main Dashboard Screen for NguyenDu Tool desktop application.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final jobsAsync = ref.watch(jobNotifierProvider);
    final filesAsync = ref.watch(fileLibraryNotifierProvider);
    final providerRegistry = ref.watch(providerRegistryProvider);

    // Calculate quick statistics
    final totalJobs = jobsAsync.maybeWhen(data: (j) => j.length, orElse: () => 0);
    final completedJobs = jobsAsync.maybeWhen(
      data: (j) => j.where((item) => item.status == JobStatus.completed).length,
      orElse: () => 0,
    );
    final totalFiles = filesAsync.maybeWhen(data: (f) => f.length, orElse: () => 0);
    final totalProviders = providerRegistry.listProviders().length;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
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
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Trợ lý số Giáo viên & Nhà trường: Bộ công cụ chuyên dụng cho Thầy Cô chuyển đổi Giáo án, Đề thi, Sổ điểm, Bài giảng PowerPoint, Quét số hóa học liệu và Dựng video E-Learning.',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Quick Stats Row
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
                QuickStatItem(
                  title: 'Động cơ & Tiện ích',
                  value: '$totalProviders khả dụng',
                  icon: Icons.school_rounded,
                  color: AppColors.secondary,
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Section: 4 Major Functional Modules
            Text(
              'Các phân hệ chuyên môn cho Giáo viên & Nhà trường',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 14),

            // 4 Big Cards Grid
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 700 ? 2 : 1);
                final itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * 16) / crossAxisCount;

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      height: 226,
                      child: ModuleCard(
                        title: 'Soạn Giáo án AI (5512)',
                        subtitle: 'Soạn Kế hoạch bài dạy chuẩn Công văn 5512 bằng Google Gemini AI, tự động sinh rubric và xuất file Word (.docx).',
                        icon: Icons.auto_awesome_rounded,
                        accentColor: AppColors.accentViolet,
                        statusBadge: 'Công văn 5512 AI',
                        onTap: () => context.go(AppRoutes.lessonPlanner),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      height: 226,
                      child: ModuleCard(
                        title: 'PDF → Word / Excel',
                        subtitle: 'Chuyển đổi PDF, nhận diện tài liệu scan và trích xuất bảng biểu, giáo án, bài giảng PowerPoint (.pptx).',
                        icon: Icons.picture_as_pdf_rounded,
                        accentColor: AppColors.modulePdf,
                        statusBadge: 'Word / Excel / PPTX',
                        onTap: () => context.go(AppRoutes.pdfConverter),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      height: 226,
                      child: ModuleCard(
                        title: 'Document Scanner',
                        subtitle: 'Scan, làm sạch tài liệu và tạo PDF searchable, số hóa đề thi và sổ sách học đường.',
                        icon: Icons.scanner_rounded,
                        accentColor: AppColors.moduleScanner,
                        statusBadge: 'OCR Đề thi & Sổ sách',
                        onTap: () => context.go(AppRoutes.scanner),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      height: 226,
                      child: ModuleCard(
                        title: 'Text to Speech',
                        subtitle: 'Chuyển văn bản thành giọng nói và xuất MP3/WAV, đọc bài giảng và phát âm chuẩn.',
                        icon: Icons.record_voice_over_rounded,
                        accentColor: AppColors.moduleTts,
                        statusBadge: 'Giọng đọc AI',
                        onTap: () => context.go(AppRoutes.textToSpeech),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      height: 226,
                      child: ModuleCard(
                        title: 'Video Studio',
                        subtitle: 'Tạo video từ nội dung, giọng đọc, hình ảnh và phụ đề cho bài giảng điện tử E-Learning.',
                        icon: Icons.video_collection_rounded,
                        accentColor: AppColors.moduleVideo,
                        statusBadge: 'E-Learning Studio',
                        onTap: () => context.go(AppRoutes.videoStudio),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 28),

            // Recent Jobs Section
            const RecentJobsCard(),
          ],
        ),
      ),
    );
  }
}
