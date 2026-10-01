import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/filesystem/workspace_manager.dart';
import '../../../../core/providers/app_providers.dart';
import '../../application/assessment_project_notifier.dart';
import '../../application/exam_builder_notifier.dart';
import '../../application/exam_code_notifier.dart';
import '../../application/exam_matrix_notifier.dart';
import '../../application/exam_specification_notifier.dart';

/// Tab 7: Xuất bản trọn bộ Đề thi & Quản lý Sản phẩm (Sections 43-53, 69-71).
class AssessmentArtifactsPanel extends ConsumerWidget {
  const AssessmentArtifactsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projState = ref.watch(assessmentProjectNotifierProvider);
    final specState = ref.watch(examSpecificationNotifierProvider);
    final matrixState = ref.watch(examMatrixNotifierProvider);
    final builderState = ref.watch(examBuilderNotifierProvider);
    final codeState = ref.watch(examCodeNotifierProvider);

    final project = projState.activeProject;
    final spec = specState.specification;
    final matrix = matrixState.matrix;
    final paper = builderState.masterPaper;

    if (project == null || spec == null || matrix == null || paper == null) {
      return const Center(
        child: Text('Vui lòng hoàn thiện Ma trận và tạo Đề thi gốc trước khi xuất bản.'),
      );
    }

    final preflight = ref.read(examCodeNotifierProvider.notifier).runPreflight(
          specification: spec,
          matrix: matrix,
          masterPaper: paper,
        );

    final exportResult = codeState.exportResult;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preflight Checklist Box (Sections 69 & 70)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        preflight.canExport ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        color: preflight.canExport ? AppColors.success : AppColors.error,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        preflight.canExport
                            ? 'KIỂM TRA TIỀN XUẤT BẢN: ĐẠT TIÊU CHUẨN'
                            : 'KIỂM TRA TIỀN XUẤT BẢN: CHƯA ĐỦ ĐIỀU KIỆN',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: preflight.canExport ? AppColors.success : AppColors.error,
                        ),
                      ),
                      const Spacer(),
                      if (preflight.isDraft)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'CHẾ ĐỘ BẢN NHÁP (DRAFT)',
                            style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: 24),
                  if (preflight.hasErrors) ...[
                    const Text('Các lỗi cần khắc phục:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
                    const SizedBox(height: 6),
                    ...preflight.blockingErrors.map((e) => Text(' • $e', style: const TextStyle(color: AppColors.error, fontSize: 13))),
                    const SizedBox(height: 12),
                  ],
                  if (preflight.warnings.isNotEmpty) ...[
                    const Text('Lưu ý cảnh báo:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                    const SizedBox(height: 6),
                    ...preflight.warnings.map((w) => Text(' • $w', style: const TextStyle(color: Color(0xFFD97706), fontSize: 13))),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Primary Export Action Button (Section 50)
          Center(
            child: SizedBox(
              height: 52,
              child: FilledButton.icon(
                icon: const Icon(Icons.file_download_rounded, size: 22),
                label: const Text(
                  'XUẤT TRỌN BỘ ĐỀ THI & ĐÁP ÁN RA WORD (.DOCX)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: preflight.canExport ? const Color(0xFF059669) : Colors.grey,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                ),
                onPressed: preflight.canExport && !codeState.isExporting
                    ? () => _exportAll(context, ref, project, spec, matrix, matrixState.objectives, paper)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Recent Export Result Banner if any
          if (exportResult != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: exportResult.successful
                    ? AppColors.success.withOpacity(0.1)
                    : AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: exportResult.successful ? AppColors.success : AppColors.error,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        exportResult.successful ? Icons.check_circle : Icons.error,
                        color: exportResult.successful ? AppColors.success : AppColors.error,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        exportResult.successful
                            ? 'Đã xuất thành công ${exportResult.successfulFiles.length} tệp Word (.docx)!'
                            : 'Xuất tệp gặp lỗi (${exportResult.failedFiles.length} tệp thất bại).',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: exportResult.successful ? AppColors.success : AppColors.error,
                        ),
                      ),
                      const Spacer(),
                      if (exportResult.exportDirectory.isNotEmpty)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.folder_open_rounded, size: 16),
                          label: const Text('Mở thư mục tệp'),
                          onPressed: () => WorkspaceManager.openContainingFolder(exportResult.exportDirectory),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Đường dẫn: ${exportResult.exportDirectory}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  if (exportResult.successfulFiles.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...exportResult.successfulFiles.map((f) => Text('  ✓ ${File(f).uri.pathSegments.last}', style: const TextStyle(fontSize: 12))),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 24),

          // Project Artifact History List (Section 52 & 53)
          Row(
            children: [
              const Icon(Icons.history_rounded, size: 20),
              const SizedBox(width: 8),
              const Text('Lịch sử sản phẩm đã xuất (Project Artifacts)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: () => ref.read(assessmentProjectNotifierProvider.notifier).refreshArtifacts(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (projState.artifacts.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Chưa có sản phẩm xuất bản nào cho dự án này.', style: TextStyle(color: Colors.grey)),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: projState.artifacts.length,
              itemBuilder: (context, idx) {
                final art = projState.artifacts[idx];
                Map<String, dynamic> metadata = {};
                if (art.metadataJson != null && art.metadataJson!.isNotEmpty) {
                  try {
                    metadata = jsonDecode(art.metadataJson!) as Map<String, dynamic>;
                  } catch (_) {}
                }
                final fileName = (metadata['file_name'] as String?) ??
                    (art.filePath != null ? File(art.filePath!).uri.pathSegments.last : 'Document.docx');
                final subtype = (metadata['artifactSubtype'] as String?) ??
                    (metadata['subtype'] as String?) ??
                    art.artifactType.displayName;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.description, color: Color(0xFF2563EB)),
                    title: Text(fileName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Loại: $subtype • Đường dẫn: ${art.filePath ?? "N/A"}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (art.filePath != null)
                          IconButton(
                            icon: const Icon(Icons.folder_open, size: 20),
                            tooltip: 'Mở thư mục chứa',
                            onPressed: () => WorkspaceManager.openFolder(File(art.filePath!).parent.path),
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                          tooltip: 'Xóa khỏi dự án',
                          onPressed: () => ref.read(assessmentProjectNotifierProvider.notifier).removeArtifact(art),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _exportAll(
    BuildContext context,
    WidgetRef ref,
    dynamic project,
    dynamic spec,
    dynamic matrix,
    dynamic objectives,
    dynamic paper,
  ) async {
    final ws = ref.read(workspaceManagerProvider);
    final exportDir = ws.exportsDir;
    final projRepo = ref.read(workspaceProjectRepositoryProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đang xuất trọn bộ đề thi và đáp án ra các tệp Word (.docx)...')),
    );

    final result = await ref.read(examCodeNotifierProvider.notifier).exportPackage(
          project: project,
          specification: spec,
          matrix: matrix,
          objectives: objectives,
          masterPaper: paper,
          baseExportDir: exportDir.path,
          projectRepository: projRepo,
        );

    ref.read(assessmentProjectNotifierProvider.notifier).refreshArtifacts();

    if (context.mounted) {
      if (result.successful) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xuất thành công ${result.successfulFiles.length} tệp Word!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi xuất tệp: ${result.errors.join(", ")}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
