import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../teaching_suite/domain/models/learning_objective.dart';
import '../../../teaching_suite/domain/models/question_models.dart';

/// Modal dialog for manually creating or editing a QuestionItem (Section 19).
/// Enforces strict GDPT 2018 MCQ 4-choice validation.
class QuestionEditDialog extends StatefulWidget {
  final QuestionItem? initialQuestion;
  final List<LearningObjective> objectives;
  final String projectId;
  final void Function(QuestionItem item) onSave;

  const QuestionEditDialog({
    super.key,
    this.initialQuestion,
    required this.objectives,
    required this.projectId,
    required this.onSave,
  });

  @override
  State<QuestionEditDialog> createState() => _QuestionEditDialogState();
}

class _QuestionEditDialogState extends State<QuestionEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late QuestionType _type;
  late QuestionDifficulty _difficulty;
  String? _objectiveId;

  late TextEditingController _promptController;
  late TextEditingController _choiceAController;
  late TextEditingController _choiceBController;
  late TextEditingController _choiceCController;
  late TextEditingController _choiceDController;
  late TextEditingController _explanationController;
  late TextEditingController _customAnswerController;

  String _mcqCorrectAnswer = 'A';
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuestion;
    _type = q?.type ?? QuestionType.multipleChoice;
    _difficulty = q?.difficulty ?? QuestionDifficulty.nhanBiet;
    _objectiveId = q?.learningObjective;

    _promptController = TextEditingController(text: q?.prompt ?? '');
    _explanationController = TextEditingController(text: q?.explanation ?? '');
    _customAnswerController = TextEditingController(
      text: _type != QuestionType.multipleChoice ? (q?.correctAnswer ?? '') : '',
    );

    final choices = q?.choices ?? [];
    _choiceAController = TextEditingController(text: choices.isNotEmpty ? choices[0] : '');
    _choiceBController = TextEditingController(text: choices.length > 1 ? choices[1] : '');
    _choiceCController = TextEditingController(text: choices.length > 2 ? choices[2] : '');
    _choiceDController = TextEditingController(text: choices.length > 3 ? choices[3] : '');

    if (_type == QuestionType.multipleChoice && q != null) {
      final ans = q.correctAnswer.trim().toUpperCase();
      if (['A', 'B', 'C', 'D'].contains(ans)) {
        _mcqCorrectAnswer = ans;
      }
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _choiceAController.dispose();
    _choiceBController.dispose();
    _choiceCController.dispose();
    _choiceDController.dispose();
    _explanationController.dispose();
    _customAnswerController.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _validationError = null);
    if (!_formKey.currentState!.validate()) return;

    List<String> finalChoices = [];
    String finalCorrectAnswer = '';

    if (_type == QuestionType.multipleChoice) {
      final cA = _choiceAController.text.trim();
      final cB = _choiceBController.text.trim();
      final cC = _choiceCController.text.trim();
      final cD = _choiceDController.text.trim();

      if (cA.isEmpty || cB.isEmpty || cC.isEmpty || cD.isEmpty) {
        setState(() => _validationError = 'Câu hỏi trắc nghiệm phải nhập đủ 4 lựa chọn A, B, C, D.');
        return;
      }

      final distinct = {cA.toLowerCase(), cB.toLowerCase(), cC.toLowerCase(), cD.toLowerCase()};
      if (distinct.length != 4) {
        setState(() => _validationError = 'Các lựa chọn A, B, C, D không được trùng lặp nội dung.');
        return;
      }

      finalChoices = [cA, cB, cC, cD];
      finalCorrectAnswer = _mcqCorrectAnswer;
    } else {
      final ans = _customAnswerController.text.trim();
      if (ans.isEmpty) {
        setState(() => _validationError = 'Vui lòng nhập đáp án hoặc hướng dẫn chấm.');
        return;
      }
      finalCorrectAnswer = ans;
    }

    final id = widget.initialQuestion?.id ??
        'q_${widget.projectId}_${DateTime.now().millisecondsSinceEpoch}';

    final item = QuestionItem(
      id: id,
      type: _type,
      prompt: _promptController.text.trim(),
      choices: finalChoices,
      correctAnswer: finalCorrectAnswer,
      explanation: _explanationController.text.trim().isNotEmpty
          ? _explanationController.text.trim()
          : null,
      difficulty: _difficulty,
      learningObjective: _objectiveId,
      orderIndex: widget.initialQuestion?.orderIndex ?? 0,
      tags: widget.initialQuestion?.tags ?? ['Manual'],
    );

    widget.onSave(item);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      widget.initialQuestion == null ? 'Thêm câu hỏi mới' : 'Chỉnh sửa câu hỏi',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 24),
                if (_validationError != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _validationError!,
                            style: const TextStyle(color: AppColors.error, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: Type, Difficulty, Objective
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<QuestionType>(
                                value: _type,
                                decoration: const InputDecoration(
                                  labelText: 'Loại câu hỏi',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: QuestionType.values.map((t) {
                                  return DropdownMenuItem(value: t, child: Text(t.label));
                                }).toList(),
                                onChanged: (v) {
                                  if (v != null) setState(() => _type = v);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<QuestionDifficulty>(
                                value: _difficulty,
                                decoration: const InputDecoration(
                                  labelText: 'Mức độ nhận thức',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: QuestionDifficulty.values.map((d) {
                                  return DropdownMenuItem(value: d, child: Text(d.label));
                                }).toList(),
                                onChanged: (v) {
                                  if (v != null) setState(() => _difficulty = v);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Objective Dropdown
                        DropdownButtonFormField<String>(
                          value: _objectiveId,
                          decoration: const InputDecoration(
                            labelText: 'Mục tiêu học tập (Yêu cầu cần đạt)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          hint: const Text('Chọn mục tiêu học tập (tùy chọn)'),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('-- Không gán mục tiêu cụ thể --'),
                            ),
                            ...widget.objectives.map((o) {
                              return DropdownMenuItem(
                                value: o.id,
                                child: Text('[${o.code}] ${o.description}'),
                              );
                            }),
                          ],
                          onChanged: (v) => setState(() => _objectiveId = v),
                        ),
                        const SizedBox(height: 16),

                        // Prompt
                        TextFormField(
                          controller: _promptController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Nội dung câu hỏi (Prompt) *',
                            hintText: 'Nhập nội dung câu hỏi hoặc ngữ liệu đọc hiểu...',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập câu hỏi' : null,
                        ),
                        const SizedBox(height: 16),

                        // Choices if MCQ
                        if (_type == QuestionType.multipleChoice) ...[
                          const Text(
                            'Các lựa chọn phương án (MCQ 4 đáp án chuẩn):',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          _buildChoiceRow('A', _choiceAController),
                          _buildChoiceRow('B', _choiceBController),
                          _buildChoiceRow('C', _choiceCController),
                          _buildChoiceRow('D', _choiceDController),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Text('Phương án đúng: ', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(value: 'A', label: Text('A')),
                                  ButtonSegment(value: 'B', label: Text('B')),
                                  ButtonSegment(value: 'C', label: Text('C')),
                                  ButtonSegment(value: 'D', label: Text('D')),
                                ],
                                selected: {_mcqCorrectAnswer},
                                onSelectionChanged: (set) {
                                  setState(() => _mcqCorrectAnswer = set.first);
                                },
                              ),
                            ],
                          ),
                        ] else ...[
                          TextFormField(
                            controller: _customAnswerController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Đáp án đúng / Hướng dẫn chấm *',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Explanation
                        TextFormField(
                          controller: _explanationController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Giải thích chi tiết (Dành cho giáo viên / Hướng dẫn giải)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Hủy'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Lưu câu hỏi'),
                      onPressed: _submit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceRow(String letter, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _mcqCorrectAnswer == letter
                  ? AppColors.primary
                  : Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              letter,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _mcqCorrectAnswer == letter ? Colors.white : Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Nhập nội dung phương án $letter',
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
