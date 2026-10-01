import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../../core/projects/domain/artifact_type.dart';
import '../../../../core/projects/domain/project_artifact.dart';
import '../../../../core/providers/app_providers.dart';
import '../../application/teaching_suite_providers.dart';
import '../../infrastructure/teaching_suite_docx_exporter.dart';

class TeachingArtifactsPanel extends ConsumerStatefulWidget {
  const TeachingArtifactsPanel({super.key});

  @override
  ConsumerState<TeachingArtifactsPanel> createState() => _TeachingArtifactsPanelState();
}

class _TeachingArtifactsPanelState extends ConsumerState<TeachingArtifactsPanel> {
  bool _isBatchExporting = false;
  String? _batchFolder;

  Future<void> _handleExportAll() async {
    final projectState = ref.read(teachingSuiteProjectNotifierProvider);
    final questionsState = ref.read(teachingSuiteQuestionsNotifierProvider);
    final rubricState = ref.read(teachingSuiteRubricNotifierProvider);
    final worksheetState = ref.read(teachingSuiteWorksheetNotifierProvider);
    final ws = ref.read(workspaceManagerProvider);

    final safeProjName = (projectState.projectData.lessonTitle.isNotEmpty
            ? projectState.projectData.lessonTitle
            : 'Bai_day_${DateTime.now().millisecondsSinceEpoch}')
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    final dateStr = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:T\-]'), '').split('.').first;
    final batchDir = p.join(ws.exportsDir.path, safeProjName, dateStr);

    setState(() => _isBatchExporting = true);
    try {
      final exportResult = await TeachingSuiteDocxExporter.exportAll(
        outputDirectory: batchDir,
        project: projectState.projectData,
        lessonPlan: projectState.lessonPlan,
        worksheet: worksheetState.worksheet,
        questionSet: questionsState.activeSet,
        rubric: rubricState.activeRubric,
      );

      // Register only successful files in DB
      if (projectState.activeProject != null) {
        final repo = ref.read(workspaceProjectRepositoryProvider);
        for (final entry in exportResult.successfulFiles.entries) {
          final art = ProjectArtifact(
            id: 'art_${DateTime.now().microsecondsSinceEpoch}_${entry.key}',
            projectId: projectState.activeProject!.id,
            artifactType: ArtifactType.docx,
            filePath: entry.value,
            createdAt: DateTime.now(),
            metadataJson: '{"subtype":"${entry.key}"}',
          );
          await repo.attachArtifact(art);
        }
        await ref.read(teachingSuiteProjectNotifierProvider.notifier).refreshArtifacts();
      }

      if (!mounted) return;
      setState(() {
        _isBatchExporting = false;
        _batchFolder = batchDir;
      });

      if (exportResult.isFullSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xuất thành công ${exportResult.successfulCount}/5 tệp vào thư mục: $safeProjName/$dateStr'),
            action: SnackBarAction(
              label: 'Mở thư mục',
              onPressed: () => Process.run('explorer.exe', [batchDir]),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Xuất hoàn tất một phần (${exportResult.successfulCount} thành công, ${exportResult.failedCount} lỗi)'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Mở thư mục',
              onPressed: () => Process.run('explorer.exe', [batchDir]),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBatchExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi xuất hàng loạt: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleRemoveArtifact(ProjectArtifact art) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa tài liệu'),
        content: Text('Bạn có chắc muốn xóa bản ghi "${art.filePath != null ? p.basename(art.filePath!) : "tài liệu"}" khỏi dự án này?\n\nLưu ý: Tệp vật lý trên đĩa sẽ được giữ nguyên.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa khỏi dự án'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(teachingSuiteProjectNotifierProvider.notifier).removeArtifact(art.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa tài liệu khỏi dự án')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectState = ref.watch(teachingSuiteProjectNotifierProvider);
    final artifacts = projectState.artifacts;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Card(
            elevation: 0.5,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hồ sơ tài liệu sư phạm bài dạy', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Quản lý các tài liệu xuất bản (DOCX/PDF) đã tạo cho bài học này (${artifacts.length} tệp)', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: _isBatchExporting ? null : _handleExportAll,
                        icon: _isBatchExporting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.folder_zip, size: 18),
                        label: Text(_isBatchExporting ? 'Đang xuất...' : 'Xuất trọn bộ sản phẩm (Export All)'),
                      ),
                      if (_batchFolder != null) ...[
                        OutlinedButton.icon(
                          onPressed: () => Process.run('explorer.exe', [_batchFolder!]),
                          icon: const Icon(Icons.folder_open, size: 18),
                          label: const Text('Mở thư mục xuất'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Artifacts List
          Expanded(
            child: artifacts.isEmpty
                ? const Center(
                    child: Text(
                      'Chưa có tài liệu nào được xuất cho dự án này.\nHãy hoàn thiện Giáo án, Phiếu học tập, Câu hỏi hoặc bấm "Xuất trọn bộ sản phẩm".',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    itemCount: artifacts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final art = artifacts[index];
                      final fileName = art.filePath != null ? p.basename(art.filePath!) : 'Tài liệu ${index + 1}';
                      final fileExists = art.filePath != null && File(art.filePath!).existsSync();

                      return Card(
                        elevation: 0.5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE3F2FD),
                            child: Icon(Icons.description, color: Color(0xFF1976D2), size: 22),
                          ),
                          title: Text(fileName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(
                            'Đường dẫn: ${art.filePath ?? "Chưa lưu đường dẫn"}\nThời gian: ${art.createdAt.toLocal().toString().substring(0, 19)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (fileExists)
                                IconButton(
                                  icon: const Icon(Icons.folder_open, size: 20),
                                  tooltip: 'Mở trong thư mục',
                                  onPressed: () => Process.run('explorer.exe', ['/select,', art.filePath!]),
                                ),
                              if (fileExists)
                                IconButton(
                                  icon: const Icon(Icons.open_in_new, size: 20),
                                  tooltip: 'Mở tệp',
                                  onPressed: () => Process.run('explorer.exe', [art.filePath!]),
                                ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                tooltip: 'Xóa khỏi dự án',
                                onPressed: () => _handleRemoveArtifact(art),
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
    );
  }
}
