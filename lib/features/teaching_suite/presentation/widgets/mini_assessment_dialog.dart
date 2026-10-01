import 'package:flutter/material.dart';
import '../../domain/models/mini_assessment_model.dart';
import '../../domain/models/question_models.dart';

class MiniAssessmentDialog extends StatefulWidget {
  final String initialTitle;
  final int availableQuestionsCount;

  const MiniAssessmentDialog({
    super.key,
    required this.initialTitle,
    required this.availableQuestionsCount,
  });

  static Future<MiniAssessmentConfig?> show(
    BuildContext context, {
    required String initialTitle,
    required int availableQuestionsCount,
  }) {
    return showDialog<MiniAssessmentConfig>(
      context: context,
      builder: (ctx) => MiniAssessmentDialog(
        initialTitle: initialTitle,
        availableQuestionsCount: availableQuestionsCount,
      ),
    );
  }

  @override
  State<MiniAssessmentDialog> createState() => _MiniAssessmentDialogState();
}

class _MiniAssessmentDialogState extends State<MiniAssessmentDialog> {
  late TextEditingController _titleController;
  int _durationMinutes = 15;
  int _questionCount = 5;
  bool _shuffle = false;
  final Set<QuestionType> _selectedTypes = {
    QuestionType.multipleChoice,
    QuestionType.trueFalse,
    QuestionType.shortAnswer,
  };
  final Set<QuestionDifficulty> _selectedDifficulties = {
    QuestionDifficulty.nhanBiet,
    QuestionDifficulty.thongHieu,
    QuestionDifficulty.vanDung,
  };

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: 'Bài kiểm tra nhanh: ${widget.initialTitle}');
    if (widget.availableQuestionsCount > 0) {
      _questionCount = widget.availableQuestionsCount.clamp(1, 10);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.assignment_turned_in_outlined, color: Colors.blue),
          SizedBox(width: 10),
          Text('Tạo bài kiểm tra ngắn (Mini Assessment)'),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Tiêu đề đề kiểm tra', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _durationMinutes,
                      decoration: const InputDecoration(labelText: 'Thời gian', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 10, child: Text('10 phút')),
                        DropdownMenuItem(value: 15, child: Text('15 phút')),
                        DropdownMenuItem(value: 20, child: Text('20 phút')),
                        DropdownMenuItem(value: 45, child: Text('45 phút')),
                      ],
                      onChanged: (v) => setState(() => _durationMinutes = v ?? 15),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _questionCount,
                      decoration: const InputDecoration(labelText: 'Số lượng câu hỏi', border: OutlineInputBorder()),
                      items: [3, 5, 10, 15, 20].where((c) => c <= widget.availableQuestionsCount || c == 3 || c == 5).map((c) {
                        return DropdownMenuItem(value: c, child: Text('$c câu'));
                      }).toList(),
                      onChanged: (v) => setState(() => _questionCount = v ?? 5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Định dạng câu hỏi lựa chọn:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Wrap(
                spacing: 8,
                children: QuestionType.values.map((t) {
                  final isSelected = _selectedTypes.contains(t);
                  return FilterChip(
                    label: Text(t.label),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedTypes.add(t);
                        } else if (_selectedTypes.length > 1) {
                          _selectedTypes.remove(t);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              const Text('Mức độ nhận thức:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Wrap(
                spacing: 8,
                children: QuestionDifficulty.values.map((d) {
                  final isSelected = _selectedDifficulties.contains(d);
                  return FilterChip(
                    label: Text(d.label),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedDifficulties.add(d);
                        } else if (_selectedDifficulties.length > 1) {
                          _selectedDifficulties.remove(d);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Xáo trộn thứ tự ngẫu nhiên', style: TextStyle(fontSize: 14)),
                value: _shuffle,
                onChanged: (v) => setState(() => _shuffle = v ?? false),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton.icon(
          onPressed: () {
            final config = MiniAssessmentConfig(
              title: _titleController.text,
              durationMinutes: _durationMinutes,
              totalQuestions: _questionCount,
              allowedTypes: _selectedTypes,
              allowedDifficulties: _selectedDifficulties,
              shuffleQuestions: _shuffle,
            );
            Navigator.pop(context, config);
          },
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Tạo đề & Đáp án'),
        ),
      ],
    );
  }
}
