import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/ken_burns_effect.dart';
import '../../application/video_studio_providers.dart';

/// Central preview canvas showing active scene composition, aspect ratio, titles, and motion badges.
class VideoPreviewCanvas extends ConsumerWidget {
  const VideoPreviewCanvas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(videoStudioNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scene = state.selectedScene;
    final aspectRatio = state.currentProject.aspectRatio;

    return Container(
      color: isDark ? const Color(0xFF121418) : const Color(0xFFE8ECEF),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: AspectRatio(
          aspectRatio: aspectRatio.value,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Background Image or Placeholder
                if (scene != null && scene.hasImage && File(scene.backgroundImagePath!).existsSync())
                  Image.file(
                    File(scene.backgroundImagePath!),
                    fit: scene.blurBackground ? BoxFit.contain : BoxFit.cover,
                  )
                else
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0F2043), Color(0xFF1E3A8A)],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            scene?.hasVideoClip == true ? Icons.movie_outlined : Icons.image_outlined,
                            size: 48,
                            color: Colors.white38,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            scene?.hasVideoClip == true
                                ? 'Đoạn video: ${scene?.videoClipPath?.split(r"\").last ?? ""}'
                                : 'Chọn hình ảnh hoặc video cho phân cảnh',
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 2. Title & Subtitle Overlay Preview
                if (scene != null && (scene.title != null || scene.subtitle != null))
                  Positioned(
                    top: 24,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (scene.title != null && scene.title!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              scene.title!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        if (scene.subtitle != null && scene.subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              scene.subtitle!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFFDE047),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                // 3. Subtitles / Narration Bottom Strip Preview
                if (scene != null &&
                    (scene.narrationText != null && scene.narrationText!.isNotEmpty))
                  Positioned(
                    bottom: 24,
                    left: 24,
                    right: 24,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.70),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        scene.narrationText!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                // 4. Ken Burns motion badge
                if (scene != null && scene.kenBurns != KenBurnsEffect.none)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.motion_photos_on_rounded, size: 12, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            scene.kenBurns.displayName.split(' ').first,
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 5. Scene Info Badge
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Cảnh ${(state.selectedSceneIndex + 1)}/${state.currentProject.scenes.length} • ${(scene?.durationSeconds ?? 5.0).toStringAsFixed(1)}s',
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
