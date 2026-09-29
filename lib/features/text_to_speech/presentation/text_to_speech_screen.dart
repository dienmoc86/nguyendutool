import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../application/tts_providers.dart';
import 'widgets/tts_editor_panel.dart';
import 'widgets/tts_input_selector.dart';
import 'widgets/tts_playback_bar.dart';
import 'widgets/tts_voice_selector.dart';

/// Production Text to Speech (TTS) Module Screen for NguyenDu Tool.
/// Implements 3-column desktop layout:
/// - Left: Document input source picker (Manual, TXT, DOCX, PDF, Library)
/// - Center: Text Editor with Vietnamese-aware normalization and preview
/// - Right: Voice enumeration (Local/Cloud), presets, speed/pitch/pause controls
/// - Bottom: Native audio player controls, seekbar, and synthesis action bar
class TextToSpeechScreen extends ConsumerWidget {
  const TextToSpeechScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ttsStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Status messages banner (Success / Error)
            if (state.errorMessage != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        state.errorMessage!,
                        style: const TextStyle(fontSize: 13, color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (state.successMessage != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        state.successMessage!,
                        style: const TextStyle(fontSize: 13, color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 3-Column Core Workspace
            const Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left: Input / Document selector (width ~260)
                  SizedBox(
                    width: 260,
                    child: TtsInputSelector(),
                  ),
                  SizedBox(width: 16),

                  // Center: Text Editor (Expanded flex 3)
                  Expanded(
                    flex: 3,
                    child: TtsEditorPanel(),
                  ),
                  SizedBox(width: 16),

                  // Right: Voice & Settings (width ~340)
                  SizedBox(
                    width: 340,
                    child: SingleChildScrollView(
                      child: TtsVoiceSelector(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Bottom: Audio Player + Synthesis Action Bar
            const TtsPlaybackBar(),
          ],
        ),
      ),
    );
  }
}
