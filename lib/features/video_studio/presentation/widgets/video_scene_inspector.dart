import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/platform/native_file_dialog.dart';
import '../../domain/models/ken_burns_effect.dart';
import '../../domain/models/transition.dart';
import '../../domain/models/video_scene.dart';
import '../../application/video_studio_providers.dart';

/// Right panel inspector for editing active scene attributes, narration, voiceover, and transitions.
class VideoSceneInspector extends ConsumerStatefulWidget {
  const VideoSceneInspector({super.key});

  @override
  ConsumerState<VideoSceneInspector> createState() => _VideoSceneInspectorState();
}

class _VideoSceneInspectorState extends ConsumerState<VideoSceneInspector> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subtitleController = TextEditingController();
  final TextEditingController _narrationController = TextEditingController();

  int _lastSceneIndex = -1;

  void _syncControllers(VideoScene? scene, int index) {
    if (scene == null) return;
    if (_lastSceneIndex != index) {
      _titleController.text = scene.title ?? '';
      _subtitleController.text = scene.subtitle ?? '';
      _narrationController.text = scene.narrationText ?? '';
      _lastSceneIndex = index;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _narrationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(videoStudioNotifierProvider);
    final notifier = ref.read(videoStudioNotifierProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scene = state.selectedScene;
    final sceneIndex = state.selectedSceneIndex;

    _syncControllers(scene, sceneIndex);

    if (scene == null) {
      return Container(
        width: 320,
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        child: const Center(child: Text('Chưa chọn phân cảnh nào.')),
      );
    }

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          left: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Inspector Header
          Row(
            children: [
              const Icon(Icons.tune_rounded, color: AppColors.moduleVideo, size: 20),
              const SizedBox(width: 8),
              Text(
                'Thuộc tính cảnh ${sceneIndex + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Section 1: Media Asset
          const Text('1. Hình ảnh / Video nền', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final result = await NativeFileDialog.pickVideoStudioMediaFiles();
              if (result.isSelected && result.paths.isNotEmpty) {
                final path = result.paths.first;
                final ext = path.toLowerCase();
                if (ext.endsWith('.mp4') || ext.endsWith('.mov')) {
                  notifier.updateSceneMedia(sceneIndex, videoPath: path);
                } else {
                  notifier.updateSceneMedia(sceneIndex, imagePath: path);
                }
              }
            },
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
            label: Text(
              scene.hasImage
                  ? 'Đổi ảnh nền (${scene.backgroundImagePath?.split(r"\").last ?? ""})'
                  : (scene.hasVideoClip ? 'Đổi video nền' : 'Chọn tệp hình ảnh / video...'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),

          // Framing mode: Fit / Fill / Crop
          if (!scene.hasVideoClip) ...[
            DropdownButtonFormField<ImageFitMode>(
              value: scene.imageFitMode,
              decoration: const InputDecoration(
                labelText: 'Kiểu khớp ảnh (Framing)',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: ImageFitMode.values.map((mode) {
                return DropdownMenuItem(
                  value: mode,
                  child: Text(mode.displayName.split(' ').first),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  notifier.updateScene(sceneIndex, scene.copyWith(imageFitMode: val));
                }
              },
            ),
            const SizedBox(height: 10),

            // Blur Background Switch
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Làm mờ nền viền', style: TextStyle(fontSize: 12)),
              value: scene.blurBackground,
              onChanged: (val) {
                notifier.updateScene(sceneIndex, scene.copyWith(blurBackground: val));
              },
            ),
            const SizedBox(height: 10),

            // Ken Burns Motion
            DropdownButtonFormField<KenBurnsEffect>(
              value: scene.kenBurns,
              decoration: const InputDecoration(
                labelText: 'Hiệu ứng chuyển động (Ken Burns)',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: KenBurnsEffect.values.map((k) {
                return DropdownMenuItem(
                  value: k,
                  child: Text(k.displayName),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  notifier.updateSceneMotion(sceneIndex, val);
                }
              },
            ),
            const SizedBox(height: 16),
          ],

          const Divider(),
          const SizedBox(height: 10),

          // Section 2: Titles & Text
          const Text('2. Tiêu đề & Văn bản', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Tiêu đề cảnh',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (val) => notifier.updateSceneText(sceneIndex, title: val),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _subtitleController,
            decoration: const InputDecoration(
              labelText: 'Tiêu đề phụ / Chú thích',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (val) => notifier.updateSceneText(sceneIndex, subtitle: val),
          ),
          const SizedBox(height: 16),

          const Divider(),
          const SizedBox(height: 10),

          // Section 3: Narration & TTS Voiceover
          const Text('3. Lời thuyết minh & Giọng đọc', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _narrationController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Nội dung thuyết minh (TTS)',
              hintText: 'Nhập nội dung để chuyển thành giọng đọc ngoại tuyến...',
              border: OutlineInputBorder(),
            ),
            onChanged: (val) => notifier.updateSceneText(sceneIndex, narrationText: val),
          ),
          const SizedBox(height: 8),

          // TTS Voiceover Action Button
          ElevatedButton.icon(
            onPressed: () async {
              if (_narrationController.text.trim().isEmpty) return;
              await notifier.generateVoiceoverForScene(sceneIndex);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã tổng hợp giọng đọc ngoại tuyến cho phân cảnh!')),
                );
              }
            },
            icon: const Icon(Icons.record_voice_over_rounded, size: 16),
            label: Text(
              scene.hasVoiceover
                  ? 'Tạo lại giọng đọc (${(scene.voiceoverDurationSeconds ?? 0).toStringAsFixed(1)}s)'
                  : 'Tạo giọng đọc ngoại tuyến',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.moduleTts,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(height: 16),

          const Divider(),
          const SizedBox(height: 10),

          // Section 4: Transition & Duration
          const Text('4. Hiệu ứng chuyển cảnh & Thời lượng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          DropdownButtonFormField<TransitionType>(
            value: scene.transition.type,
            decoration: const InputDecoration(
              labelText: 'Hiệu ứng chuyển cảnh',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: TransitionType.values.map((t) {
              return DropdownMenuItem(
                value: t,
                child: Text(t.displayName),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                notifier.updateSceneTransition(
                  sceneIndex,
                  SceneTransition(type: val, durationSeconds: scene.transition.durationSeconds),
                );
              }
            },
          ),
          const SizedBox(height: 14),

          // Duration Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Thời lượng phân cảnh:', style: TextStyle(fontSize: 12)),
              Text(
                '${scene.durationSeconds.toStringAsFixed(1)}s',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.moduleVideo),
              ),
            ],
          ),
          Slider(
            min: 1.0,
            max: 30.0,
            divisions: 58,
            value: scene.durationSeconds.clamp(1.0, 30.0),
            onChanged: (val) => notifier.updateSceneDuration(sceneIndex, val),
          ),
        ],
      ),
    );
  }
}
