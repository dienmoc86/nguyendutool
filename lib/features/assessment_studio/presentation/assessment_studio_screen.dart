import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../application/assessment_project_notifier.dart';
import '../application/assessment_question_bank_notifier.dart';
import '../application/exam_builder_notifier.dart';
import '../application/exam_code_notifier.dart';
import '../application/exam_matrix_notifier.dart';
import '../application/exam_specification_notifier.dart';
import '../domain/models/assessment_project_data.dart';
import 'widgets/assessment_artifacts_panel.dart';
import 'widgets/assessment_overview_panel.dart';
import 'widgets/assessment_question_bank_panel.dart';
import 'widgets/exam_answer_key_panel.dart';
import 'widgets/exam_builder_panel.dart';
import 'widgets/exam_codes_panel.dart';
import 'widgets/exam_matrix_panel.dart';

/// Assessment Studio main screen (Sections 1-3, 60-70).
/// Comprehensive workbench for Exam Matrix, Question Bank, Multi-Code Permutation & OpenXML DOCX Export.
class AssessmentStudioScreen extends ConsumerStatefulWidget {
  const AssessmentStudioScreen({super.key});

  @override
  ConsumerState<AssessmentStudioScreen> createState() => _AssessmentStudioScreenState();
}

class _AssessmentStudioScreenState extends ConsumerState<AssessmentStudioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initDefaultProjectIfNone();
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initDefaultProjectIfNone() async {
    final projState = ref.read(assessmentProjectNotifierProvider);
    if (projState.activeProject == null) {
      // Create initial sample assessment project
      final proj = await ref.read(assessmentProjectNotifierProvider.notifier).createProject(
            name: 'Đề kiểm tra Định kỳ Ngữ văn 9',
            subject: 'Ngữ văn',
            grade: '9',
            examType: ExamType.periodic45,
            durationMinutes: 45,
            totalScore: 10.0,
          );
      await _hydrateProjectSubnotifiers(proj);
    }
  }

  Future<void> _hydrateProjectSubnotifiers(AssessmentProjectData project) async {
    // 1. Spec
    final spec = await ref.read(examSpecificationNotifierProvider.notifier).loadForProject(
          projectId: project.id,
          subject: project.subject,
          grade: project.grade,
          durationMinutes: project.durationMinutes,
          totalScore: project.totalScore,
        );

    // 2. Matrix
    await ref.read(examMatrixNotifierProvider.notifier).loadForSpecification(
          specificationId: spec.id,
          projectId: project.id,
          specification: spec,
        );

    // 3. Question Bank
    await ref.read(assessmentQuestionBankNotifierProvider.notifier).loadQuestions(
          project.id,
          linkedLessonProjectId: project.lessonProjectId,
        );

    // 4. Master Paper
    final paper = await ref.read(examBuilderNotifierProvider.notifier).loadMasterPaper(project.id);

    // 5. Codes
    if (paper != null) {
      await ref.read(examCodeNotifierProvider.notifier).loadCodes(paper.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final projState = ref.watch(assessmentProjectNotifierProvider);
    final project = projState.activeProject;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        titleSpacing: 24,
        elevation: 1,
        title: Row(
          children: [
            const Icon(Icons.quiz_rounded, color: Color(0xFF059669), size: 26),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      project?.name ?? 'Xưởng Đề kiểm tra & Đánh giá',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'GDPT 2018',
                        style: TextStyle(
                          color: Color(0xFF059669),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${project?.subject ?? "Ngữ văn"} • Lớp ${project?.grade ?? "9"} • ${project?.durationMinutes ?? 45} phút',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Tạo dự án mới'),
            onPressed: () => _showCreateProjectDialog(context),
          ),
          const SizedBox(width: 16),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFF059669),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF059669),
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: '1. Tổng quan'),
            Tab(icon: Icon(Icons.grid_on_outlined, size: 18), text: '2. Ma trận đề'),
            Tab(icon: Icon(Icons.inventory_2_outlined, size: 18), text: '3. Ngân hàng câu hỏi'),
            Tab(icon: Icon(Icons.edit_document, size: 18), text: '4. Tạo đề'),
            Tab(icon: Icon(Icons.shuffle_rounded, size: 18), text: '5. Mã đề'),
            Tab(icon: Icon(Icons.fact_check_outlined, size: 18), text: '6. Đáp án'),
            Tab(icon: Icon(Icons.folder_zip_outlined, size: 18), text: '7. Sản phẩm'),
          ],
        ),
      ),
      body: projState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: const [
                AssessmentOverviewPanel(),
                ExamMatrixPanel(),
                AssessmentQuestionBankPanel(),
                ExamBuilderPanel(),
                ExamCodesPanel(),
                ExamAnswerKeyPanel(),
                AssessmentArtifactsPanel(),
              ],
            ),
    );
  }

  void _showCreateProjectDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: 'Đề kiểm tra Giữa kỳ I');
    String subject = 'Ngữ văn';
    String grade = '9';
    var type = ExamType.periodic45;
    int duration = 45;
    double score = 10.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tạo Dự án Đề kiểm tra mới'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Tên đề kiểm tra *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: subject,
                        decoration: const InputDecoration(labelText: 'Môn học', border: OutlineInputBorder()),
                        items: ['Ngữ văn', 'Toán', 'Tiếng Anh', 'Lịch sử & Địa lí', 'Khoa học tự nhiên']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setDialogState(() => subject = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: grade,
                        decoration: const InputDecoration(labelText: 'Khối lớp', border: OutlineInputBorder()),
                        items: ['6', '7', '8', '9', '10', '11', '12']
                            .map((g) => DropdownMenuItem(value: g, child: Text('Lớp $g')))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setDialogState(() => grade = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<ExamType>(
                        value: type,
                        decoration: const InputDecoration(labelText: 'Loại bài kiểm tra', border: OutlineInputBorder()),
                        items: ExamType.values
                            .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setDialogState(() => type = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: duration,
                        decoration: const InputDecoration(labelText: 'Thời lượng', border: OutlineInputBorder()),
                        items: [15, 45, 60, 90, 120]
                            .map((m) => DropdownMenuItem(value: m, child: Text('$m phút')))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setDialogState(() => duration = v);
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
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.of(ctx).pop();

                final created = await ref.read(assessmentProjectNotifierProvider.notifier).createProject(
                      name: name,
                      subject: subject,
                      grade: grade,
                      examType: type,
                      durationMinutes: duration,
                      totalScore: score,
                    );
                await _hydrateProjectSubnotifiers(created);
              },
              child: const Text('Tạo dự án'),
            ),
          ],
        ),
      ),
    );
  }
}
