import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../teaching_suite/domain/models/question_models.dart';
import '../../application/exam_builder_notifier.dart';
import '../../application/exam_code_notifier.dart';
import '../../domain/models/exam_code.dart';
import '../../domain/models/question_choice.dart';

/// Tab 5: Sinh & Quản lý các Mã đề thi học sinh (Sections 32-35, 66-67).
class ExamCodesPanel extends ConsumerStatefulWidget {
  const ExamCodesPanel({super.key});

  @override
  ConsumerState<ExamCodesPanel> createState() => _ExamCodesPanelState();
}

class _ExamCodesPanelState extends ConsumerState<ExamCodesPanel> {
  int _numberOfCodes = 4;
  int _startingCode = 101;
  bool _shuffleQuestions = true;
  bool _shuffleChoices = true;
  int? _randomSeed;
  int _selectedCodeIndex = 0;

  @override
  Widget build(BuildContext context) {
    final builderState = ref.watch(examBuilderNotifierProvider);
    final codeState = ref.watch(examCodeNotifierProvider);
    final masterPaper = builderState.masterPaper;

    if (masterPaper == null) {
      return const Center(
        child: Text('Vui lòng tạo đề thi gốc (Master) tại tab "Tạo đề" trước khi sinh mã đề.'),
      );
    }

    return Column(
      children: [
        // Controls Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
          ),
          child: Row(
            children: [
              // Code Count
              DropdownButton<int>(
                value: _numberOfCodes,
                items: [2, 4, 6, 8]
                    .map((c) => DropdownMenuItem(value: c, child: Text('$c mã đề')))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _numberOfCodes = v);
                },
              ),
              const SizedBox(width: 12),
              // Starting Code
              SizedBox(
                width: 110,
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Mã bắt đầu',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  controller: TextEditingController(text: '$_startingCode'),
                  onChanged: (v) {
                    final parsed = int.tryParse(v);
                    if (parsed != null) _startingCode = parsed;
                  },
                ),
              ),
              const SizedBox(width: 16),
              // Shuffling options
              FilterChip(
                label: const Text('Trộn câu hỏi'),
                selected: _shuffleQuestions,
                onSelected: (v) => setState(() => _shuffleQuestions = v),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Trộn đáp án A/B/C/D'),
                selected: _shuffleChoices,
                onSelected: (v) => setState(() => _shuffleChoices = v),
              ),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.shuffle_rounded, size: 18),
                label: Text(codeState.codes.isEmpty ? 'Sinh mã đề' : 'Sinh lại các mã đề'),
                onPressed: codeState.isGenerating
                    ? null
                    : () => _generateCodes(context, masterPaper),
              ),
            ],
          ),
        ),

        // Body: Code Tabs and Question Preview
        Expanded(
          child: codeState.isGenerating
              ? const Center(child: CircularProgressIndicator())
              : codeState.codes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shuffle_outlined, size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text(
                            'Chưa sinh các mã đề kiểm tra.',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Chọn số lượng mã đề (mặc định 4 mã: 101, 102, 103, 104) và nhấn "Sinh mã đề".',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : Row(
                      children: [
                        // Left sidebar: List of Codes
                        Container(
                          width: 180,
                          decoration: BoxDecoration(
                            border: Border(right: BorderSide(color: Colors.grey.withOpacity(0.2))),
                          ),
                          child: ListView.builder(
                            itemCount: codeState.codes.length,
                            itemBuilder: (context, idx) {
                              final code = codeState.codes[idx];
                              final isSelected = idx == _selectedCodeIndex;
                              return ListTile(
                                selected: isSelected,
                                selectedTileColor: AppColors.primary.withOpacity(0.1),
                                leading: Icon(
                                  Icons.tag_rounded,
                                  color: isSelected ? AppColors.primary : Colors.grey,
                                ),
                                title: Text(
                                  'MÃ ĐỀ ${code.code}',
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? AppColors.primary : null,
                                  ),
                                ),
                                subtitle: Text('${code.questions.length} câu • ${code.totalScore.toStringAsFixed(1)} đ'),
                                onTap: () => setState(() => _selectedCodeIndex = idx),
                              );
                            },
                          ),
                        ),

                        // Right: Preview of Selected Code
                        Expanded(
                          child: _selectedCodeIndex < codeState.codes.length
                              ? _buildCodePreview(codeState.codes[_selectedCodeIndex])
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildCodePreview(ExamCode code) {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: code.questions.length,
      itemBuilder: (context, idx) {
        final q = code.questions[idx];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Câu ${idx + 1} (${q.score.toStringAsFixed(2)} đ)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Đáp án: ${q.correctDisplayAnswer}',
                        style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(q.snapshot.prompt, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 10),

                if (q.snapshot.type == QuestionType.multipleChoice)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: q.orderedChoices.asMap().entries.map((e) {
                        final letter = QuestionChoice.indexToLetter(e.key);
                        final isCorrect = letter == q.correctDisplayAnswer;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            children: [
                              Text(
                                '$letter. ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isCorrect ? AppColors.success : Colors.black87,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  e.value.text,
                                  style: TextStyle(
                                    fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                                    color: isCorrect ? AppColors.success : Colors.black87,
                                  ),
                                ),
                              ),
                              if (isCorrect)
                                const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _generateCodes(BuildContext context, dynamic masterPaper) async {
    try {
      await ref.read(examCodeNotifierProvider.notifier).generateCodes(
            masterPaper: masterPaper,
            numberOfCodes: _numberOfCodes,
            startingCode: _startingCode,
            shuffleQuestions: _shuffleQuestions,
            shuffleChoices: _shuffleChoices,
            seed: _randomSeed,
          );
      setState(() => _selectedCodeIndex = 0);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã sinh và xác minh thành công $_numberOfCodes mã đề thi!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi sinh mã đề: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}
