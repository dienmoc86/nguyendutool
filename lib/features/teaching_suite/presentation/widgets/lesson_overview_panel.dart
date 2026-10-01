import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../lesson_planner/domain/lesson_plan_models.dart';
import '../../application/teaching_suite_ai_notifier.dart';
import '../../application/teaching_suite_project_notifier.dart';
import '../../application/teaching_suite_providers.dart';
import '../../domain/models/lesson_project_data.dart';
import '../../infrastructure/prompt_templates.dart';

class LessonOverviewPanel extends ConsumerStatefulWidget {
  final VoidCallback onNavigateToPlan;
  final VoidCallback onNavigateToWorksheet;
  final VoidCallback onNavigateToQuestions;
  final VoidCallback onNavigateToRubric;
  final VoidCallback onNavigateToArtifacts;

  const LessonOverviewPanel({
    super.key,
    required this.onNavigateToPlan,
    required this.onNavigateToWorksheet,
    required this.onNavigateToQuestions,
    required this.onNavigateToRubric,
    required this.onNavigateToArtifacts,
  });

  @override
  ConsumerState<LessonOverviewPanel> createState() => _LessonOverviewPanelState();
}

class _LessonOverviewPanelState extends ConsumerState<LessonOverviewPanel> {
  late TextEditingController _titleController;
  late TextEditingController _objectivesController;
  late TextEditingController _requirementsController;
  late TextEditingController _referenceController;

