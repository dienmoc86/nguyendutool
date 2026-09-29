import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/jobs/domain/job_status.dart';
import '../../../../core/jobs/domain/job_type.dart';
import '../../../../core/providers/app_providers.dart';

/// Recent Jobs card on the Dashboard displaying task queues and live progress.
class RecentJobsCard extends ConsumerWidget {
  const RecentJobsCard({super.key});

  Color _getStatusColor(JobStatus status) {
    switch (status) {
      case JobStatus.completed:
        return AppColors.success;
      case JobStatus.running:
        return AppColors.primaryLight;
      case JobStatus.queued:
        return AppColors.warning;
      case JobStatus.failed:
        return AppColors.error;
      case JobStatus.cancelled:
        return AppColors.darkTextMuted;
    }
  }

  IconData _getTypeIcon(JobType type) {
    switch (type) {
      case JobType.pdfConvert:
        return Icons.picture_as_pdf_rounded;
      case JobType.ocr:
        return Icons.document_scanner_rounded;
      case JobType.scanProcess:
        return Icons.scanner_rounded;
      case JobType.ttsGenerate:
        return Icons.record_voice_over_rounded;
      case JobType.videoRender:
        return Icons.video_collection_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final jobsAsync = ref.watch(jobNotifierProvider);
    final jobNotifier = ref.read(jobNotifierProvider.notifier);
    final dateFormat = DateFormat('HH:mm:ss dd/MM');

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.history_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Tác vụ gần đây (Recent Jobs)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => jobNotifier.refreshJobs(),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Làm mới'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      jobNotifier.runDemoJob(
                        type: JobType.pdfConvert,
                        moduleName: 'PDF / Office Converter',
                      );
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label: const Text('Tạo tác vụ mẫu'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          jobsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Lỗi tải tác vụ: $err',
                style: const TextStyle(color: AppColors.error),
              ),
            ),
            data: (jobs) {
              if (jobs.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(
                        Icons.hourglass_empty_rounded,
                        size: 40,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Chưa có tác vụ nào trong hàng đợi.',
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Nhấn "Tạo tác vụ mẫu" để thử nghiệm quy trình không đồng bộ.',
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: jobs.length > 5 ? 5 : jobs.length,
                separatorBuilder: (_, __) => Divider(
                  height: 16,
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                itemBuilder: (context, index) {
                  final job = jobs[index];
                  final statusColor = _getStatusColor(job.status);

                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getTypeIcon(job.jobType),
                          color: statusColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              job.jobType.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ID: ${job.id.substring(0, 8)}... • ${job.moduleType}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Progress bar or status indicator
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: job.progress,
                                backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                                minHeight: 6,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${(job.progress * 100).toInt()}% • ${job.status.label}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      Text(
                        dateFormat.format(job.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Cancel or Delete
                      if (job.status.isActive)
                        IconButton(
                          tooltip: 'Hủy tác vụ',
                          icon: const Icon(Icons.cancel_outlined, size: 18, color: AppColors.error),
                          onPressed: () => jobNotifier.cancelJob(job.id),
                        )
                      else
                        IconButton(
                          tooltip: 'Xóa bản ghi',
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                          onPressed: () => jobNotifier.deleteJob(job.id),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
