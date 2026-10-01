import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../teaching_suite/domain/models/learning_objective.dart';
import '../../../teaching_suite/domain/models/question_models.dart';
import '../../application/assessment_project_notifier.dart';
import '../../application/exam_matrix_notifier.dart';
import '../../application/exam_specification_notifier.dart';
import '../../domain/models/exam_matrix.dart';

/// Tab 2: Ma trận đề kiểm tra chuẩn GDPT 2018 (Sections 10, 14, 62).
class ExamMatrixPanel extends ConsumerWidget {
  const ExamMatrixPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projState = ref.watch(assessmentProjectNotifierProvider);
    final specState = ref.watch(examSpecificationNotifierProvider);
    final matrixState = ref.watch(examMatrixNotifierProvider);

    final project = projState.activeProject;
    final spec = specState.specification;
    final matrix = matrixState.matrix;
    final validation = matrixState.validationResult;

    if (project == null || spec == null || matrix == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Top Toolbar
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
                  const Text(
                    'MA TRẬN ĐỀ KIỂM TRA ĐỊNH KỲ (GDPT 2018)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    'Đặc tả yêu cầu: ${spec.questionCount} câu - Thang điểm: ${spec.totalScore.toStringAsFixed(1)} đ',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
              const Spacer(),
              if (project.lessonProjectId != null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Nhập YCCĐ từ KHBD'),
                  onPressed: () {
                    ref.read(examMatrixNotifierProvider.notifier).importObjectivesFromLessonProject(
                          lessonProjectId: project.lessonProjectId!,
                          assessmentProjectId: project.id,
                          spec: spec,
                        );
                  },
                ),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Thêm Yêu cầu cần đạt'),
                onPressed: () => _showAddObjectiveDialog(context, ref, project.id, spec),
              ),
            ],
          ),
        ),

        // Validation Banner if errors or warnings exist (Section 12, 17, 62)
        if (validation != null && (validation.hasErrors || validation.hasWarnings))
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            color: validation.hasErrors
                ? AppColors.error.withOpacity(0.12)
                : AppColors.warning.withOpacity(0.12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...validation.errors.map(
                  (err) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            err,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ...validation.warnings.map(
                  (warn) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            warn,
                            style: const TextStyle(color: Color(0xFFD97706), fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Matrix Grid Table
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.grey.withOpacity(0.1)),
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 64,
                  columns: const [
                    DataColumn(label: Text('TT', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Yêu cầu cần đạt / Mạch KT', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Nhận biết', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Thông hiểu', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Vận dụng', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Vận dụng cao', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Tổng cộng', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: [
                    ...matrixState.objectives.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final obj = entry.value;

                      final nbCell = matrix.getCell(obj.id, QuestionDifficulty.nhanBiet);
                      final thCell = matrix.getCell(obj.id, QuestionDifficulty.thongHieu);
                      final vdCell = matrix.getCell(obj.id, QuestionDifficulty.vanDung);
                      final vdcCell = matrix.getCell(obj.id, QuestionDifficulty.vanDungCao);

                      final totalObjCount = (nbCell?.questionCount ?? 0) +
                          (thCell?.questionCount ?? 0) +
                          (vdCell?.questionCount ?? 0) +
                          (vdcCell?.questionCount ?? 0);

                      final totalObjScore = (nbCell?.cellTotalScore ?? 0.0) +
                          (thCell?.cellTotalScore ?? 0.0) +
                          (vdCell?.cellTotalScore ?? 0.0) +
                          (vdcCell?.cellTotalScore ?? 0.0);

                      return DataRow(
                        cells: [
                          DataCell(Text('$idx')),
                          DataCell(
                            SizedBox(
                              width: 280,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('[${obj.code}] ${obj.description}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  if (obj.category != null)
                                    Text(obj.category!, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                          DataCell(_buildCellEditor(context, ref, nbCell, obj.id, QuestionDifficulty.nhanBiet, spec)),
                          DataCell(_buildCellEditor(context, ref, thCell, obj.id, QuestionDifficulty.thongHieu, spec)),
                          DataCell(_buildCellEditor(context, ref, vdCell, obj.id, QuestionDifficulty.vanDung, spec)),
                          DataCell(_buildCellEditor(context, ref, vdcCell, obj.id, QuestionDifficulty.vanDungCao, spec)),
                          DataCell(
                            Text(
                              '$totalObjCount câu\n${totalObjScore.toStringAsFixed(2)} đ',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      );
                    }),

                    // Summary Row
                    DataRow(
                      color: WidgetStateProperty.all(Colors.blue.withOpacity(0.06)),
                      cells: [
                        const DataCell(Text('Σ', style: TextStyle(fontWeight: FontWeight.bold))),
                        const DataCell(Text('TỔNG SỐ CÂU / ĐIỂM SỐ', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(_buildSummaryColumn(matrix, QuestionDifficulty.nhanBiet)),
                        DataCell(_buildSummaryColumn(matrix, QuestionDifficulty.thongHieu)),
                        DataCell(_buildSummaryColumn(matrix, QuestionDifficulty.vanDung)),
                        DataCell(_buildSummaryColumn(matrix, QuestionDifficulty.vanDungCao)),
                        DataCell(
                          Text(
                            '${matrix.totalQuestionCount} câu\n${matrix.totalScore.toStringAsFixed(2)} đ',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 14),
                          ),
                        ),
                      ],
                    ),

                    // Percentage Row
                    DataRow(
                      color: WidgetStateProperty.all(Colors.grey.withOpacity(0.04)),
                      cells: [
                        const DataCell(Text('%', style: TextStyle(fontWeight: FontWeight.bold))),
                        const DataCell(Text('TỈ LỆ ĐIỂM SỐ', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(_buildPercentageColumn(matrix, QuestionDifficulty.nhanBiet)),
                        DataCell(_buildPercentageColumn(matrix, QuestionDifficulty.thongHieu)),
                        DataCell(_buildPercentageColumn(matrix, QuestionDifficulty.vanDung)),
                        DataCell(_buildPercentageColumn(matrix, QuestionDifficulty.vanDungCao)),
                        const DataCell(Text('100%', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCellEditor(
    BuildContext context,
    WidgetRef ref,
    ExamMatrixCell? cell,
    String objectiveId,
    QuestionDifficulty difficulty,
    dynamic spec,
  ) {
    final count = cell?.questionCount ?? 0;
    final score = cell?.scorePerQuestion ?? 0.25;

    return InkWell(
      onTap: () => _showEditCellDialog(context, ref, cell, objectiveId, difficulty, spec),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(6),
          color: count > 0 ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$count câu',
              style: TextStyle(
                fontWeight: count > 0 ? FontWeight.bold : FontWeight.normal,
                color: count > 0 ? AppColors.primary : Colors.grey,
                fontSize: 12,
              ),
            ),
            Text(
              '${(count * score).toStringAsFixed(2)} đ',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryColumn(ExamMatrix matrix, QuestionDifficulty diff) {
    final count = matrix.getQuestionCountByDifficulty(diff);
    final score = matrix.getScoreByDifficulty(diff);
    return Text(
      '$count câu\n${score.toStringAsFixed(2)} đ',
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
    );
  }

  Widget _buildPercentageColumn(ExamMatrix matrix, QuestionDifficulty diff) {
    final total = matrix.totalScore > 0 ? matrix.totalScore : 10.0;
    final score = matrix.getScoreByDifficulty(diff);
    final pct = (score / total * 100).toStringAsFixed(1);
    return Text('$pct%', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12));
  }

  void _showEditCellDialog(
    BuildContext context,
    WidgetRef ref,
    ExamMatrixCell? cell,
    String objectiveId,
    QuestionDifficulty difficulty,
    dynamic spec,
  ) {
    final countCtrl = TextEditingController(text: '${cell?.questionCount ?? 0}');
    final scoreCtrl = TextEditingController(text: '${cell?.scorePerQuestion ?? 0.25}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Chỉnh sửa ô ma trận [${difficulty.label}]'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: countCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Số lượng câu hỏi', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: scoreCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Điểm số mỗi câu', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Hủy')),
          FilledButton(
            onPressed: () {
              final newCount = int.tryParse(countCtrl.text.trim()) ?? 0;
              final newScore = double.tryParse(scoreCtrl.text.trim()) ?? 0.25;

              final updatedCell = (cell ??
                      ExamMatrixCell(
                        id: 'cell_${spec.id}_${objectiveId}_${difficulty.name}',
                        specificationId: spec.id,
                        objectiveId: objectiveId,
                        difficulty: difficulty,
                      ))
                  .copyWith(questionCount: newCount, scorePerQuestion: newScore);

              ref.read(examMatrixNotifierProvider.notifier).updateCell(updatedCell, spec);
              Navigator.of(ctx).pop();
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showAddObjectiveDialog(BuildContext context, WidgetRef ref, String projectId, dynamic spec) {
    final codeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final catCtrl = TextEditingController(text: 'Năng lực đặc thù');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm Yêu cầu cần đạt mới'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Mã mục tiêu (ví dụ: NL_02, KT_01)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Mô tả yêu cầu cần đạt *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: catCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nhóm / Phân loại',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Hủy')),
          FilledButton(
            onPressed: () {
              final code = codeCtrl.text.trim().isNotEmpty
                  ? codeCtrl.text.trim()
                  : 'OBJ_${DateTime.now().millisecondsSinceEpoch}';
              final desc = descCtrl.text.trim();
              if (desc.isEmpty) return;

              final obj = LearningObjective(
                id: 'obj_${projectId}_$code',
                projectId: projectId,
                code: code,
                description: desc,
                category: catCtrl.text.trim(),
              );

              ref.read(examMatrixNotifierProvider.notifier).addObjective(obj, spec);
              Navigator.of(ctx).pop();
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }
}
