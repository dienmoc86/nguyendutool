import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../application/tts_providers.dart';
import '../../domain/models/pronunciation_rule.dart';

/// Modal dialog for managing local educational pronunciation dictionary rules.
class PronunciationDictionaryDialog extends ConsumerStatefulWidget {
  const PronunciationDictionaryDialog({super.key});

  @override
  ConsumerState<PronunciationDictionaryDialog> createState() => _PronunciationDictionaryDialogState();
}

class _PronunciationDictionaryDialogState extends ConsumerState<PronunciationDictionaryDialog> {
  List<PronunciationRule> _rules = [];
  bool _isLoading = true;

  final _sourceController = TextEditingController();
  final _replacementController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isCaseSensitive = false;
  bool _isRegex = false;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    setState(() => _isLoading = true);
    final service = ref.read(pronunciationDictionaryServiceProvider);
    final rules = await service.getAllRules(forceRefresh: true);
    setState(() {
      _rules = rules;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _replacementController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _addRule() async {
    final src = _sourceController.text.trim();
    final rep = _replacementController.text.trim();
    if (src.isEmpty || rep.isEmpty) return;

    final service = ref.read(pronunciationDictionaryServiceProvider);
    await service.addRule(
      sourcePhrase: src,
      replacementPhrase: rep,
      isCaseSensitive: _isCaseSensitive,
      isRegex: _isRegex,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    _sourceController.clear();
    _replacementController.clear();
    _notesController.clear();
    setState(() {
      _isCaseSensitive = false;
      _isRegex = false;
    });

    await _loadRules();
  }

  Future<void> _deleteRule(String id) async {
    final service = ref.read(pronunciationDictionaryServiceProvider);
    await service.deleteRule(id);
    await _loadRules();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.spellcheck_rounded, color: AppColors.moduleTts, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Từ điển phát âm & Phiên âm từ viết tắt',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Ánh xạ từ viết tắt sư phạm hoặc từ mượn sang cách đọc phiên âm chuẩn mà không làm thay đổi văn bản gốc.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const Divider(height: 24),

            // Add Rule Form
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _sourceController,
                      decoration: const InputDecoration(
                        labelText: 'Từ gốc (VD: STEM)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.arrow_forward, size: 16),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _replacementController,
                      decoration: const InputDecoration(
                        labelText: 'Đọc thành (VD: ét tem)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Ghi chú',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _addRule,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Thêm'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.moduleTts,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Rules List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _rules.isEmpty
                      ? const Center(child: Text('Chưa có quy tắc phiên âm nào.'))
                      : ListView.separated(
                          itemCount: _rules.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final rule = _rules[index];
                            return ListTile(
                              dense: true,
                              title: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.moduleTts.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      rule.sourcePhrase,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.moduleTts,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_right_alt, size: 18, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(
                                    rule.replacementPhrase,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  if (rule.notes != null) ...[
                                    const SizedBox(width: 12),
                                    Text(
                                      '(${rule.notes})',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.white54 : Colors.black45,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                onPressed: () => _deleteRule(rule.id),
                              ),
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
