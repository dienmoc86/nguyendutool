import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import 'widgets/video_left_panel.dart';
import 'widgets/video_preview_canvas.dart';
import 'widgets/video_scene_inspector.dart';
import 'widgets/video_timeline_bottom.dart';
import 'widgets/video_top_bar.dart';

/// Main Video Studio desktop workstation screen assembling the 5-panel layout.
class VideoStudioScreen extends StatelessWidget {
  const VideoStudioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: const Column(
        children: [
          // 1. Top Action & Navigation Bar
          VideoTopBar(),

          // 2. Middle Tri-Panel: Left Scenes / Center Canvas / Right Inspector
          Expanded(
            child: Row(
              children: [
                // Left Panel: Scene Reordering & Templates
                VideoLeftPanel(),

                // Center Panel: Preview Canvas
                Expanded(
                  child: VideoPreviewCanvas(),
                ),

                // Right Panel: Scene Inspector
                VideoSceneInspector(),
              ],
            ),
          ),

          // 3. Bottom Timeline & Audio Ducking Strip
          VideoTimelineBottom(),
        ],
      ),
    );
  }
}
