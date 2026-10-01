import 'dart:convert';
import 'dart:io';

import 'package:ilocal_client/ilocal_client.dart';
import 'package:ilocal_protocol/ilocal_protocol.dart';

import '../../../core/ai/ai_model_config.dart';
import '../../../core/logging/app_logger.dart';
import '../application/ai_text_generation_service.dart';
import '../domain/ai_question_response_parser.dart';
import '../domain/models/lesson_plan_document.dart';
import '../domain/models/lesson_project_data.dart';
import '../domain/models/question_models.dart';
import '../domain/models/rubric_models.dart';
import '../domain/models/worksheet_models.dart';
import 'prompt_templates.dart';

/// Production implementation of [AiTextGenerationService] using iLocal AI Shared Core.
///
/// Runs 100% offline via local inference (GPU / CPU), requiring NO API Key
/// and zero external internet connectivity.
class ILocalAiTextGenerationService implements AiTextGenerationService {
  final LocalAIClient _client;
  final String _model;

  ILocalAiTextGenerationService({
    LocalAIClient? client,
    String? model,
    int port = 18181,
  })  : _client = client ?? LocalAIClient(port: port),
        _model = model ?? AiModelConfig.defaultLocalModel;

  @override
  String get providerName => AiModelConfig.providerIlocal;

  @override
  String get currentModel => _model;

  /// Helper to send a text generation request to iLocal AI Core.
  Future<String> _generate(String prompt, {double temperature = 0.3, int maxTokens = 4096}) async {
    final req = ChatRequest(
      model: _model,
      messages: [
        ChatMessage.system(
          'Bạn là trợ lý AI sư phạm tiếng Việt chuẩn mực, thông minh và chính xác. '
          'Hãy suy nghĩ cẩn thận và trả lời bằng tiếng Việt tự nhiên, đúng định dạng yêu cầu.',
        ),
        ChatMessage.user(prompt),
      ],
      temperature: temperature,
      maxTokens: maxTokens,
    );

    final result = await _client.generate(req);
    if (result.isSuccess && result.value.choices.isNotEmpty) {
      return result.value.text;
    } else if (result.isFailure) {
      final err = result.error;
      AppLogger.error('iLocal AI Core error: [${err.code}] ${err.message}');
      throw HttpException('iLocal AI (${err.code}): ${err.message}');
    } else {
      throw const FormatException('Không nhận được nội dung phản hồi từ mô hình iLocal AI.');
    }
  }

  /// Extracts pure JSON string from AI response.
  static String extractJson(String text) {
    String trimmed = text.trim();
    if (trimmed.startsWith('```json')) {
      trimmed = trimmed.substring(7);
    } else if (trimmed.startsWith('```')) {
      trimmed = trimmed.substring(3);
    }
    if (trimmed.endsWith('```')) {
      trimmed = trimmed.substring(0, trimmed.length - 3);
    }
    trimmed = trimmed.trim();

    final firstBrace = trimmed.indexOf('{');
    final firstBracket = trimmed.indexOf('[');
    if (firstBrace != -1 && (firstBracket == -1 || firstBrace < firstBracket)) {
      final lastBrace = trimmed.lastIndexOf('}');
      if (lastBrace != -1 && lastBrace > firstBrace) {
        return trimmed.substring(firstBrace, lastBrace + 1);
      }
    } else if (firstBracket != -1) {
      final lastBracket = trimmed.lastIndexOf(']');
      if (lastBracket != -1 && lastBracket > firstBracket) {
        return trimmed.substring(firstBracket, lastBracket + 1);
      }
    }

    return trimmed;
  }

  @override
  Future<LessonPlanDocument> generateLessonPlan(
    LessonProjectData project, {
    String? customInstruction,
  }) async {
    final prompt = PromptTemplates.buildLessonPlanPrompt(
      project,
      customInstruction: customInstruction,
    );
    final rawMarkdown = await _generate(prompt, temperature: 0.4, maxTokens: 4096);

    return LessonPlanDocument.parseFromMarkdown(
      title: project.lessonTitle,
      subject: project.subject,
      grade: project.grade,
      duration: project.duration,
      bookSeries: project.bookSeries,
      markdown: rawMarkdown,
    );
  }

  @override
  Future<String> regenerateSection({
    required String sectionKey,
    required String currentContent,
    required LessonProjectData project,
  }) async {
    final prompt = PromptTemplates.buildSectionRegenerationPrompt(
      sectionKey: sectionKey,
      currentContent: currentContent,
      project: project,
    );
    return await _generate(prompt, temperature: 0.4, maxTokens: 2048);
  }

