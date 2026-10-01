import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../teaching_suite/domain/models/question_models.dart';
import '../../application/assessment_project_notifier.dart';
import '../../application/assessment_question_bank_notifier.dart';
import '../../application/exam_matrix_notifier.dart';
import 'question_edit_dialog.dart';

/// Tab 3: Ngân hàng câu hỏi kiểm tra & đánh giá (Sections 18, 19, 22, 63).
class AssessmentQuestionBankPanel extends ConsumerWidget {
  const AssessmentQuestionBankPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projState = ref.watch(assessmentProjectNotifierProvider);
    final bankState = ref.watch(assessmentQuestionBankNotifierProvider);

    final project = projState.activeProject;
    if (project == null) return const Center(child: Text('Chưa chọn dự án'));

    return Column(
      children: [
        // Filter Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Tìm kiếm câu hỏi, nội dung, từ khóa...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => ref
                          .read(assessmentQuestionBankNotifierProvider.notifier)
                          .setSearchQuery(v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Filter Type
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<QuestionType?>(
                      value: bankState.selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Loại câu',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('-- Tất cả loại --')),
                        ...QuestionType.values.map(
                          (t) => DropdownMenuItem(value: t, child: Text(t.label)),
                        ),
                      ],
                      onChanged: (v) => ref
                          .read(assessmentQuestionBankNotifierProvider.notifier)
                          .filterByType(v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Filter Difficulty
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<QuestionDifficulty?>(
                      value: bankState.selectedDifficulty,
                      decoration: const InputDecoration(
                        labelText: 'Độ khó',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('-- Tất cả mức độ --')),
                        ...QuestionDifficulty.values.map(
                          (d) => DropdownMenuItem(value: d, child: Text(d.label)),
                        ),
                      ],
                      onChanged: (v) => ref
                          .read(assessmentQuestionBankNotifierProvider.notifier)
                          .filterByDifficulty(v),
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Thêm câu hỏi'),
                    onPressed: () => _openQuestionEditor(context, ref, project.id, null),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('AI Tạo câu hỏi'),
                    onPressed: () => _openAiGenerateDialog(context, ref, project),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Questions List
        Expanded(
          child: bankState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : bankState.filteredQuestions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            bankState.allQuestions.isEmpty
                                ? 'Ngân hàng câu hỏi trống. Hãy thêm câu hỏi mới hoặc tạo bằng AI.'
                                : 'Không tìm thấy câu hỏi nào phù hợp với bộ lọc.',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: bankState.filteredQuestions.length,
                      itemBuilder: (context, index) {
                        final q = bankState.filteredQuestions[index];
                        return _buildQuestionCard(context, ref, project.id, q, index + 1);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(
    BuildContext context,
    WidgetRef ref,
    String projectId,
    QuestionItem q,
    int index,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Badges & Actions
            Row(
              children: [
                Text('Câu $index', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(width: 10),
                _buildBadge(q.difficulty.label, Colors.purple),
                const SizedBox(width: 6),
                _buildBadge(q.type.label, Colors.blue),
                if (q.learningObjective != null && q.learningObjective!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _buildBadge(q.learningObjective!, Colors.teal),
                ],
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  tooltip: 'Nhân bản',
                  onPressed: () {
                    final clone = q.copyWith(
                      id: 'q_${projectId}_${DateTime.now().millisecondsSinceEpoch}',
                      prompt: '${q.prompt} (Bản sao)',
                    );
                    ref
                        .read(assessmentQuestionBankNotifierProvider.notifier)
                        .saveQuestion(clone, projectId);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Chỉnh sửa',
                  onPressed: () => _openQuestionEditor(context, ref, projectId, q),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                  tooltip: 'Xóa',
                  onPressed: () => ref
                      .read(assessmentQuestionBankNotifierProvider.notifier)
                      .deleteQuestion(q.id, projectId),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Prompt
            Text(q.prompt, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),

            // Choices preview if MCQ
            if (q.type == QuestionType.multipleChoice && q.choices.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: q.choices.asMap().entries.map((e) {
                    final letter = String.fromCharCode(65 + e.key);
                    final isCorrect = q.correctAnswer.trim().toUpperCase() == letter ||
                        q.correctAnswer.trim().toLowerCase() == e.value.trim().toLowerCase();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                              e.value,
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
              )
            else if (q.correctAnswer.isNotEmpty)
              Text(
                'Đáp án: ${q.correctAnswer}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success),
              ),

            if (q.explanation != null && q.explanation!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Giải thích: ${q.explanation}',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade700, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _openQuestionEditor(BuildContext context, WidgetRef ref, String projectId, QuestionItem? item) {
    final matrixState = ref.read(examMatrixNotifierProvider);
    showDialog(
      context: context,
      builder: (ctx) => QuestionEditDialog(
        initialQuestion: item,
        objectives: matrixState.objectives,
        projectId: projectId,
        onSave: (saved) {
          ref.read(assessmentQuestionBankNotifierProvider.notifier).saveQuestion(saved, projectId);
        },
      ),
    );
  }

  void _openAiGenerateDialog(BuildContext context, WidgetRef ref, dynamic project) {
    final topicCtrl = TextEditingController();
    var diff = QuestionDifficulty.nhanBiet;
    var type = QuestionType.multipleChoice;
    int count = 5;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Tạo câu hỏi tự động bằng AI'),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: topicCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Chủ đề / Bài học / Ngữ liệu *',
                    hintText: 'Ví dụ: Truyện Kiều - Đoạn trích Cảnh ngày xuân',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<QuestionDifficulty>(
                        value: diff,
                        decoration: const InputDecoration(labelText: 'Độ khó', border: OutlineInputBorder()),
                        items: QuestionDifficulty.values
                            .map((d) => DropdownMenuItem(value: d, child: Text(d.label)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setDialogState(() => diff = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: count,
                        decoration: const InputDecoration(labelText: 'Số lượng', border: OutlineInputBorder()),
                        items: [1, 2, 3, 5, 10]
                            .map((c) => DropdownMenuItem(value: c, child: Text('$c câu')))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setDialogState(() => count = v);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Hủy')),
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Bắt đầu sinh câu hỏi'),
              onPressed: () async {
                final topic = topicCtrl.text.trim();
                if (topic.isEmpty) return;
                Navigator.of(ctx).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đang gửi yêu cầu sinh câu hỏi tới AI...')),
                );

                try {
                  await ref.read(assessmentQuestionBankNotifierProvider.notifier).generateQuestionsWithAi(
                        projectId: project.id,
                        subject: project.subject,
                        grade: project.grade,
                        topic: topic,
                        difficulty: diff,
                        type: type,
                        count: count,
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Đã tạo thành công $count câu hỏi mới vào ngân hàng!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
