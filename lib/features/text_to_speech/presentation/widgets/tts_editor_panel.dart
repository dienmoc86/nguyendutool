import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../application/tts_providers.dart';
import 'pronunciation_dictionary_dialog.dart';

/// Text Editor Panel for TTS featuring open file, paste, clear, character count,
/// estimated reading duration, and normalized preview toggle.
class TtsEditorPanel extends ConsumerStatefulWidget {
  const TtsEditorPanel({super.key});

  @override
  ConsumerState<TtsEditorPanel> createState() => _TtsEditorPanelState();
}

class _TtsEditorPanelState extends ConsumerState<TtsEditorPanel> {
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    final initialText = ref.read(ttsStateProvider).rawText;
    _textController = TextEditingController(text: initialText);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && data!.text!.isNotEmpty) {
      _textController.text = data.text!;
      ref.read(ttsStateProvider.notifier).setText(data.text!);
    }
  }

  void _clearText() {
    _textController.clear();
    ref.read(ttsStateProvider.notifier).clearText();
  }

  void _openPronunciationDialog() {
    showDialog(
      context: context,
      builder: (context) => const PronunciationDictionaryDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ttsStateProvider);
    final notifier = ref.read(ttsStateProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Sync external changes (e.g. document import)
    if (_textController.text != state.rawText) {
      _textController.text = state.rawText;
      _textController.selection = TextSelection.collapsed(offset: _textController.text.length);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toolbar
          Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: AppColors.moduleTts, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Nội dung kịch bản văn bản',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              // Source File Badge if loaded
              if (state.inputSourceName != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.moduleTts.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.moduleTts.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.description_outlined, size: 14, color: AppColors.moduleTts),
                      const SizedBox(width: 6),
                      Text(
                        state.inputSourceName!,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.moduleTts),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
              ],

              // Pronunciation Dictionary Button
              IconButton(
                tooltip: 'Từ điển phát âm & Phiên âm viết tắt',
                icon: const Icon(Icons.spellcheck_rounded, size: 20),
                onPressed: _openPronunciationDialog,
              ),

              // Paste Button
              IconButton(
                tooltip: 'Dán từ bộ nhớ tạm',
                icon: const Icon(Icons.content_paste_rounded, size: 20),
                onPressed: _pasteFromClipboard,
              ),

              // Clear Button
              IconButton(
                tooltip: 'Xóa toàn bộ nội dung',
                icon: const Icon(Icons.clear_all_rounded, size: 20),
                onPressed: _clearText,
              ),

              const SizedBox(width: 8),

              // Toggle Normalized Preview
              OutlinedButton.icon(
                onPressed: () => notifier.toggleNormalizedPreview(),
                icon: Icon(
                  state.showNormalizedPreview ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  size: 16,
                  color: state.showNormalizedPreview ? AppColors.moduleTts : null,
                ),
                label: Text(
                  state.showNormalizedPreview ? 'Xem gốc' : 'Xem chuẩn hóa',
                  style: TextStyle(
                    fontSize: 12,
                    color: state.showNormalizedPreview ? AppColors.moduleTts : null,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: state.showNormalizedPreview ? AppColors.moduleTts : Colors.grey.withOpacity(0.4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Editor Field / Normalized View
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: state.showNormalizedPreview
                  ? SingleChildScrollView(
                      child: SelectableText(
                        state.normalizedText.isEmpty ? '(Chưa có nội dung văn bản để chuẩn hóa)' : state.normalizedText,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          fontFamily: 'Consolas',
                          color: isDark ? Colors.tealAccent : Colors.teal.shade800,
                        ),
                      ),
                    )
                  : TextField(
                      controller: _textController,
                      maxLines: null,
                      expands: true,
                      style: const TextStyle(fontSize: 14, height: 1.6),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Nhập hoặc dán văn bản bài giảng, thông báo vào đây...',
                      ),
                      onChanged: (text) => notifier.setText(text),
                    ),
            ),
          ),
          const SizedBox(height: 10),

          // Footer Status: Characters, Words, Estimated Duration
          Row(
            children: [
              Text(
                'Ký tự: ${state.characterCount}  |  Từ: ${state.wordCount}',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(width: 16),
              Text(
                'Thời lượng ước tính: ~${_formatDuration(state.estimatedDuration)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.moduleTts),
              ),
              const Spacer(),
              if (state.currentStage.isNotEmpty)
                Text(
                  state.currentStage,
                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.blueAccent),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    if (minutes == 0) return '${seconds}s';
    return '${minutes}m ${seconds}s';
  }
}
