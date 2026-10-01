import 'dart:convert';
import 'dart:io';
import '../../../core/ai/ai_model_config.dart';
import '../../../core/ai/gemini_service.dart';
import '../../../core/logging/app_logger.dart';
import '../application/ai_text_generation_service.dart';
import '../domain/models/lesson_plan_document.dart';
import '../domain/models/lesson_project_data.dart';
import '../domain/models/question_models.dart';
import '../domain/models/rubric_models.dart';
import '../domain/models/worksheet_models.dart';
import '../domain/ai_question_response_parser.dart';
import 'prompt_templates.dart';

/// Production implementation of AiTextGenerationService using Google Gemini.
class GeminiAiTextGenerationService implements AiTextGenerationService {
  final Future<String?> Function() _apiKeyGetter;
  final String _model;

  GeminiAiTextGenerationService({
    required Future<String?> Function() apiKeyGetter,
    String? model,
  })  : _apiKeyGetter = apiKeyGetter,
        _model = model ?? AiModelConfig.defaultModel;

  @override
  String get providerName => 'gemini';

  @override
  String get currentModel => _model;

  Future<GeminiService> _getGeminiService() async {
    final apiKey = await _apiKeyGetter();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const FormatException('Chưa cấu hình API Key cho Google Gemini.');
    }
    return GeminiService(apiKey: apiKey.trim(), model: _model);
  }

  /// Extracts pure JSON string from AI response even if wrapped in ```json ... ``` or has surrounding text.
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

    // In case there is text before the first [ or {
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
    final gemini = await _getGeminiService();
    final prompt = PromptTemplates.buildLessonPlanPrompt(project, customInstruction: customInstruction);
    final rawMarkdown = await gemini.generateText(prompt, temperature: 0.7);

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
    final gemini = await _getGeminiService();
    final prompt = PromptTemplates.buildSectionRegenerationPrompt(
      sectionKey: sectionKey,
      currentContent: currentContent,
      project: project,
    );
    return await gemini.generateText(prompt, temperature: 0.7);
  }

  @override
  Future<WorksheetModel> generateWorksheet({
    required LessonProjectData project,
    required WorksheetPreset preset,
    required int taskCount,
  }) async {
    final gemini = await _getGeminiService();
    final prompt = PromptTemplates.buildWorksheetPrompt(
      project: project,
      preset: preset,
      taskCount: taskCount,
    );

    final rawOutput = await gemini.generateText(prompt, temperature: 0.4);
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
      AppLogger.error('Lỗi phân tích cú pháp JSON Phiếu học tập: $e\nRaw: $rawOutput', e, st);
      throw FormatException('Không thể phân tích cú pháp Phiếu học tập từ phản hồi AI: $e');
    }
  }

  @override
  Future<List<QuestionItem>> generateQuestions({
    required LessonProjectData project,
    required int count,
    QuestionDifficulty? difficulty,
    QuestionType? type,
  }) async {
    final gemini = await _getGeminiService();
    final prompt = PromptTemplates.buildQuestionsPrompt(
      project: project,
      count: count,
      difficulty: difficulty,
      type: type,
    );

    final rawOutput = await gemini.generateText(prompt, temperature: 0.3);
    try {
      final items = AiQuestionResponseParser.parse(rawOutput);
      return items.take(count).toList();
    } catch (e, st) {
      AppLogger.error('Lỗi phân tích cú pháp nghiêm ngặt danh sách câu hỏi AI: $e\nRaw: $rawOutput', e, st);
      throw FormatException('Không thể phân tích danh sách câu hỏi từ phản hồi AI: $e');
    }
  }

  @override
  Future<RubricModel> generateRubric({
    required LessonProjectData project,
    int levelCount = 4,
  }) async {
    final gemini = await _getGeminiService();
    final prompt = PromptTemplates.buildRubricPrompt(
      project: project,
      levelCount: levelCount,
    );

    final rawOutput = await gemini.generateText(prompt, temperature: 0.4);
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
      AppLogger.error('Lỗi phân tích cú pháp Rubric: $e\nRaw: $rawOutput', e, st);
      throw FormatException('Không thể phân tích Rubric từ phản hồi AI: $e');
    }
  }

  @override
  Future<AiConnectionTestResult> testConnection() async {
    final apiKey = await _apiKeyGetter();
    if (apiKey == null || apiKey.trim().isEmpty) {
      return const AiConnectionTestResult(
        status: AiConnectionStatus.notConfigured,
        provider: 'gemini',
        model: AiModelConfig.defaultModel,
        message: 'Chưa cấu hình API Key trong Cài đặt.',
      );
    }

    final stopwatch = Stopwatch()..start();
    try {
      final cleanKey = apiKey.trim();
      final endpoint = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$cleanKey',
      );

      final payload = {
        'contents': [
          {
            'parts': [
              {'text': 'Ping'}
            ]
          }
        ],
        'generationConfig': {
          'maxOutputTokens': 5,
        },
      };

      final client = HttpClient();
      final request = await client.postUrl(endpoint).timeout(const Duration(seconds: 12));
      request.headers.set('Content-Type', 'application/json; charset=UTF-8');
      request.add(utf8.encode(jsonEncode(payload)));

      final response = await request.close().timeout(const Duration(seconds: 12));
      stopwatch.stop();

      if (response.statusCode == 200) {
        return AiConnectionTestResult(
          status: AiConnectionStatus.ok,
          provider: 'gemini',
          model: _model,
          message: 'Kết nối máy chủ Google Gemini thành công.',
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      }

      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode == 400 || response.statusCode == 403) {
        return AiConnectionTestResult(
          status: AiConnectionStatus.authFailed,
          provider: 'gemini',
          model: _model,
          message: 'API Key không hợp lệ hoặc không có quyền truy cập mô hình này.',
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      } else if (response.statusCode == 429) {
        return AiConnectionTestResult(
          status: AiConnectionStatus.quotaExceeded,
          provider: 'gemini',
          model: _model,
          message: 'Hạn mức gọi API Google Gemini đã hết hoặc bị giới hạn tần suất.',
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      }

      return AiConnectionTestResult(
        status: AiConnectionStatus.error,
        provider: 'gemini',
        model: _model,
        message: 'Máy chủ phản hồi mã lỗi HTTP ${response.statusCode}: $body',
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    } on SocketException catch (e) {
      stopwatch.stop();
      return AiConnectionTestResult(
        status: AiConnectionStatus.networkError,
        provider: 'gemini',
        model: _model,
        message: 'Không thể kết nối mạng tới Google Gemini: ${e.message}',
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return AiConnectionTestResult(
        status: AiConnectionStatus.error,
        provider: 'gemini',
        model: _model,
        message: 'Lỗi kiểm tra kết nối: $e',
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    }
  }
}
