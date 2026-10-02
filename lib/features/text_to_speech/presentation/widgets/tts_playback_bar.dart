import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/filesystem/workspace_manager.dart';
import '../../application/tts_providers.dart';
import '../../application/tts_state.dart';

/// Bottom Audio Playback and Speech Generation control bar.
class TtsPlaybackBar extends ConsumerWidget {
  const TtsPlaybackBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ttsStateProvider);
    final notifier = ref.read(ttsStateProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isPlaying = state.playbackStatus == AudioPlaybackStatus.playing;
    final hasAudio = state.currentAudioPath != null;

    final totalMs = state.totalDuration.inMilliseconds;
    final currentMs = state.currentPosition.inMilliseconds;
    final sliderMax = totalMs > 0 ? totalMs.toDouble() : 1.0;
    final sliderVal = currentMs.clamp(0, sliderMax.toInt()).toDouble();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Generation Progress Bar & Status (if active)
          if (state.isSynthesizing) ...[
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.moduleTts),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    state.currentStage.isEmpty ? 'Đang tổng hợp giọng nói...' : state.currentStage,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.moduleTts),
                  ),
                ),
                Text(
                  '${(state.synthesisProgress * 100).toInt()}%',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => notifier.cancelSynthesis(),
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                  child: const Text('Hủy bỏ'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: state.synthesisProgress > 0 ? state.synthesisProgress : null,
                minHeight: 6,
                backgroundColor: Colors.grey.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.moduleTts),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Playback timeline and controls
          Row(
            children: [
              // Play/Pause Button
              IconButton(
                iconSize: 32,
                color: AppColors.moduleTts,
                icon: Icon(isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded),
                onPressed: hasAudio
                    ? () {
                        if (isPlaying) {
                          notifier.pauseAudio();
                        } else {
                          notifier.playAudio();
                        }
                      }
                    : null,
              ),

              // Stop Button
              IconButton(
                iconSize: 24,
                icon: const Icon(Icons.stop_rounded),
                onPressed: hasAudio ? () => notifier.stopAudio() : null,
              ),

              const SizedBox(width: 8),

              // Current Position Text
              Text(
                _formatTime(state.currentPosition),
                style: const TextStyle(fontSize: 12, fontFamily: 'Consolas'),
              ),

              // Seek Slider
              Expanded(
                child: Slider(
                  value: sliderVal,
                  min: 0.0,
                  max: sliderMax,
                  activeColor: AppColors.moduleTts,
                  inactiveColor: Colors.grey.withOpacity(0.3),
                  onChanged: hasAudio && totalMs > 0
                      ? (val) => notifier.seekAudio(Duration(milliseconds: val.round()))
                      : null,
                ),
              ),

              // Total Duration Text
              Text(
                _formatTime(state.totalDuration),
                style: const TextStyle(fontSize: 12, fontFamily: 'Consolas'),
              ),

              const SizedBox(width: 16),

              // Volume Slider
              const Icon(Icons.volume_up_rounded, size: 18, color: Colors.grey),
              SizedBox(
                width: 100,
                child: Slider(
                  value: state.playbackVolume,
                  min: 0.0,
                  max: 1.0,
                  activeColor: AppColors.moduleTts,
                  onChanged: (val) => notifier.setPlaybackVolume(val),
                ),
              ),

              const SizedBox(width: 16),
              const VerticalDivider(width: 20),

              if (hasAudio) ...[
                Tooltip(
                  message: 'Mở nghe tệp âm thanh trực tiếp',
                  child: OutlinedButton.icon(
                    onPressed: () => WorkspaceManager.openFile(state.currentAudioPath!),
                    icon: const Icon(Icons.audio_file_rounded, size: 16),
                    label: const Text('Mở tệp', style: TextStyle(fontSize: 12.5)),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Mở thư mục chứa tệp MP3',
                  child: IconButton(
                    onPressed: () => WorkspaceManager.openContainingFolder(state.currentAudioPath!),
                    icon: const Icon(Icons.folder_open_rounded, color: AppColors.moduleTts, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
              ],

              // Generate Button
              ElevatedButton.icon(
                onPressed: state.isSynthesizing ? null : () => notifier.generateSpeech(),
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: const Text('Tạo giọng đọc (TTS)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.moduleTts,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
