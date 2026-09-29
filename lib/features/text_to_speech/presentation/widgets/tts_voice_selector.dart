import 'dart:io';
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

          // Voice Pack Status & Management (Req: Works on English Windows without language change)
          const SizedBox(height: 10),
          if (state.hasVietnameseVoice) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.teal.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, size: 18, color: Colors.tealAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Gói giọng đọc Tiếng Việt (${state.selectedVoice?.name ?? "Tự nhiên"}) đang kích hoạt — Hoạt động độc lập không cần cài đặt tiếng Việt cho Windows.',
                      style: const TextStyle(fontSize: 12, color: Colors.tealAccent),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showVoicePackDialog(context, ref),
                    icon: const Icon(Icons.language_rounded, size: 14),
                    label: const Text('Gói ngôn ngữ & Offline', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.tealAccent,
                      side: const BorderSide(color: Colors.tealAccent),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 18, color: Colors.amber),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Windows hiện dùng bản tiếng Anh và chưa có gói giọng đọc tiếng Việt Offline.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orangeAccent),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          notifier.setOfflineOnly(false);
                          notifier.loadVoices();
                        },
                        icon: const Icon(Icons.auto_awesome_rounded, size: 15),
                        label: const Text('Bật Gói giọng AI Tiếng Việt (Tự nhiên)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.moduleTts,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _openWindowsSpeechSettings(),
                        icon: const Icon(Icons.settings_suggest_rounded, size: 15),
                        label: const Text('Tải Gói Tiếng Việt cho Windows (1-Click)'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.amber,
                          side: const BorderSide(color: Colors.amber),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Làm mới danh sách giọng',
                        onPressed: () => notifier.loadVoices(),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                      ),
                    ],
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

  void _openWindowsSpeechSettings() {
    if (Platform.isWindows) {
      Process.run('cmd.exe', ['/c', 'start', 'ms-settings:speech']);
    }
  }

  void _showVoicePackDialog(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(ttsStateProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        title: const Row(
          children: [
            Icon(Icons.language_rounded, color: AppColors.moduleTts),
            SizedBox(width: 10),
            Text('Quản lý Gói giọng đọc & Ngôn ngữ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gói 1: AI Giọng Việt Tự nhiên
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.tealAccent, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Gói giọng AI Tiếng Việt (Hoài My & Nam Minh)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Tích hợp sẵn', style: TextStyle(fontSize: 10, color: Colors.tealAccent, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Hoạt động ngay lập tức trên mọi máy tính (kể cả máy cài Windows tiếng Anh hoặc bản Windows rút gọn). Diễn cảm tự nhiên, phát âm chuẩn giáo dục, hỗ trợ đọc số, công thức, ngày tháng.',
                      style: TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Gói 2: Windows Offline Speech Pack
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blueGrey.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.computer_rounded, color: Colors.lightBlueAccent, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Gói giọng đọc Offline cho Windows (Microsoft An)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Dành cho trường hợp máy không có internet. Hướng dẫn cài thêm vào Windows:',
                      style: TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '• Bước 1: Nhấn nút bên dưới để mở Cài đặt Windows.\n• Bước 2: Nhấn "Add voices" và tìm chọn "Vietnamese".\n• Bước 3: Sau khi Windows tải xong, nhấn "Làm mới danh sách giọng".',
                      style: TextStyle(fontSize: 11, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _openWindowsSpeechSettings(),
                          icon: const Icon(Icons.open_in_new_rounded, size: 14),
                          label: const Text('Mở Cài đặt Windows để tải (1-Click)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            textStyle: const TextStyle(fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            notifier.loadVoices();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Đã làm mới danh sách giọng đọc.')),
                            );
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 14),
                          label: const Text('Làm mới'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            textStyle: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}
