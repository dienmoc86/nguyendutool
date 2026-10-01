import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../../core/ai/ai_model_config.dart';
import '../../../../core/projects/domain/artifact_type.dart';
import '../../../../core/projects/domain/project_artifact.dart';
import '../../../../core/providers/app_providers.dart';
import '../../application/teaching_suite_providers.dart';
import '../../domain/models/lesson_plan_document.dart';
import '../../infrastructure/teaching_suite_docx_exporter.dart';
import 'cloud_privacy_consent_dialog.dart';

class LessonPlanEditorPanel extends ConsumerStatefulWidget {
  const LessonPlanEditorPanel({super.key});

  @override
  ConsumerState<LessonPlanEditorPanel> createState() => _LessonPlanEditorPanelState();
}

class _LessonPlanEditorPanelState extends ConsumerState<LessonPlanEditorPanel> {
  late TextEditingController _contentController;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    final plan = ref.read(teachingSuiteProjectNotifierProvider).lessonPlan;
    _contentController = TextEditingController(text: plan?.rawContent ?? '');
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _handleGenerateFullPlan() async {
    final aiState = ref.read(teachingSuiteAiNotifierProvider);
    final projectState = ref.read(teachingSuiteProjectNotifierProvider);

    if (aiState.connectionStatus?.isSuccessful != true) {
      _showAiNotConfiguredDialog();
      return;
    }

    if (!aiState.hasAcceptedCloudPrivacy) {
      final agreed = await CloudPrivacyConsentDialog.show(
        context,
        providerName: 'Google Gemini',
        modelName: aiState.connectionStatus?.model ?? AiModelConfig.defaultModel,
      );
      if (!agreed) return;
      ref.read(teachingSuiteAiNotifierProvider.notifier).acceptCloudPrivacy();
    }

    final newPlan = await ref.read(teachingSuiteAiNotifierProvider.notifier).generateLessonPlan(projectState.projectData);
    if (!mounted) return;
    if (newPlan != null) {
      _contentController.text = newPlan.rawContent;
      ref.read(teachingSuiteProjectNotifierProvider.notifier).setLessonPlan(newPlan);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã tạo thành công Kế hoạch bài dạy theo Công văn 5512!')),
      );
    }
  }

  Future<void> _handleRegenerateSection(String sectionKey) async {
    final aiState = ref.read(teachingSuiteAiNotifierProvider);
    final projectState = ref.read(teachingSuiteProjectNotifierProvider);

    if (aiState.connectionStatus?.isSuccessful != true) {
      _showAiNotConfiguredDialog();
      return;
    }

    final regenerated = await ref.read(teachingSuiteAiNotifierProvider.notifier).regenerateSection(
          sectionKey: sectionKey,
          currentContent: _contentController.text,
          project: projectState.projectData,
        );

    if (!mounted) return;
    if (regenerated != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã cải tiến nội dung mục "$sectionKey"')),
      );
    }
  }

  Future<void> _exportDocx() async {
    final projectState = ref.read(teachingSuiteProjectNotifierProvider);
    final text = _contentController.text;
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nội dung giáo án đang trống. Vui lòng nhập nội dung trước khi xuất Word.')),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final ws = ref.read(workspaceManagerProvider);
      final safeTitle = (projectState.projectData.lessonTitle.isNotEmpty ? projectState.projectData.lessonTitle : 'Giao_an')
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final fileName = '01_Giao_an_${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.docx';
      final outPath = p.join(ws.exportsDir.path, fileName);

      final planDoc = LessonPlanDocument.parseFromMarkdown(
        title: projectState.projectData.lessonTitle,
        subject: projectState.projectData.subject,
        grade: projectState.projectData.grade,
        duration: projectState.projectData.duration,
        bookSeries: projectState.projectData.bookSeries,
        markdown: text,
      );

      final file = await TeachingSuiteDocxExporter.exportLessonPlan(
        document: planDoc,
        outputPath: outPath,
      );

      // Register Project Artifact
      if (projectState.activeProject != null) {
        final artifact = ProjectArtifact(
          id: 'art_${DateTime.now().millisecondsSinceEpoch}',
          projectId: projectState.activeProject!.id,
          artifactType: ArtifactType.docx,
          filePath: file.path,
          createdAt: DateTime.now(),
          metadataJson: '{"subtype":"lessonPlan","title":"${projectState.projectData.lessonTitle}"}',
        );
        final repo = ref.read(workspaceProjectRepositoryProvider);
        await repo.attachArtifact(artifact);
        await ref.read(teachingSuiteProjectNotifierProvider.notifier).refreshArtifacts();
      }

      if (!mounted) return;
      setState(() {
        _isExporting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xuất thành công tệp Word: $fileName'),
          action: SnackBarAction(
            label: 'Mở thư mục',
            onPressed: () => Process.run('explorer.exe', ['/select,', outPath]),
          ),
        ),
      );
    } catch (e) {
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi xuất DOCX: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showAiNotConfiguredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('Chưa cấu hình AI'),
          ],
        ),
        content: const Text(
          'Tính năng soạn tự động bằng AI yêu cầu API Key của Google Gemini.\n\nBạn vẫn có thể soạn và chỉnh sửa giáo án hoàn toàn thủ công hoặc xuất tệp Word ngoại tuyến.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đã hiểu')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/settings');
            },
            child: const Text('Đi tới Cài đặt'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final projectState = ref.watch(teachingSuiteProjectNotifierProvider);
    final aiState = ref.watch(teachingSuiteAiNotifierProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toolbar
          Card(
            elevation: 0.5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  FilledButton.icon(
                    onPressed: aiState.isGenerating ? null : _handleGenerateFullPlan,
                    icon: aiState.isGenerating
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.auto_awesome, size: 18),
                    label: Text(aiState.isGenerating ? 'Đang soạn bài...' : 'Tạo toàn văn bằng AI'),
                  ),
                  const SizedBox(width: 12),
                  PopupMenuButton<String>(
                    tooltip: 'Viết lại từng mục chuyên sâu',
                    enabled: !aiState.isGenerating,
                    onSelected: _handleRegenerateSection,
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'I. Mục tiêu', child: Text('Làm mới I. Mục tiêu')),
                      const PopupMenuItem(value: 'II. Thiết bị dạy học', child: Text('Làm mới II. Thiết bị dạy học')),
                      const PopupMenuItem(value: 'III. Hoạt động 1: Khởi động', child: Text('Viết lại Hoạt động Khởi động')),
                      const PopupMenuItem(value: 'III. Hoạt động 2: Hình thành kiến thức', child: Text('Viết lại Hoạt động Khám phá')),
                      const PopupMenuItem(value: 'III. Hoạt động 3: Luyện tập', child: Text('Viết lại Hoạt động Luyện tập')),
                      const PopupMenuItem(value: 'III. Hoạt động 4: Vận dụng', child: Text('Viết lại Hoạt động Vận dụng')),
                    ],
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Làm mới từng phần ▾'),
                    ),
                  ),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: _isExporting ? null : _exportDocx,
                    icon: _isExporting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.file_download, size: 18),
                    label: const Text('Xuất Word (.docx)'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Main Editor
          Expanded(
            child: Card(
              elevation: 0.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Kế hoạch bài dạy (Công văn 5512): ${projectState.projectData.lessonTitle}',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_contentController.text.length} ký tự',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: TextField(
                        controller: _contentController,
                        maxLines: null,
                        expands: true,
                        style: const TextStyle(fontSize: 14, height: 1.5, fontFamily: 'Segoe UI'),
                        decoration: const InputDecoration(
                          hintText: 'Nhập nội dung giáo án hoặc nhấn "Tạo toàn văn bằng AI" để tự động biên soạn...',
                          border: InputBorder.none,
                        ),
                        onChanged: (val) {
                          final currentPlan = ref.read(teachingSuiteProjectNotifierProvider).lessonPlan;
                          ref.read(teachingSuiteProjectNotifierProvider.notifier).setLessonPlan(
                                (currentPlan ?? const LessonPlanDocument()).copyWith(rawContent: val),
                              );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
