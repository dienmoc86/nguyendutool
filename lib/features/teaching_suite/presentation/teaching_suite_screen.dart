import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/teaching_suite_project_notifier.dart';
import '../application/teaching_suite_providers.dart';
import 'widgets/lesson_overview_panel.dart';
import 'widgets/lesson_plan_editor_panel.dart';
import 'widgets/question_bank_panel.dart';
import 'widgets/rubric_panel.dart';
import 'widgets/teaching_artifacts_panel.dart';
import 'widgets/worksheet_panel.dart';

class TeachingSuiteScreen extends ConsumerStatefulWidget {
  const TeachingSuiteScreen({super.key});

  @override
  ConsumerState<TeachingSuiteScreen> createState() => _TeachingSuiteScreenState();
}

class _TeachingSuiteScreenState extends ConsumerState<TeachingSuiteScreen> {
  int _selectedTabIndex = 0;

  final List<String> _tabTitles = [
    'Tổng quan bài dạy',
    'Giáo án (Công văn 5512)',
    'Phiếu học tập (Worksheet)',
    'Ngân hàng Câu hỏi & Đề thi',
    'Rubric đánh giá',
    'Hồ sơ sản phẩm đã xuất',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(teachingSuiteAiNotifierProvider.notifier).checkConnection();
    });
  }

  void _showNewProjectDialog() {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tạo dự án bài dạy mới'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Tên bài học / Chủ đề bài dạy',
            hintText: 'Ví dụ: Ngữ văn 9 - Truyện Kiều',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            onPressed: () async {
              final text = titleController.text.trim();
              if (text.isNotEmpty) {
                await ref.read(teachingSuiteProjectNotifierProvider.notifier).createNewProject(title: text);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
              }
            },
            child: const Text('Tạo dự án'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen for active project switch to synchronize child notifiers and prevent state leakage
    ref.listen<TeachingSuiteProjectState>(teachingSuiteProjectNotifierProvider, (prev, next) {
      final oldId = prev?.activeProject?.id;
      final newId = next.activeProject?.id;
      if (newId != null && newId != oldId) {
        final title = next.projectData.lessonTitle;
        ref.read(teachingSuiteQuestionsNotifierProvider.notifier).loadForProject(
              newId,
              defaultTitle: 'Bộ câu hỏi: $title',
            );
        ref.read(teachingSuiteRubricNotifierProvider.notifier).loadForProject(
              newId,
              defaultTitle: 'Rubric đánh giá: $title',
            );
        ref.read(teachingSuiteWorksheetNotifierProvider.notifier).loadForProject(
              newId,
              defaultTitle: 'Phiếu học tập: $title',
            );
      }
    });

    final aiState = ref.watch(teachingSuiteAiNotifierProvider);
    final isAiConfigured = aiState.connectionStatus?.isSuccessful ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.auto_stories, size: 24),
            Expanded(
              child: Text(
                'Trợ lý Giảng dạy (Teaching Suite) — ${_tabTitles[_selectedTabIndex]}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // Project duplicate button
          IconButton(
            icon: const Icon(Icons.copy, size: 20),
            tooltip: 'Nhân bản bài dạy này',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final dup = await ref.read(teachingSuiteProjectNotifierProvider.notifier).duplicateProject();
              if (dup != null && mounted) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Đã nhân bản dự án: ${dup.name}')),
                );
              }
            },
          ),
          // New Project button
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 22),
            tooltip: 'Tạo dự án bài dạy mới',
            onPressed: _showNewProjectDialog,
          ),
          const SizedBox(width: 8),
          // AI status chip
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ActionChip(
              avatar: Icon(
                isAiConfigured ? Icons.cloud_done : Icons.cloud_off,
                size: 16,
                color: isAiConfigured ? Colors.green : Colors.orange,
              ),
              label: Text(
                isAiConfigured ? 'Gemini AI Sẵn sàng' : 'AI chưa cấu hình',
                style: TextStyle(
                  fontSize: 12,
                  color: isAiConfigured ? Colors.green.shade800 : Colors.orange.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/settings');
              },
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          // Left Sub-Navigation Sidebar
          NavigationRail(
            selectedIndex: _selectedTabIndex,
            onDestinationSelected: (idx) => setState(() => _selectedTabIndex = idx),
            labelType: NavigationRailLabelType.all,
            minWidth: 84,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Tổng quan'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.description_outlined),
                selectedIcon: Icon(Icons.description),
                label: Text('Giáo án'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.assignment_outlined),
                selectedIcon: Icon(Icons.assignment),
                label: Text('Phiếu học tập'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.quiz_outlined),
                selectedIcon: Icon(Icons.quiz),
                label: Text('Câu hỏi'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.checklist_outlined),
                selectedIcon: Icon(Icons.checklist),
                label: Text('Rubric'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.folder_shared_outlined),
                selectedIcon: Icon(Icons.folder_shared),
                label: Text('Sản phẩm'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          // Main Content View
          Expanded(
            child: IndexedStack(
              index: _selectedTabIndex,
              children: [
                LessonOverviewPanel(
                  onNavigateToPlan: () => setState(() => _selectedTabIndex = 1),
                  onNavigateToWorksheet: () => setState(() => _selectedTabIndex = 2),
                  onNavigateToQuestions: () => setState(() => _selectedTabIndex = 3),
                  onNavigateToRubric: () => setState(() => _selectedTabIndex = 4),
                  onNavigateToArtifacts: () => setState(() => _selectedTabIndex = 5),
                ),
                const LessonPlanEditorPanel(),
                const WorksheetPanel(),
                const QuestionBankPanel(),
                const RubricPanel(),
                const TeachingArtifactsPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
