import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/platform/native_file_dialog.dart';
import '../../domain/models/audio_ducking_level.dart';
import '../../application/video_studio_providers.dart';

/// Bottom desktop timeline displaying scenes strip, transitions, and audio ducking controls.
class VideoTimelineBottom extends ConsumerWidget {
  const VideoTimelineBottom({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(videoStudioNotifierProvider);
    final notifier = ref.read(videoStudioNotifierProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final project = state.currentProject;

    return Container(
      height: 190,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
      ),
      child: Column(
        children: [
          // 1. Timeline Controls Header
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.timeline_rounded, size: 16, color: AppColors.moduleVideo),
                const SizedBox(width: 8),
                Text(
                  'Dòng thời gian (Timeline) • ${project.scenes.length} cảnh • Tổng: ${project.totalDurationSeconds.toStringAsFixed(1)}s',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                const Spacer(),

                // Background Music Picker
                OutlinedButton.icon(
                  onPressed: () async {
                    final res = await NativeFileDialog.pickAudioFiles();
                    if (res.isSelected && res.paths.isNotEmpty) {
                      notifier.setBackgroundMusic(res.paths.first);
                    }
                  },
                  icon: const Icon(Icons.music_note_rounded, size: 14),
                  label: Text(
                    project.backgroundMusicPath != null
                        ? 'Nhạc: ${project.backgroundMusicPath!.split(r"\").last}'
                        : 'Thêm nhạc nền...',
                    style: const TextStyle(fontSize: 11),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),

                // Audio Ducking Preset Picker
                PopupMenuButton<AudioDuckingLevel>(
                  tooltip: 'Tự giảm nhạc khi có giọng thuyết minh (Audio Ducking)',
                  initialValue: project.audioDucking,
                  onSelected: (d) => notifier.setBackgroundMusic(project.backgroundMusicPath, ducking: d),
                  itemBuilder: (context) => AudioDuckingLevel.values.map((d) {
                    return PopupMenuItem(
                      value: d,
                      child: Text('Ducking: ${d.displayName}'),
                    );
                  }).toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? Colors.white24 : Colors.black26),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.graphic_eq_rounded, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Ducking: ${project.audioDucking.displayName.split(' ').first}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Render Progress Bar (Visible when rendering)
          if (state.isRendering)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.moduleVideo.withOpacity(0.12),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.moduleVideo),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              state.renderStage,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.moduleVideo),
                            ),
                            Text(
                              '${(state.renderProgress * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: state.renderProgress > 0 ? state.renderProgress : null,
                          backgroundColor: Colors.white24,
                          color: AppColors.moduleVideo,
                          minHeight: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: 'Hủy render',
                    icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
                    onPressed: () => notifier.cancelRender(),
                  ),
                ],
              ),
            ),

          // 3. Scene Strips Horizontal Scroll
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: project.scenes.length,
              separatorBuilder: (context, index) {
                // Transition indicator badge between scenes
                final scene = project.scenes[index];
                return Center(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.black12,
                      shape: BoxShape.circle,
                    ),
                    child: Tooltip(
                      message: 'Chuyển cảnh: ${scene.transition.type.displayName} (${scene.transition.durationSeconds}s)',
                      child: const Icon(Icons.arrow_forward_ios_rounded, size: 10),
                    ),
                  ),
                );
              },
              itemBuilder: (context, index) {
                final scene = project.scenes[index];
                final isSelected = index == state.selectedSceneIndex;

                return GestureDetector(
                  onTap: () => notifier.selectScene(index),
                  child: Container(
                    width: 130,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.moduleVideo.withOpacity(0.2)
                          : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)),
                      border: Border.all(
                        color: isSelected ? AppColors.moduleVideo : (isDark ? Colors.white12 : Colors.black12),
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Thumbnail preview
                        Expanded(
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                            ),
                            child: scene.hasImage && File(scene.backgroundImagePath!).existsSync()
                                ? ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                    child: Image.file(
                                      File(scene.backgroundImagePath!),
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    ),
                                  )
                                : Center(
                                    child: Icon(
                                      scene.hasVideoClip ? Icons.videocam_rounded : Icons.image_rounded,
                                      size: 24,
                                      color: Colors.white30,
                                    ),
                                  ),
                          ),
                        ),

                        // Title & duration footer
                        Padding(
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                scene.title?.isNotEmpty == true ? scene.title! : 'Cảnh ${index + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${scene.durationSeconds.toStringAsFixed(1)}s',
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                  if (scene.hasVoiceover)
                                    const Icon(Icons.mic_rounded, size: 12, color: Colors.green),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