  @override
  Future<WorksheetModel> generateWorksheet({
    required LessonProjectData project,
    required WorksheetPreset preset,
    required int taskCount,
  }) async {
    final prompt = PromptTemplates.buildWorksheetPrompt(
      project: project,
      preset: preset,
      taskCount: taskCount,
    );

    final rawOutput = await _generate(prompt, temperature: 0.3, maxTokens: 3072);
    final jsonStr = extractJson(rawOutput);

    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        final tasksList = (decoded['tasks'] as List<dynamic>?)
                ?.map((e) => WorksheetTask.fromMap(e as Map<String, dynamic>))
                .toList() ??
            [];

        return WorksheetModel(
          id: 'ws_${DateTime.now().millisecondsSinceEpoch}',
          title: (decoded['title'] as String?) ?? 'Phiếu học tập: ${project.lessonTitle}',
          subject: project.subject,
          grade: project.grade,
          preset: preset,
          durationMinutes: (decoded['durationMinutes'] as num?)?.toInt() ?? 15,
          tasks: tasksList,
          teacherNotes: decoded['teacherNotes'] as String?,
        );
      }
      throw const FormatException('Kết quả trả về không phải là JSON Object hợp lệ.');
    } catch (e, st) {
      AppLogger.error('Lỗi phân tích cú pháp JSON Phiếu học tập từ iLocal AI: $e\nRaw: $rawOutput', e, st);
      throw FormatException('Không thể phân tích cú pháp Phiếu học tập từ iLocal AI: $e');
    }
  }

  @override
  Future<List<QuestionItem>> generateQuestions({
    required LessonProjectData project,
    required int count,
    QuestionDifficulty? difficulty,
    QuestionType? type,
  }) async {
    final prompt = PromptTemplates.buildQuestionsPrompt(
      project: project,
      count: count,
      difficulty: difficulty,
      type: type,
    );

    final rawOutput = await _generate(prompt, temperature: 0.3, maxTokens: 3072);
    try {
      final items = AiQuestionResponseParser.parse(rawOutput);
      return items.take(count).toList();
    } catch (e, st) {
      AppLogger.error('Lỗi phân tích cú pháp danh sách câu hỏi từ iLocal AI: $e\nRaw: $rawOutput', e, st);
      throw FormatException('Không thể phân tích danh sách câu hỏi từ iLocal AI: $e');
    }
  }

  @override
  Future<RubricModel> generateRubric({
    required LessonProjectData project,
    int levelCount = 4,
  }) async {
    final prompt = PromptTemplates.buildRubricPrompt(
      project: project,
      levelCount: levelCount,
    );

    final rawOutput = await _generate(prompt, temperature: 0.3, maxTokens: 3072);
    final jsonStr = extractJson(rawOutput);

    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        final criteriaList = (decoded['criteria'] as List<dynamic>?)
                ?.map((e) => RubricCriterion.fromMap(e as Map<String, dynamic>))
                .toList() ??
            [];

        return RubricModel(
          id: 'rub_${DateTime.now().millisecondsSinceEpoch}',
          projectId: '',
          title: (decoded['title'] as String?) ?? 'Rubric đánh giá bài: ${project.lessonTitle}',
          criteria: criteriaList,
        );
      }
      throw const FormatException('Kết quả trả về không phải là JSON Rubric hợp lệ.');
    } catch (e, st) {
      AppLogger.error('Lỗi phân tích cú pháp Rubric từ iLocal AI: $e\nRaw: $rawOutput', e, st);
      throw FormatException('Không thể phân tích Rubric từ iLocal AI: $e');
    }
  }

  @override
  Future<AiConnectionTestResult> testConnection() async {
    final sw = Stopwatch()..start();
    try {
      final res = await _client.health();
      sw.stop();
      if (res.isSuccess && res.value.isReady) {
        return AiConnectionTestResult(
          status: AiConnectionStatus.ok,
          provider: providerName,
          model: _model,
          message: 'Kết nối thành công tới iLocal AI Core (Offline GPU: ready)',
          latencyMs: sw.elapsedMilliseconds,
        );
      } else {
        final msg = res.isSuccess
            ? (res.value.message ?? 'iLocal AI Engine chưa sẵn sàng')
            : res.error.message;
        return AiConnectionTestResult(
          status: AiConnectionStatus.networkError,
          provider: providerName,
          model: _model,
          message: 'iLocal AI chưa sẵn sàng: $msg',
          latencyMs: sw.elapsedMilliseconds,
        );
      }
    } catch (e) {
      sw.stop();
      return AiConnectionTestResult(
        status: AiConnectionStatus.networkError,
        provider: providerName,
        model: _model,
        message: 'Không thể kết nối tới dịch vụ iLocal AI (127.0.0.1:18181): $e',
        latencyMs: sw.elapsedMilliseconds,
      );
    }
  }
}
