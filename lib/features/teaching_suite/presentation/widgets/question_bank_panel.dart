import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../../core/ai/ai_model_config.dart';
import '../../../../core/projects/domain/artifact_type.dart';
import '../../../../core/projects/domain/project_artifact.dart';
import '../../../../core/providers/app_providers.dart';
import '../../application/teaching_suite_providers.dart';
import '../../domain/models/question_models.dart';
import '../../domain/models/mini_assessment_model.dart';
import '../../infrastructure/teaching_suite_docx_exporter.dart';
import 'cloud_privacy_consent_dialog.dart';
import 'mini_assessment_dialog.dart';

class QuestionBankPanel extends ConsumerStatefulWidget {
  const QuestionBankPanel({super.key});

  @override
  ConsumerState<QuestionBankPanel> createState() => _QuestionBankPanelState();
}

class _QuestionBankPanelState extends ConsumerState<QuestionBankPanel> {
  int _aiCount = 4;
  QuestionDifficulty? _aiDifficulty;
  QuestionType? _aiType = QuestionType.multipleChoice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final projectState = ref.read(teachingSuiteProjectNotifierProvider);
      if (projectState.activeProject != null) {
        ref.read(teachingSuiteQuestionsNotifierProvider.notifier).loadForProject(
              projectState.activeProject!.id,
              defaultTitle: 'Bộ câu hỏi: ${projectState.projectData.lessonTitle}',
              subject: projectState.projectData.subject,
              grade: projectState.projectData.grade,
            );
      }
    });
  }

  Future<void> _handleGenerateAiQuestions() async {
    final messenger = ScaffoldMessenger.of(context);
    final aiState = ref.read(teachingSuiteAiNotifierProvider);
    final projectState = ref.read(teachingSuiteProjectNotifierProvider);

    if (aiState.connectionStatus?.isSuccessful != true) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Chưa cấu hình AI. Bạn có thể tự thêm câu hỏi thủ công.')),
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

    final items = await ref.read(teachingSuiteAiNotifierProvider.notifier).generateQuestions(
          project: projectState.projectData,
          count: _aiCount,
          difficulty: _aiDifficulty,
          type: _aiType,
        );

    if (!mounted) return;
    if (items != null && items.isNotEmpty) {
      await ref.read(teachingSuiteQuestionsNotifierProvider.notifier).addQuestions(items);
      messenger.showSnackBar(
        SnackBar(content: Text('Đã thêm ${items.length} câu hỏi mới vào ngân hàng!')),
      );
    }
  }

  Future<void> _handleAddManualQuestion() async {
    final projectState = ref.read(teachingSuiteProjectNotifierProvider);
    final effectiveProjectId = projectState.activeProject?.id ??
        ref.read(teachingSuiteQuestionsNotifierProvider).activeSet?.projectId ??
        'proj_${DateTime.now().millisecondsSinceEpoch}';

    final newQ = QuestionItem(
      id: 'q_${DateTime.now().millisecondsSinceEpoch}',
      type: QuestionType.multipleChoice,
      prompt: 'Câu hỏi mới',
      choices: ['A. Phương án A', 'B. Phương án B', 'C. Phương án C', 'D. Phương án D'],
      correctAnswer: 'A',
      difficulty: QuestionDifficulty.nhanBiet,
      explanation: 'Giải thích đáp án đúng',
    );
    await ref.read(teachingSuiteQuestionsNotifierProvider.notifier).addQuestions(
      [newQ],
      projectId: effectiveProjectId,
    );
  }

  Future<void> _handleBuildMiniAssessment() async {
    final qState = ref.read(teachingSuiteQuestionsNotifierProvider);
    final activeSet = qState.activeSet;
    if (activeSet == null || activeSet.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ngân hàng câu hỏi chưa có dữ liệu.')),
      );
      return;
    }

    final config = await MiniAssessmentDialog.show(
      context,
      initialTitle: activeSet.title,
      availableQuestionsCount: activeSet.items.length,
    );
    if (config == null) return;

    final result = await ref.read(teachingSuiteQuestionsNotifierProvider.notifier).buildMiniAssessment(config);
    if (!mounted) return;
    if (result != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(result.title),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Thời gian làm bài: ${result.durationMinutes} phút | Tổng số câu: ${result.questions.length}'),
                  const Divider(),
                  const Text('Đáp án tự động tạo (Deterministic Answer Key):', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...result.deterministicAnswerKey.entries.map((e) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('Câu ${e.key}: ${e.value}', style: const TextStyle(fontSize: 13)),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _exportMiniAssessment(result);
              },
              icon: const Icon(Icons.file_download, size: 18),
              label: const Text('Xuất Đề & Đáp án ra Word'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _exportMiniAssessment(MiniAssessment assessment) async {
    try {
      final ws = ref.read(workspaceManagerProvider);
      final projectState = ref.read(teachingSuiteProjectNotifierProvider);
      final safeTitle = assessment.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

      final qFile = p.join(ws.exportsDir.path, '03_De_kiem_tra_$safeTitle.docx');
      await TeachingSuiteDocxExporter.exportMiniAssessment(assessment: assessment, outputPath: qFile);

      final aFile = p.join(ws.exportsDir.path, '04_Dap_an_$safeTitle.docx');
      await TeachingSuiteDocxExporter.exportMiniAssessmentAnswerKey(assessment: assessment, outputPath: aFile);

      if (projectState.activeProject != null) {
        final repo = ref.read(workspaceProjectRepositoryProvider);
        await repo.attachArtifact(ProjectArtifact(
          id: 'art_${DateTime.now().microsecondsSinceEpoch}_mini_q',
          projectId: projectState.activeProject!.id,
          artifactType: ArtifactType.docx,
          filePath: qFile,
          createdAt: DateTime.now(),
          metadataJson: '{"subtype":"miniAssessment"}',
        ));
        await repo.attachArtifact(ProjectArtifact(
          id: 'art_${DateTime.now().microsecondsSinceEpoch}_mini_a',
          projectId: projectState.activeProject!.id,
          artifactType: ArtifactType.docx,
          filePath: aFile,
          createdAt: DateTime.now(),
          metadataJson: '{"subtype":"miniAssessmentAnswerKey"}',
        ));
        await ref.read(teachingSuiteProjectNotifierProvider.notifier).refreshArtifacts();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xuất thành công Đề (${assessment.questions.length} câu) & Đáp án ra Word!'),
          action: SnackBarAction(
            label: 'Mở thư mục',
            onPressed: () => Process.run('explorer.exe', ['/select,', qFile]),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi xuất tệp: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _exportQuestionSetAndAnswerKey() async {
    final qState = ref.read(teachingSuiteQuestionsNotifierProvider);
    final activeSet = qState.activeSet;
    if (activeSet == null || activeSet.items.isEmpty) return;

    try {
      final ws = ref.read(workspaceManagerProvider);
      final projectState = ref.read(teachingSuiteProjectNotifierProvider);
      final safeTitle = activeSet.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

      // 03_Cau_hoi.docx
      final qFile = p.join(ws.exportsDir.path, '03_Cau_hoi_$safeTitle.docx');
      await TeachingSuiteDocxExporter.exportQuestionSet(questionSet: activeSet, outputPath: qFile);

      // 04_Dap_an.docx
      final aFile = p.join(ws.exportsDir.path, '04_Dap_an_$safeTitle.docx');
      await TeachingSuiteDocxExporter.exportAnswerKey(questionSet: activeSet, outputPath: aFile);

      if (projectState.activeProject != null) {
        final repo = ref.read(workspaceProjectRepositoryProvider);
        await repo.attachArtifact(ProjectArtifact(
          id: 'art_${DateTime.now().millisecondsSinceEpoch}_q',
          projectId: projectState.activeProject!.id,
          artifactType: ArtifactType.docx,
          filePath: qFile,
          createdAt: DateTime.now(),
          metadataJson: '{"subtype":"questionSet"}',
        ));
        await repo.attachArtifact(ProjectArtifact(
          id: 'art_${DateTime.now().millisecondsSinceEpoch}_a',
          projectId: projectState.activeProject!.id,
          artifactType: ArtifactType.docx,
          filePath: aFile,
          createdAt: DateTime.now(),
          metadataJson: '{"subtype":"answerKey"}',
        ));
        await ref.read(teachingSuiteProjectNotifierProvider.notifier).refreshArtifacts();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Đã xuất thành công Đề câu hỏi và Đáp án ra Word!'),
          action: SnackBarAction(
            label: 'Mở thư mục',
            onPressed: () => Process.run('explorer.exe', ['/select,', qFile]),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi xuất tệp: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final qState = ref.watch(teachingSuiteQuestionsNotifierProvider);
    final aiState = ref.watch(teachingSuiteAiNotifierProvider);
    final theme = Theme.of(context);
    final activeSet = qState.activeSet;

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
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DropdownButton<QuestionDifficulty?>(
                    value: _aiDifficulty,
                    hint: const Text('Mọi mức độ'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Đa dạng mức độ')),
                      ...QuestionDifficulty.values.map((d) => DropdownMenuItem(value: d, child: Text(d.label))),
                    ],
                    onChanged: (v) => setState(() => _aiDifficulty = v),
                  ),
                  DropdownButton<QuestionType?>(
                    value: _aiType,
                    items: QuestionType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
                    onChanged: (v) => setState(() => _aiType = v),
                  ),
                  DropdownButton<int>(
                    value: _aiCount,
                    items: [2, 4, 6, 10].map((c) => DropdownMenuItem(value: c, child: Text('$c câu'))).toList(),
                    onChanged: (v) => setState(() => _aiCount = v ?? 4),
                  ),
                  FilledButton.icon(
                    onPressed: aiState.isGenerating ? null : _handleGenerateAiQuestions,
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: Text(aiState.isGenerating ? 'Đang soạn...' : 'Sinh câu hỏi bằng AI'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _handleAddManualQuestion,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Thêm câu hỏi'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _handleBuildMiniAssessment,
                    icon: const Icon(Icons.assignment_turned_in, size: 18),
                    label: const Text('Tạo Đề nhanh (Mini Assessment)'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _exportQuestionSetAndAnswerKey,
                    icon: const Icon(Icons.file_download, size: 18),
                    label: const Text('Xuất Đề & Đáp án DOCX'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Question List
          Expanded(
            child: activeSet == null || activeSet.items.isEmpty
                ? const Center(child: Text('Chưa có câu hỏi nào trong ngân hàng. Hãy nhấn "Sinh câu hỏi bằng AI" hoặc "Thêm câu hỏi".'))
                : ListView.separated(
                    itemCount: activeSet.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final q = activeSet.items[index];
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
                                  Chip(
                                    label: Text(q.difficulty.label, style: const TextStyle(fontSize: 12)),
                                    backgroundColor: theme.colorScheme.secondaryContainer,
                                  ),
                                  const SizedBox(width: 8),
                                  Chip(
                                    label: Text(q.type.label, style: const TextStyle(fontSize: 12)),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('Câu ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 18),
                                    tooltip: 'Nhân bản',
                                    onPressed: () => ref.read(teachingSuiteQuestionsNotifierProvider.notifier).duplicateQuestion(q.id),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                    tooltip: 'Xóa câu hỏi',
                                    onPressed: () => ref.read(teachingSuiteQuestionsNotifierProvider.notifier).deleteQuestion(q.id),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                initialValue: q.prompt,
                                decoration: const InputDecoration(labelText: 'Lời dẫn câu hỏi', border: OutlineInputBorder()),
                                onChanged: (val) {
                                  ref.read(teachingSuiteQuestionsNotifierProvider.notifier).updateQuestion(q.copyWith(prompt: val));
                                },
                              ),
                              const SizedBox(height: 10),
                              if (q.type == QuestionType.multipleChoice) ...[
                                ...q.choices.asMap().entries.map((entry) {
                                  final choiceIdx = entry.key;
                                  final choiceText = entry.value;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: TextFormField(
                                      initialValue: choiceText,
                                      decoration: InputDecoration(
                                        labelText: 'Phương án ${String.fromCharCode(65 + choiceIdx)}',
                                        border: const OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      onChanged: (val) {
                                        final updatedChoices = List<String>.from(q.choices);
                                        updatedChoices[choiceIdx] = val;
                                        ref.read(teachingSuiteQuestionsNotifierProvider.notifier).updateQuestion(q.copyWith(choices: updatedChoices));
                                      },
                                    ),
                                  );
                                }),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: q.correctAnswer,
                                      decoration: const InputDecoration(
                                        labelText: 'Đáp án đúng (A/B/C/D hoặc câu trả lời)',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      onChanged: (val) {
                                        ref.read(teachingSuiteQuestionsNotifierProvider.notifier).updateQuestion(q.copyWith(correctAnswer: val));
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 3,
                                    child: TextFormField(
                                      initialValue: q.explanation ?? '',
                                      decoration: const InputDecoration(
                                        labelText: 'Hướng dẫn giải thích',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      onChanged: (val) {
                                        ref.read(teachingSuiteQuestionsNotifierProvider.notifier).updateQuestion(q.copyWith(explanation: val));
                                      },
                                    ),
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
    );
  }
}