  @override
  void initState() {
    super.initState();
    final data = ref.read(teachingSuiteProjectNotifierProvider).projectData;
    _titleController = TextEditingController(text: data.lessonTitle);
    _objectivesController = TextEditingController(text: data.learningObjectives);
    _requirementsController = TextEditingController(text: data.requirements);
    _referenceController = TextEditingController(text: data.referenceMaterial);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _objectivesController.dispose();
    _requirementsController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  void _syncData() {
    final notifier = ref.read(teachingSuiteProjectNotifierProvider.notifier);
    final current = ref.read(teachingSuiteProjectNotifierProvider).projectData;
    notifier.updateProjectData(current.copyWith(
      lessonTitle: _titleController.text,
      learningObjectives: _objectivesController.text,
      requirements: _requirementsController.text,
      referenceMaterial: _referenceController.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final projectState = ref.watch(teachingSuiteProjectNotifierProvider);
    final aiState = ref.watch(teachingSuiteAiNotifierProvider);
    final theme = Theme.of(context);
    final data = projectState.projectData;

    // Keep text controllers in sync when switching projects
    ref.listen<TeachingSuiteProjectState>(teachingSuiteProjectNotifierProvider, (previous, next) {
      if (previous?.activeProject?.id != next.activeProject?.id) {
        _titleController.text = next.projectData.lessonTitle;
        _objectivesController.text = next.projectData.learningObjectives;
        _requirementsController.text = next.projectData.requirements;
        _referenceController.text = next.projectData.referenceMaterial;
      }
    });

    final refLength = _referenceController.text.length;
    const maxChars = PromptTemplates.maxReferenceMaterialChars;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card with Project Status & Quick Actions
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.school, color: theme.colorScheme.onPrimaryContainer, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.lessonTitle.isNotEmpty ? data.lessonTitle : 'Bài học chưa đặt tên',
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Dự án bài dạy: ${projectState.activeProject?.name ?? "..."} | Môn: ${data.subject} | ${data.grade} | ${data.duration}',
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                            ),
                          ],
                        ),
                      ),
                      // AI Status Badge
                      _buildAiStatusBadge(aiState),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  // Quick Action Buttons
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: widget.onNavigateToPlan,
                        icon: const Icon(Icons.description, size: 18),
                        label: const Text('Soạn Giáo án 5512'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: widget.onNavigateToWorksheet,
                        icon: const Icon(Icons.assignment, size: 18),
                        label: const Text('Tạo Phiếu học tập'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: widget.onNavigateToQuestions,
                        icon: const Icon(Icons.quiz, size: 18),
                        label: const Text('Ngân hàng Câu hỏi'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: widget.onNavigateToRubric,
                        icon: const Icon(Icons.checklist, size: 18),
                        label: const Text('Bảng Rubric đánh giá'),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.onNavigateToArtifacts,
                        icon: const Icon(Icons.file_download, size: 18),
                        label: const Text('Xuất trọn bộ sản phẩm'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Main 2-Column Form
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              return isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildGeneralInfoCard(data, theme)),
                        const SizedBox(width: 20),
                        Expanded(child: _buildReferenceAndObjectivesCard(data, theme, refLength, maxChars)),
                      ],
                    )
                  : Column(
                      children: [
                        _buildGeneralInfoCard(data, theme),
                        const SizedBox(height: 20),
                        _buildReferenceAndObjectivesCard(data, theme, refLength, maxChars),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAiStatusBadge(TeachingSuiteAiState aiState) {
    final status = aiState.connectionStatus;
    final isOk = status?.isSuccessful ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isOk ? Colors.green.withOpacity(0.12) : Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isOk ? Colors.green : Colors.orange),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isOk ? Icons.cloud_done : Icons.cloud_off, size: 16, color: isOk ? Colors.green : Colors.orange),
          const SizedBox(width: 6),
          Text(
            isOk ? 'AI Sẵn sàng (${status?.model ?? "Gemini"})' : 'AI chưa cấu hình',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isOk ? Colors.green.shade800 : Colors.orange.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralInfoCard(LessonProjectData data, ThemeData theme) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Thông tin tổng thể bài học', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Tên bài dạy / Chủ đề bài học *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              onChanged: (_) => _syncData(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: SchoolSubjects.subjects.contains(data.subject) ? data.subject : SchoolSubjects.subjects.first,
                    decoration: const InputDecoration(labelText: 'Môn học', border: OutlineInputBorder()),
                    items: SchoolSubjects.subjects.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(teachingSuiteProjectNotifierProvider.notifier).updateProjectData(data.copyWith(subject: val));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: SchoolSubjects.grades.contains(data.grade) ? data.grade : SchoolSubjects.grades.first,
                    decoration: const InputDecoration(labelText: 'Khối lớp', border: OutlineInputBorder()),
                    items: SchoolSubjects.grades.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(teachingSuiteProjectNotifierProvider.notifier).updateProjectData(data.copyWith(grade: val));
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: SchoolSubjects.bookSeriesList.contains(data.bookSeries) ? data.bookSeries : SchoolSubjects.bookSeriesList.first,
              decoration: const InputDecoration(labelText: 'Bộ sách giáo khoa', border: OutlineInputBorder()),
              items: SchoolSubjects.bookSeriesList.map((b) => DropdownMenuItem(value: b, child: Text(b, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (val) {
                if (val != null) {
                  ref.read(teachingSuiteProjectNotifierProvider.notifier).updateProjectData(data.copyWith(bookSeries: val));
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: SchoolSubjects.durations.contains(data.duration) ? data.duration : SchoolSubjects.durations.first,
              decoration: const InputDecoration(labelText: 'Thời lượng tiết dạy', border: OutlineInputBorder()),
              items: SchoolSubjects.durations.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (val) {
                if (val != null) {
                  ref.read(teachingSuiteProjectNotifierProvider.notifier).updateProjectData(data.copyWith(duration: val));
                }
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _requirementsController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Yêu cầu đặc biệt của giáo viên (Tùy chọn)',
                hintText: 'Ví dụ: Tăng cường hoạt động thảo luận nhóm, sử dụng sơ đồ tư duy...',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _syncData(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferenceAndObjectivesCard(LessonProjectData data, ThemeData theme, int refLength, int maxChars) {
    final isOverLimit = refLength > maxChars;

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('2. Mục tiêu & Học liệu tham khảo', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _objectivesController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Mục tiêu cần đạt theo GDPT 2018',
                hintText: 'Nhập mục tiêu kiến thức, năng lực đặc thù và phẩm chất chủ yếu của bài dạy...',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _syncData(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text('Tài liệu / Ngữ liệu bài học:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                Text(
                  '$refLength / $maxChars ký tự',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isOverLimit ? Colors.red : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _referenceController,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: 'Dán nội dung bài đọc, văn bản trích dẫn, hoặc nội dung trích xuất từ PDF/Scanner/Thư viện...',
                border: const OutlineInputBorder(),
                errorText: isOverLimit ? 'Vượt quá dung lượng khuyến nghị ($maxChars ký tự). AI sẽ cắt ngắn phần vượt quá.' : null,
              ),
              onChanged: (_) => _syncData(),
            ),
          ],
        ),
      ),
    );
  }
}
