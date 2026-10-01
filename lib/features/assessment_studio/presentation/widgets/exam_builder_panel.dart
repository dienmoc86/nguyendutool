import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../teaching_suite/domain/models/question_models.dart';
import '../../application/assessment_question_bank_notifier.dart';
import '../../application/exam_builder_notifier.dart';
import '../../application/exam_matrix_notifier.dart';
import '../../application/exam_specification_notifier.dart';
import '../../domain/models/exam_question_snapshot.dart';

/// Tab 4: Tạo đề thi gốc theo ma trận & Chốt duyệt (Sections 26-31, 64-65).
class ExamBuilderPanel extends ConsumerWidget {
  const ExamBuilderPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final specState = ref.watch(examSpecificationNotifierProvider);
    final matrixState = ref.watch(examMatrixNotifierProvider);
    final bankState = ref.watch(assessmentQuestionBankNotifierProvider);
    final builderState = ref.watch(examBuilderNotifierProvider);

    final spec = specState.specification;
    final matrix = matrixState.matrix;
    final paper = builderState.masterPaper;
    final shortages = builderState.selectionResult?.shortages ?? [];

    if (spec == null || matrix == null) {
      return const Center(child: Text('Vui lòng thiết lập Đặc tả và Ma trận đề trước khi tạo đề.'));
    }

    return Column(
      children: [
        // Control Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    paper != null
                        ? 'ĐỀ THI GỐC (MASTER) - ${paper.isFinalized ? "ĐÃ CHỐT DUYỆT" : "BẢN NHÁP"}'
                        : 'CHƯA TẠO ĐỀ THI GỐC',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    'Số lượng: ${paper?.questions.length ?? 0}/${spec.questionCount} câu - Tổng điểm: ${paper?.calculatedScore.toStringAsFixed(2) ?? "0"} đ',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
              const Spacer(),
              if (paper != null && !paper.isFinalized)
                OutlinedButton.icon(
                  icon: const Icon(Icons.check_circle_outline_rounded, color: AppColors.success),
                  label: const Text('Chốt duyệt đề thi (Finalize)'),
                  onPressed: () => _finalizePaper(context, ref),
                ),
              const SizedBox(width: 12),
              FilledButton.icon(
                icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                label: Text(paper == null ? 'Tạo đề theo ma trận' : 'Tạo lại đề theo ma trận'),
                onPressed: builderState.isGenerating
                    ? null
                    : () => _generateMaster(context, ref, matrix, bankState.allQuestions, spec),
              ),
            ],
          ),
        ),

        // Shortage Deficit Banner if selection failed (Section 27)
        if (shortages.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            color: AppColors.error.withOpacity(0.12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.error),
                    SizedBox(width: 8),
                    Text(
                      'NGÂN HÀNG CÂU HỎI KHÔNG ĐỦ SỐ LƯỢNG ĐỂ THỎA MÃN MA TRẬN ĐỀ:',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ...shortages.map(
                  (sh) => Text(
                    ' • $sh',
                    style: const TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

        // Questions List / Empty State
        Expanded(
          child: builderState.isGenerating
              ? const Center(child: CircularProgressIndicator())
              : paper == null || paper.questions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.description_outlined, size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text(
                            'Chưa có câu hỏi nào trong đề thi gốc.',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Nhấn "Tạo đề theo ma trận" để hệ thống tự động bốc câu hỏi từ ngân hàng.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: paper.questions.length,
                      itemBuilder: (context, index) {
                        final q = paper.questions[index];
                        return _buildMasterQuestionCard(context, ref, q, index, paper.isFinalized, bankState.allQuestions);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildMasterQuestionCard(
    BuildContext context,
    WidgetRef ref,
    ExamQuestionSnapshot q,
    int index,
    bool isFinalized,
    List<QuestionItem> bank,
  ) {
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
                  'Câu ${index + 1} (${q.score.toStringAsFixed(2)} đ)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(width: 10),
                _buildBadge(q.difficulty.label, Colors.purple),
                const SizedBox(width: 6),
                _buildBadge(q.type.label, Colors.blue),
                if (q.objectiveId != null) ...[
                  const SizedBox(width: 6),
                  _buildBadge(q.objectiveId!, Colors.teal),
                ],
                const Spacer(),
                if (!isFinalized)
                  TextButton.icon(
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: const Text('Thay thế câu hỏi'),
                    onPressed: () => _showReplaceDialog(context, ref, index, q, bank),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(q.prompt, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),

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
                    final isCorrect = e.value.id == q.correctChoiceId;
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

  void _generateMaster(
    BuildContext context,
    WidgetRef ref,
    dynamic matrix,
    List<QuestionItem> bank,
    dynamic spec,
  ) async {
    final result = await ref.read(examBuilderNotifierProvider.notifier).generateMasterPaper(
          matrix: matrix,
          bank: bank,
          spec: spec,
        );

    if (context.mounted && !result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Không thể tạo đề theo ma trận'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _finalizePaper(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận chốt duyệt đề thi'),
        content: const Text(
          'Sau khi chốt duyệt, đề thi gốc sẽ được khóa và đóng băng nội dung (Snapshot). '
          'Bạn sẽ có thể sinh các mã đề kiểm tra cho học sinh và xuất ra file Word.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Hủy')),
          FilledButton(
            onPressed: () {
              ref.read(examBuilderNotifierProvider.notifier).finalizePaper();
              Navigator.of(ctx).pop();
            },
            child: const Text('Chốt duyệt ngay'),
          ),
        ],
      ),
    );
  }

  void _showReplaceDialog(
    BuildContext context,
    WidgetRef ref,
    int qIndex,
    ExamQuestionSnapshot currentSnap,
    List<QuestionItem> bank,
  ) {
    // Find compatible candidates in bank (Section 65)
    final candidates = bank.where((q) {
      if (q.id == currentSnap.questionId) return false;
      if (q.difficulty != currentSnap.difficulty) return false;
      if (q.type != currentSnap.type) return false;
      return true;
    }).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Thay thế câu hỏi số ${qIndex + 1}'),
        content: SizedBox(
          width: 580,
          height: 420,
          child: candidates.isEmpty
              ? const Center(
                  child: Text('Không có câu hỏi nào khác trong ngân hàng có cùng loại và mức độ nhận thức.'),
                )
              : ListView.builder(
                  itemCount: candidates.length,
                  itemBuilder: (context, idx) {
                    final item = candidates[idx];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(item.prompt, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${item.difficulty.label} • ${item.type.label}'),
                        trailing: FilledButton(
                          child: const Text('Chọn câu này'),
                          onPressed: () {
                            ref.read(examBuilderNotifierProvider.notifier).replaceQuestion(
                                  questionIndex: qIndex,
                                  newQuestion: item,
                                );
                            Navigator.of(ctx).pop();
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Đóng')),
        ],
      ),
    );
  }
}
