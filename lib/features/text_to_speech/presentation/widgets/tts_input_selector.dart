import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/platform/native_file_dialog.dart';
import '../../../../core/providers/app_providers.dart';
import '../../application/tts_providers.dart';

/// Left panel for selecting text input sources (Manual text, TXT, DOCX, PDF, Document Library).
class TtsInputSelector extends ConsumerWidget {
  const TtsInputSelector({super.key});

  Future<void> _pickFile(BuildContext context, WidgetRef ref) async {
    final res = await NativeFileDialog.pickTtsDocumentFiles(multiSelect: false);
    if (res.isSelected && res.paths.isNotEmpty) {
      final selectedPath = res.paths.first;
      await ref.read(ttsStateProvider.notifier).importDocument(selectedPath);
    }
  }

  void _showLibraryPicker(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const _DocumentLibraryPickerDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          const Row(
            children: [
              Icon(Icons.source_rounded, color: AppColors.moduleTts, size: 22),
              SizedBox(width: 8),
              Text(
                'Nguồn tài liệu đầu vào',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Import File Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _pickFile(context, ref),
              icon: const Icon(Icons.file_open_rounded, size: 18),
              label: const Text('Mở tệp (.txt, .docx, .pdf)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.moduleTts.withOpacity(0.15),
                foregroundColor: AppColors.moduleTts,
                elevation: 0,
                side: const BorderSide(color: AppColors.moduleTts),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Document Library Import Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showLibraryPicker(context, ref),
              icon: const Icon(Icons.folder_shared_rounded, size: 18),
              label: const Text('Chọn từ Thư viện'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Divider(),
          const SizedBox(height: 8),

          const Text(
            'Định dạng hỗ trợ:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          _buildFormatRow('TXT', 'Văn bản thuần UTF-8/BOM', Icons.text_snippet_outlined),
          _buildFormatRow('DOCX', 'Word OpenXML (giữ thứ tự đoạn)', Icons.description_outlined),
          _buildFormatRow('PDF', 'PDF điện tử & bản quét OCR', Icons.picture_as_pdf_outlined),
          _buildFormatRow('OCR', 'Văn bản từ Scanner', Icons.document_scanner_outlined),

          const Spacer(),

          // Guide card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.moduleTts.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.moduleTts.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tips_and_updates_rounded, size: 16, color: AppColors.moduleTts),
                    SizedBox(width: 6),
                    Text(
                      'Mẹo ngắt nghỉ giọng đọc',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.moduleTts),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Bạn có thể chèn thẻ ngắt nghỉ chủ động trong văn bản bằng cú pháp:\n[pause 500ms] hoặc [pause 1s]',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white70 : Colors.black87,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatRow(String ext, String desc, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            ext,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              desc,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog for selecting existing library item to import into TTS editor.
class _DocumentLibraryPickerDialog extends ConsumerWidget {
  const _DocumentLibraryPickerDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryAsync = ref.watch(fileLibraryNotifierProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 600,
        height: 500,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.folder_shared_rounded, color: AppColors.moduleTts),
                const SizedBox(width: 10),
                const Text(
                  'Chọn tài liệu từ Thư viện số',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: libraryAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Lỗi: $err')),
                data: (files) {
                  if (files.isEmpty) {
                    return const Center(child: Text('Thư viện hiện chưa có tệp nào.'));
                  }
                  return ListView.separated(
                    itemCount: files.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final file = files[index];
                      final isSupported = file.originalName.endsWith('.txt') ||
                          file.originalName.endsWith('.docx') ||
                          file.originalName.endsWith('.pdf');

                      return ListTile(
                        dense: true,
                        enabled: isSupported,
                        leading: Icon(
                          isSupported ? Icons.insert_drive_file_outlined : Icons.block,
                          color: isSupported ? AppColors.moduleTts : Colors.grey,
                        ),
                        title: Text(file.originalName, style: const TextStyle(fontSize: 13)),
                        subtitle: Text(file.formattedSize, style: const TextStyle(fontSize: 11)),
                        trailing: isSupported
                            ? ElevatedButton(
                                child: const Text('Nạp văn bản'),
                                onPressed: () async {
                                  Navigator.of(context).pop();
                                  await ref
                                      .read(ttsStateProvider.notifier)
                                      .importDocument(file.localPath);
                                },
                              )
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

