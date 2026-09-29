import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/models/video_export_settings.dart';
import '../../application/video_studio_providers.dart';

/// Top action and settings bar for Video Studio.
class VideoTopBar extends ConsumerWidget {
  const VideoTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(videoStudioNotifierProvider);
    final notifier = ref.read(videoStudioNotifierProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
      ),
      child: Row(
        children: [
          // Project icon & editable title
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.moduleVideo.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.movie_creation_rounded, color: AppColors.moduleVideo, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.currentProject.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${state.currentProject.scenes.length} cảnh • ${state.currentProject.totalDurationSeconds.toStringAsFixed(1)}s • ${state.currentProject.aspectRatio.ratioString} • ${state.currentProject.resolution.displayName.split(' ').first}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),

          // Aspect Ratio Selector
          PopupMenuButton<VideoAspectRatio>(
            tooltip: 'Tỷ lệ khung hình',
            initialValue: state.currentProject.aspectRatio,
            onSelected: (ratio) => notifier.updateProjectFormat(aspectRatio: ratio),
            itemBuilder: (context) => VideoAspectRatio.values.map((r) {
              return PopupMenuItem(
                value: r,
                child: Text(r.displayName),
              );
            }).toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: isDark ? Colors.white24 : Colors.black26),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.aspect_ratio_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text(state.currentProject.aspectRatio.ratioString, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Resolution Selector
          PopupMenuButton<VideoResolution>(
            tooltip: 'Độ phân giải',
            initialValue: state.currentProject.resolution,
            onSelected: (res) => notifier.updateProjectFormat(resolution: res),
            itemBuilder: (context) => VideoResolution.values.map((res) {
              return PopupMenuItem(
                value: res,
                child: Text(res.displayName),
              );
            }).toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: isDark ? Colors.white24 : Colors.black26),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hd_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text(state.currentProject.resolution == VideoResolution.res1080p ? '1080p' : '720p',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Mode toggle: Simple / Advanced
          OutlinedButton.icon(
            onPressed: notifier.toggleSimpleMode,
            icon: Icon(
              state.isSimpleMode ? Icons.tune_rounded : Icons.flash_on_rounded,
              size: 16,
            ),
            label: Text(state.isSimpleMode ? 'Nâng cao' : 'Đơn giản'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(width: 10),

          // Save button
          OutlinedButton.icon(
            onPressed: () async {
              await notifier.saveProject();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã lưu dự án video thành công.')),
                );
              }
            },
            icon: const Icon(Icons.save_outlined, size: 16),
            label: const Text('Lưu dự án'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(width: 10),

          // Render / Export button
          ElevatedButton.icon(
            onPressed: state.isRendering ? null : () => _showExportDialog(context, ref),
            icon: state.isRendering
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.video_library_rounded, size: 18),
            label: Text(state.isRendering ? 'Đang xuất...' : 'Xuất Video MP4'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.moduleVideo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.video_library_rounded, color: AppColors.moduleVideo),
            SizedBox(width: 10),
            Text('Xác nhận Xuất Video MP4'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Video sẽ được kết xuất bằng động cơ FFmpeg cục bộ trên máy tính của bạn.'),
            SizedBox(height: 12),
            Text('• Định dạng: MP4 (H.264 / AAC 192k)'),
            Text('• Chuyển cảnh: Tự động ghép nối hiệu ứng mượt mà'),
            Text('• Âm thanh: Hòa âm thuyết minh, nhạc nền và Audio Ducking'),
            Text('• Phụ đề: Khắc chữ tiếng Việt (Burn-in subtitles)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.moduleVideo, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(videoStudioNotifierProvider.notifier).startRender();
            },
            child: const Text('Bắt đầu Render'),
          ),
        ],
      ),
    );
  }
}
