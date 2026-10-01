import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../../core/ai/ai_model_config.dart';
import '../../../../core/projects/domain/artifact_type.dart';
import '../../../../core/projects/domain/project_artifact.dart';
import '../../../../core/providers/app_providers.dart';
import '../../application/teaching_suite_providers.dart';
import '../../domain/models/rubric_models.dart';
import '../../infrastructure/teaching_suite_docx_exporter.dart';
import 'cloud_privacy_consent_dialog.dart';

class RubricPanel extends ConsumerStatefulWidget {
  const RubricPanel({super.key});

  @override
  ConsumerState<RubricPanel> createState() => _RubricPanelState();
}

class _RubricPanelState extends ConsumerState<RubricPanel> {
  int _levelCount = 4;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final projectState = ref.read(teachingSuiteProjectNotifierProvider);
      if (projectState.activeProject != null) {
        ref.read(teachingSuiteRubricNotifierProvider.notifier).loadForProject(
              projectState.activeProject!.id,
              defaultTitle: 'Rubric đánh giá bài: ${projectState.projectData.lessonTitle}',
            );
      }
    });
  }

  Future<void> _handleGenerateAiRubric() async {
    final messenger = ScaffoldMessenger.of(context);
    final aiState = ref.read(teachingSuiteAiNotifierProvider);
    final projectState = ref.read(teachingSuiteProjectNotifierProvider);

    if (aiState.connectionStatus?.isSuccessful != true) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Chưa cấu hình AI. Bạn có thể xây dựng Rubric đánh giá thủ công.')),
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

    final rubric = await ref.read(teachingSuiteAiNotifierProvider.notifier).generateRubric(
          project: projectState.projectData,
          levelCount: _levelCount,
        );

    if (!mounted) return;
    if (rubric != null) {
      await ref.read(teachingSuiteRubricNotifierProvider.notifier).setRubric(
            rubric.copyWith(projectId: projectState.activeProject?.id ?? ''),
          );
      messenger.showSnackBar(
        const SnackBar(content: Text('Đã tạo thành công Rubric đánh giá bằng AI!')),
      );
    }
  }

  Future<void> _exportDocx() async {
    final rState = ref.read(teachingSuiteRubricNotifierProvider);
    final activeRubric = rState.activeRubric;
    if (activeRubric == null || activeRubric.criteria.isEmpty) return;

    setState(() => _isExporting = true);
    try {
      final ws = ref.read(workspaceManagerProvider);
      final projectState = ref.read(teachingSuiteProjectNotifierProvider);
      final safeTitle = activeRubric.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final fileName = '05_Rubric_${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.docx';
      final outPath = p.join(ws.exportsDir.path, fileName);

      await TeachingSuiteDocxExporter.exportRubric(rubric: activeRubric, outputPath: outPath);

      if (projectState.activeProject != null) {
        final repo = ref.read(workspaceProjectRepositoryProvider);
        await repo.attachArtifact(ProjectArtifact(
          id: 'art_${DateTime.now().millisecondsSinceEpoch}_r',
          projectId: projectState.activeProject!.id,
          artifactType: ArtifactType.docx,
          filePath: outPath,
          createdAt: DateTime.now(),
          metadataJson: '{"subtype":"rubric"}',
        ));
        await ref.read(teachingSuiteProjectNotifierProvider.notifier).refreshArtifacts();
      }

      if (!mounted) return;
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xuất thành công Rubric: $fileName'),
          action: SnackBarAction(
            label: 'Mở thư mục',
            onPressed: () => Process.run('explorer.exe', ['/select,', outPath]),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi xuất tệp: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _handleAddCriterion() {
    final newCrit = RubricCriterion(
      id: 'crit_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Tiêu chí đánh giá mới',
      weight: 20.0,
      levels: const [
        RubricLevel(name: 'Xuất sắc', score: 4.0, description: 'Mô tả mức xuất sắc...'),
        RubricLevel(name: 'Tốt', score: 3.0, description: 'Mô tả mức tốt...'),
        RubricLevel(name: 'Đạt', score: 2.0, description: 'Mô tả mức đạt...'),
        RubricLevel(name: 'Cần cố gắng', score: 1.0, description: 'Mô tả mức cần cố gắng...'),
      ],
    );
    ref.read(teachingSuiteRubricNotifierProvider.notifier).addCriterion(newCrit);
  }

  @override
  Widget build(BuildContext context) {
    final rState = ref.watch(teachingSuiteRubricNotifierProvider);
    final aiState = ref.watch(teachingSuiteAiNotifierProvider);
    final rubric = rState.activeRubric;
    final totalWeight = rubric?.totalWeight ?? 0.0;
    final isValid = rubric?.isWeightValid ?? false;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toolbar
          Card(
            elevation: 0.5,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DropdownButton<int>(
                    value: _levelCount,
                    items: const [
                      DropdownMenuItem(value: 3, child: Text('3 mức độ (Đạt/Khá/Giỏi)')),
                      DropdownMenuItem(value: 4, child: Text('4 mức độ chuẩn GDPT')),
                    ],
                    onChanged: (v) => setState(() => _levelCount = v ?? 4),
                  ),
                  FilledButton.icon(
                    onPressed: aiState.isGenerating ? null : _handleGenerateAiRubric,
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: Text(aiState.isGenerating ? 'Đang tạo...' : 'Tạo Rubric bằng AI'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _handleAddCriterion,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Thêm tiêu chí'),
                  ),
                  // Weight Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isValid ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isValid ? Colors.green : Colors.orange),
                    ),
                    child: Text(
                      'Tổng trọng số: ${totalWeight.toStringAsFixed(1)}% ${isValid ? "✓ Đạt 100%" : "⚠ Chưa đủ 100%"}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isValid ? Colors.green.shade800 : Colors.orange.shade800,
                      ),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _isExporting ? null : _exportDocx,
                    icon: const Icon(Icons.file_download, size: 18),
                    label: const Text('Xuất Rubric DOCX'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Criteria List
          Expanded(
            child: rubric == null || rubric.criteria.isEmpty
                ? const Center(child: Text('Chưa có tiêu chí đánh giá nào. Nhấn "Tạo Rubric bằng AI" hoặc "Thêm tiêu chí".'))
                : ListView.separated(
                    itemCount: rubric.criteria.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final crit = rubric.criteria[index];
                      return Card(
                        elevation: 0.5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: TextFormField(
                                      initialValue: crit.name,
                                      decoration: InputDecoration(
                                        labelText: 'Tên tiêu chí ${index + 1}',
                                        border: const OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      onChanged: (val) {
                                        ref.read(teachingSuiteRubricNotifierProvider.notifier).updateCriterion(crit.copyWith(name: val));
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 1,
                                    child: TextFormField(
                                      initialValue: crit.weight.toString(),
                                      decoration: const InputDecoration(
                                        labelText: 'Trọng số (%)',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        suffixText: '%',
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (val) {
                                        final numVal = double.tryParse(val);
                                        if (numVal != null) {
                                          ref.read(teachingSuiteRubricNotifierProvider.notifier).updateCriterion(crit.copyWith(weight: numVal));
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () {
                                      ref.read(teachingSuiteRubricNotifierProvider.notifier).deleteCriterion(crit.id);
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Levels table / grid
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: crit.levels.map((lvl) {
                                    return Container(
                                      width: 220,
                                      margin: const EdgeInsets.only(right: 10),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('${lvl.name} (${lvl.score}đ)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          const SizedBox(height: 6),
                                          Text(lvl.description, style: const TextStyle(fontSize: 12, height: 1.3)),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
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
