import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../../../core/ai/ai_model_config.dart';
import '../../../../core/projects/domain/artifact_type.dart';
import '../../../../core/projects/domain/project_artifact.dart';
import '../../../../core/providers/app_providers.dart';
import '../../application/teaching_suite_providers.dart';
import '../../domain/models/worksheet_models.dart';
import '../../infrastructure/teaching_suite_docx_exporter.dart';
import 'cloud_privacy_consent_dialog.dart';

class WorksheetPanel extends ConsumerStatefulWidget {
  const WorksheetPanel({super.key});

  @override
  ConsumerState<WorksheetPanel> createState() => _WorksheetPanelState();
}

class _WorksheetPanelState extends ConsumerState<WorksheetPanel> {
  WorksheetPreset _selectedPreset = WorksheetPreset.luyenTap;
  int _taskCount = 3;
  bool _isExporting = false;
  static const _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final projectState = ref.read(teachingSuiteProjectNotifierProvider);
      final pId = projectState.activeProject?.id;
      if (pId != null) {
        ref.read(teachingSuiteWorksheetNotifierProvider.notifier).loadForProject(
              pId,
              defaultTitle: 'Phiếu học tập: ${projectState.projectData.lessonTitle.isNotEmpty ? projectState.projectData.lessonTitle : "Bài học"}',
              subject: projectState.projectData.subject,
              grade: projectState.projectData.grade,
              preset: _selectedPreset,
            );
      }
    });
  }

  Future<void> _handleGenerateWorksheet() async {
    final aiState = ref.read(teachingSuiteAiNotifierProvider);
    final projectState = ref.read(teachingSuiteProjectNotifierProvider);

    if (aiState.connectionStatus?.isSuccessful != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa cấu hình AI. Bạn có thể tự thêm nhiệm vụ học tập thủ công.')),
      );
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

    final ws = await ref.read(teachingSuiteAiNotifierProvider.notifier).generateWorksheet(
          project: projectState.projectData,
          preset: _selectedPreset,
          taskCount: _taskCount,
        );

    if (!mounted) return;
    if (ws != null) {
      final pId = projectState.activeProject?.id ?? '';
      await ref.read(teachingSuiteWorksheetNotifierProvider.notifier).setWorksheet(
            ws.copyWith(projectId: pId),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã tạo thành công Phiếu học tập qua AI!')),
      );
    }
  }

  Future<void> _exportDocx() async {
    final wsState = ref.read(teachingSuiteWorksheetNotifierProvider);
    final currentWorksheet = wsState.worksheet;
    if (currentWorksheet == null || currentWorksheet.tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phiếu học tập chưa có nhiệm vụ nào.')),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final ws = ref.read(workspaceManagerProvider);
      final projectState = ref.read(teachingSuiteProjectNotifierProvider);
      final safeTitle = (currentWorksheet.title).replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final fileName = '02_Phieu_hoc_tap_${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.docx';
      final outPath = p.join(ws.exportsDir.path, fileName);

      await TeachingSuiteDocxExporter.exportWorksheet(
        worksheet: currentWorksheet,
        outputPath: outPath,
      );

      // Register artifact in database
      if (projectState.activeProject != null) {
        final repo = ref.read(workspaceProjectRepositoryProvider);
        final art = ProjectArtifact(
          id: 'art_${_uuid.v4()}',
          projectId: projectState.activeProject!.id,
          artifactType: ArtifactType.docx,
          filePath: outPath,
          createdAt: DateTime.now(),
          metadataJson: '{"subtype":"worksheet","title":"${currentWorksheet.title}"}',
        );
        await repo.attachArtifact(art);
        await ref.read(teachingSuiteProjectNotifierProvider.notifier).refreshArtifacts();
      }

      if (!mounted) return;
      setState(() => _isExporting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xuất thành công: $fileName'),
          action: SnackBarAction(
            label: 'Mở tệp',
            onPressed: () => Process.run('explorer.exe', [outPath]),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi xuất tài liệu DOCX: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showTaskDialog({WorksheetTask? existingTask}) {
    final instructionCtrl = TextEditingController(text: existingTask?.instruction ?? '');
    final contentCtrl = TextEditingController(text: existingTask?.content ?? '');
    final hintCtrl = TextEditingController(text: existingTask?.hint ?? '');
    WorksheetTaskType selectedType = existingTask?.taskType ?? WorksheetTaskType.shortAnswer;
    int points = (existingTask?.points ?? 2.0).toInt();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(existingTask == null ? 'Thêm nhiệm vụ học tập' : 'Chỉnh sửa nhiệm vụ'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: instructionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Chỉ dẫn nhiệm vụ (Yêu cầu HS làm gì)',
                      hintText: 'Ví dụ: Đọc văn bản và trả lời câu hỏi',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Nội dung chi tiết / Câu hỏi / Chỗ trống',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: hintCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Gợi ý / Hướng dẫn thực hiện (Tùy chọn)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<WorksheetTaskType>(
                          value: selectedType,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Dạng bài tập', border: OutlineInputBorder()),
                          items: WorksheetTaskType.values.map((t) {
                            return DropdownMenuItem(value: t, child: Text(t.label));
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setDlgState(() => selectedType = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 110,
                        child: DropdownButtonFormField<int>(
                          value: points,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Điểm số', border: OutlineInputBorder()),
                          items: [1, 2, 3, 4, 5, 10].map((p) => DropdownMenuItem(value: p, child: Text('$p điểm'))).toList(),
                          onChanged: (v) {
                            if (v != null) setDlgState(() => points = v);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            FilledButton(
              onPressed: () {
                final instruction = instructionCtrl.text.trim();
                final content = contentCtrl.text.trim();
                if (instruction.isEmpty && content.isEmpty) return;

                if (existingTask == null) {
                  final newTask = WorksheetTask(
                    id: 'task_${_uuid.v4()}',
                    instruction: instruction.isNotEmpty ? instruction : 'Nhiệm vụ học tập',
                    content: content,
                    hint: hintCtrl.text.trim().isNotEmpty ? hintCtrl.text.trim() : null,
                    taskType: selectedType,
                    points: points.toDouble(),
                  );
                  ref.read(teachingSuiteWorksheetNotifierProvider.notifier).addTask(newTask);
                } else {
                  final updated = existingTask.copyWith(
                    instruction: instruction.isNotEmpty ? instruction : existingTask.instruction,
                    content: content,
                    hint: hintCtrl.text.trim().isNotEmpty ? hintCtrl.text.trim() : null,
                    taskType: selectedType,
                    points: points.toDouble(),
                  );
                  ref.read(teachingSuiteWorksheetNotifierProvider.notifier).updateTask(updated);
                }
                Navigator.pop(ctx);
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(teachingSuiteAiNotifierProvider);
    final wsState = ref.watch(teachingSuiteWorksheetNotifierProvider);
    final currentWorksheet = wsState.worksheet;
    final isGenerating = aiState.isGeneratingWorksheet;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toolbar Card
          Card(
            elevation: 0.5,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 170,
                        child: DropdownButtonFormField<WorksheetPreset>(
                          value: _selectedPreset,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Chủ đề phiếu', border: OutlineInputBorder()),
                          items: WorksheetPreset.values.map((p) {
                            return DropdownMenuItem(value: p, child: Text(p.label));
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _selectedPreset = v);
                              ref.read(teachingSuiteWorksheetNotifierProvider.notifier).updateMetadata(preset: v);
                            }
                          },
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: DropdownButtonFormField<int>(
                          value: _taskCount,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Số bài tập', border: OutlineInputBorder()),
                          items: [2, 3, 4, 5, 6].map((c) => DropdownMenuItem(value: c, child: Text('$c bài'))).toList(),
                          onChanged: (v) => setState(() => _taskCount = v ?? 3),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: isGenerating ? null : _handleGenerateWorksheet,
                        icon: isGenerating
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.auto_awesome, size: 18),
                        label: Text(isGenerating ? 'Đang tạo...' : 'Tạo phiếu bằng AI'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _showTaskDialog(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Thêm bài tập'),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _isExporting ? null : _exportDocx,
                        icon: _isExporting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.description, size: 18),
                        label: Text(_isExporting ? 'Đang xuất...' : 'Xuất Word (02_Phieu_hoc_tap.docx)'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Main Worksheet View
          Expanded(
            child: currentWorksheet == null || currentWorksheet.tasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('Chưa có nhiệm vụ học tập nào.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _showTaskDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('Thêm nhiệm vụ đầu tiên'),
                        ),
                      ],
                    ),
                  )
                : Card(
                    elevation: 0.5,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  currentWorksheet.title,
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Chip(
                                label: Text('${currentWorksheet.tasks.length} nhiệm vụ | ${currentWorksheet.durationMinutes} phút'),
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                              ),
                            ],
                          ),
                          const Divider(),
                          Expanded(
                            child: ListView.separated(
                              itemCount: currentWorksheet.tasks.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final task = currentWorksheet.tasks[index];
                                return Card(
                                  elevation: 0.5,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          child: Text('${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      task.instruction,
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                    ),
                                                  ),
                                                  Chip(
                                                    label: Text('${task.taskType.label} (${task.points}đ)'),
                                                    padding: EdgeInsets.zero,
                                                    labelStyle: const TextStyle(fontSize: 11),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(task.content, style: const TextStyle(fontSize: 13.5)),
                                              if (task.hint != null && task.hint!.isNotEmpty) ...[
                                                const SizedBox(height: 6),
                                                Text('💡 Gợi ý: ${task.hint}', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.blueGrey[700])),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit, size: 18),
                                              tooltip: 'Chỉnh sửa',
                                              onPressed: () => _showTaskDialog(existingTask: task),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                              tooltip: 'Xóa bài tập',
                                              onPressed: () {
                                                ref.read(teachingSuiteWorksheetNotifierProvider.notifier).deleteTask(task.id);
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
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
