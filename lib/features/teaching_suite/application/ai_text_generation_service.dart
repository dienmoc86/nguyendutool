import '../domain/models/lesson_plan_document.dart';
import '../domain/models/lesson_project_data.dart';
import '../domain/models/question_models.dart';
import '../domain/models/rubric_models.dart';
import '../domain/models/worksheet_models.dart';

/// Connection test status for AI services
enum AiConnectionStatus {
  notConfigured('Chưa cấu hình API Key'),
  ok('Kết nối thành công (OK)'),
  authFailed('Xác thực thất bại (Sai API Key)'),
  networkError('Lỗi kết nối mạng'),
  quotaExceeded('Vượt quá hạn mức / Quota Exceeded'),
  error('Lỗi không xác định');

  final String label;
  const AiConnectionStatus(this.label);
}

/// Detailed result of an AI connection probe
class AiConnectionTestResult {
  final AiConnectionStatus status;
  final String provider;
  final String model;
  final String message;
  final int? latencyMs;

  const AiConnectionTestResult({
    required this.status,
    required this.provider,
    required this.model,
    required this.message,
    this.latencyMs,
  });

  bool get isSuccessful => status == AiConnectionStatus.ok;
}

/// Abstract contract for AI text generation services in Teaching Suite.
abstract class AiTextGenerationService {
  String get providerName;
  String get currentModel;

  /// Generates a comprehensive CV 5512 lesson plan.
  Future<LessonPlanDocument> generateLessonPlan(
    LessonProjectData project, {
    String? customInstruction,
  });

  /// Regenerates a specific section (e.g., objectives, activity, rubric) without rewriting the entire plan.
  Future<String> regenerateSection({
    required String sectionKey,
    required String currentContent,
    required LessonProjectData project,
  });

  /// Generates a structured student worksheet with chosen preset and task count.
  Future<WorksheetModel> generateWorksheet({
    required LessonProjectData project,
    required WorksheetPreset preset,
    required int taskCount,
  });

  /// Generates a structured list of QuestionItem records (MCQ, True/False, Short Answer, Essay).
  Future<List<QuestionItem>> generateQuestions({
    required LessonProjectData project,
    required int count,
    QuestionDifficulty? difficulty,
    QuestionType? type,
  });

  /// Generates an evaluation rubric with criteria, weights, and performance levels.
  Future<RubricModel> generateRubric({
    required LessonProjectData project,
    int levelCount = 4,
  });

  /// Performs a lightweight connection test without generating expensive content.
  Future<AiConnectionTestResult> testConnection();
}
