import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../application/tts_providers.dart';
import '../../domain/models/tts_options.dart';

/// Voice selection and speech parameter configuration panel.
class TtsVoiceSelector extends ConsumerWidget {
  const TtsVoiceSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ttsStateProvider);
    final notifier = ref.read(ttsStateProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          Row(
            children: [
              const Icon(Icons.tune_rounded, color: AppColors.moduleTts, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Cấu hình giọng đọc & Tham số',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              // Offline Only Filter Toggle
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Chỉ Offline:', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Switch(
                    value: state.isOfflineOnly,
                    onChanged: (val) => notifier.setOfflineOnly(val),
                    activeColor: AppColors.moduleTts,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Preset Selection Dropdown
          Row(
            children: [
              const Text('Cấu hình mẫu (Preset):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: state.selectedPreset?.id,
                  hint: const Text('Tùy chỉnh cá nhân'),
                  isDense: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    ...state.presets.map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(p.name, overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      final match = state.presets.firstWhere((p) => p.id == val);
                      notifier.applyPreset(match);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Voice Selection Dropdown & Preview Button
          const Text('Chọn giọng đọc (Voice):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: state.isLoadingVoices
                    ? const Center(child: LinearProgressIndicator())
                    : DropdownButtonFormField<String>(
                        value: state.selectedVoice?.id,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: state.availableVoices.map((v) {
                          return DropdownMenuItem(
                            value: v.id,
                            child: Row(
                              children: [
                                Icon(
                                  v.isLocal ? Icons.computer_rounded : Icons.cloud_outlined,
                                  size: 16,
                                  color: v.isLocal ? Colors.teal : Colors.blueAccent,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${v.name} (${v.language}) - ${v.providerId}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (v.isLocal ? Colors.teal : Colors.blueAccent).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    v.isLocal ? 'Offline' : 'Cloud',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: v.isLocal ? Colors.teal : Colors.blueAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final match = state.availableVoices.firstWhere((v) => v.id == val);
                            notifier.selectVoice(match);
                          }
                        },
                      ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: state.isPreviewing ? null : () => notifier.previewVoice(),
                icon: state.isPreviewing
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.volume_up_rounded, size: 18),
                label: const Text('Nghe thử'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.moduleTts,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),
            ],
          ),

          // Clear Warning if no Vietnamese Local Voice installed (Req 9)
          if (!state.hasVietnameseVoice) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.withOpacity(0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: Colors.amber),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Không tìm thấy giọng tiếng Việt cục bộ trên Windows. Bạn có thể cài đặt thêm gói giọng đọc Tiếng Việt trong Cài đặt Windows hoặc sử dụng giọng ngoại ngữ/Cloud.',
                      style: TextStyle(fontSize: 12, color: Colors.orangeAccent),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Speed Slider
          Row(
            children: [
              Text('Tốc độ đọc: ${state.options.speed.toStringAsFixed(2)}x', style: const TextStyle(fontSize: 13)),
              const Spacer(),
              // Preset chips: 0.5x, 0.75x, 1.0x, 1.25x, 1.5x, 2.0x
              ...[0.75, 1.0, 1.25, 1.5].map((spd) => Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: InkWell(
                      onTap: () => notifier.setSpeed(spd),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (state.options.speed - spd).abs() < 0.05
                              ? AppColors.moduleTts
                              : Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${spd}x',
                          style: TextStyle(
                            fontSize: 11,
                            color: (state.options.speed - spd).abs() < 0.05 ? Colors.white : null,
                          ),
                        ),
                      ),
                    ),
                  )),
            ],
          ),
          Slider(
            value: state.options.speed,
            min: 0.5,
            max: 2.0,
            divisions: 15,
            activeColor: AppColors.moduleTts,
            onChanged: (val) => notifier.setSpeed(val),
          ),

          // Pitch Slider
          Row(
            children: [
              Text('Cao độ: ${state.options.pitch.toStringAsFixed(2)}x', style: const TextStyle(fontSize: 13)),
            ],
          ),
          Slider(
            value: state.options.pitch,
            min: 0.5,
            max: 1.5,
            divisions: 10,
            activeColor: AppColors.moduleTts,
            onChanged: (val) => notifier.setPitch(val),
          ),

          // Pause Controls
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nghỉ câu: ${state.options.sentencePauseMs} ms', style: const TextStyle(fontSize: 12)),
                    Slider(
                      value: state.options.sentencePauseMs.toDouble(),
                      min: 100,
                      max: 1000,
                      divisions: 9,
                      activeColor: AppColors.moduleTts,
                      onChanged: (val) => notifier.setSentencePause(val.round()),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nghỉ đoạn: ${state.options.paragraphPauseMs} ms', style: const TextStyle(fontSize: 12)),
                    Slider(
                      value: state.options.paragraphPauseMs.toDouble(),
                      min: 200,
                      max: 2000,
                      divisions: 9,
                      activeColor: AppColors.moduleTts,
                      onChanged: (val) => notifier.setParagraphPause(val.round()),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Output Format Selector
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Định dạng xuất:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 16),
              Radio<TtsAudioFormat>(
                value: TtsAudioFormat.wav,
                groupValue: state.options.format,
                activeColor: AppColors.moduleTts,
                onChanged: (f) => f != null ? notifier.setAudioFormat(f) : null,
              ),
              const Text('WAV (PCM gốc)', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 16),
              Radio<TtsAudioFormat>(
                value: TtsAudioFormat.mp3,
                groupValue: state.options.format,
                activeColor: AppColors.moduleTts,
                onChanged: (f) => f != null ? notifier.setAudioFormat(f) : null,
              ),
              const Text('MP3 (Mã hóa nén)', style: TextStyle(fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}
