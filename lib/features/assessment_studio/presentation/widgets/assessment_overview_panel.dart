import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../application/assessment_project_notifier.dart';
import '../../application/assessment_question_bank_notifier.dart';
import '../../application/exam_builder_notifier.dart';
import '../../application/exam_code_notifier.dart';
import '../../application/exam_matrix_notifier.dart';
import '../../domain/models/assessment_project_data.dart';

/// Tab 1: Tổng quan dự án kiểm tra & đánh giá (Section 61).
class AssessmentOverviewPanel extends ConsumerWidget {
  const AssessmentOverviewPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projState = ref.watch(assessmentProjectNotifierProvider);
    final matrixState = ref.watch(examMatrixNotifierProvider);
    final bankState = ref.watch(assessmentQuestionBankNotifierProvider);
    final builderState = ref.watch(examBuilderNotifierProvider);
    final codeState = ref.watch(examCodeNotifierProvider);

    final project = projState.activeProject;
    if (project == null) {
      return const Center(child: Text('Vui lòng chọn hoặc tạo mới một dự án kiểm tra.'));
    }

    final isMatrixValid = matrixState.validationResult?.isValid ?? false;
    final isMasterFinalized = builderState.masterPaper?.isFinalized ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF065F46), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.quiz_rounded, size: 48, color: Colors.white),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Môn: ${project.subject} | Khối lớp: ${project.grade} | '
                        'Loại: ${project.examType.label} | Thời lượng: ${project.durationMinutes} phút | '
                        'Thang điểm: ${project.totalScore.toStringAsFixed(1)} đ',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Overview KPI Grid
          Row(
            children: [
              _buildKpiCard(
                context,
                title: 'Ma trận đề',
                value: isMatrixValid ? 'HỢP LỆ' : 'CẦN CHỈNH',
                subtitle: '${matrixState.matrix?.totalQuestionCount ?? 0} câu / ${matrixState.matrix?.totalScore.toStringAsFixed(1) ?? "0"} đ',
                icon: Icons.grid_on_rounded,
                color: isMatrixValid ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(width: 16),
              _buildKpiCard(
                context,
                title: 'Ngân hàng câu hỏi',
                value: '${bankState.allQuestions.length} CÂU',
                subtitle: '${matrixState.objectives.length} mục tiêu học tập',
                icon: Icons.inventory_2_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(width: 16),
              _buildKpiCard(
                context,
                title: 'Đề thi gốc (Master)',
                value: builderState.masterPaper != null
                    ? (isMasterFinalized ? 'ĐÃ DUYỆT' : 'BẢN NHÁP')
                    : 'CHƯA TẠO',
                subtitle: '${builderState.masterPaper?.questions.length ?? 0} câu hỏi',
                icon: Icons.description_rounded,
                color: isMasterFinalized ? AppColors.success : const Color(0xFFD97706),
              ),
              const SizedBox(width: 16),
              _buildKpiCard(
                context,
                title: 'Mã đề học sinh',
                value: '${codeState.codes.length} MÃ',
                subtitle: codeState.codes.map((c) => c.code).join(', '),
                icon: Icons.shuffle_rounded,
                color: const Color(0xFF2563EB),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Exam Header Configuration Box
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.school_rounded, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Thông tin Tiêu đề Đề thi (Theo chuẩn Nghị định 30/2020/NĐ-CP)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Chỉnh sửa'),
                        onPressed: () => _showEditHeaderDialog(context, ref, project),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow('Tên trường / Đơn vị:', project.headerConfig.schoolName),
                            const SizedBox(height: 8),
                            _buildInfoRow('Tiêu đề kỳ thi:', project.headerConfig.examTitle),
                            const SizedBox(height: 8),
                            _buildInfoRow('Học kỳ & Năm học:', '${project.headerConfig.semester}, Năm học ${project.headerConfig.schoolYear}'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow('Môn học & Khối:', '${project.headerConfig.subject} - Lớp ${project.headerConfig.grade}'),
                            const SizedBox(height: 8),
                            _buildInfoRow('Thời gian làm bài:', '${project.headerConfig.durationMinutes} phút'),
                            const SizedBox(height: 8),
                            _buildInfoRow('Liên kết KHBD:', project.lessonProjectId ?? 'Không liên kết'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ],
    );
  }

  void _showEditHeaderDialog(BuildContext context, WidgetRef ref, AssessmentProjectData project) {
    final schoolCtrl = TextEditingController(text: project.headerConfig.schoolName);
    final titleCtrl = TextEditingController(text: project.headerConfig.examTitle);
    final yearCtrl = TextEditingController(text: project.headerConfig.schoolYear);
    final semesterCtrl = TextEditingController(text: project.headerConfig.semester);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chỉnh sửa Tiêu đề Đề thi'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: schoolCtrl,
                decoration: const InputDecoration(labelText: 'Tên trường / Cơ sở giáo dục'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Tiêu đề kỳ thi (ví dụ: ĐỀ KIỂM TRA ĐỊNH KỲ)'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: semesterCtrl,
                      decoration: const InputDecoration(labelText: 'Học kỳ'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: yearCtrl,
                      decoration: const InputDecoration(labelText: 'Năm học'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Hủy')),
          FilledButton(
            onPressed: () {
              final updatedHeader = project.headerConfig.copyWith(
                schoolName: schoolCtrl.text.trim(),
                examTitle: titleCtrl.text.trim(),
                schoolYear: yearCtrl.text.trim(),
                semester: semesterCtrl.text.trim(),
              );
              ref.read(assessmentProjectNotifierProvider.notifier).updateProject(
                    project.copyWith(headerConfig: updatedHeader),
                  );
              Navigator.of(ctx).pop();
            },
            child: const Text('Lưu thay đổi'),
          ),
        ],
      ),
    );
  }
}
