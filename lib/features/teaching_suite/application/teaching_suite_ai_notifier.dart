import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/logging/app_logger.dart';
import '../domain/models/lesson_plan_document.dart';
import '../domain/models/lesson_project_data.dart';
import '../domain/models/question_models.dart';
import '../domain/models/rubric_models.dart';
import '../domain/models/worksheet_models.dart';
import 'ai_text_generation_service.dart';

class TeachingSuiteAiState {
  final bool isGenerating;
  final String? activeOperation; // e.g., 'lessonPlan', 'worksheet', 'questions', 'rubric', 'section'
  final String? activeSectionKey;
  final String? errorMessage;
  final bool hasAcceptedCloudPrivacy;
  final AiConnectionTestResult? connectionStatus;
  final DateTime? lastGeneratedTime;

  bool get isGeneratingWorksheet => isGenerating && activeOperation == 'worksheet';
  bool get isGeneratingLessonPlan => isGenerating && activeOperation == 'lessonPlan';
  bool get isGeneratingQuestions => isGenerating && activeOperation == 'questions';
  bool get isGeneratingRubric => isGenerating && activeOperation == 'rubric';

  const TeachingSuiteAiState({
    this.isGenerating = false,
    this.activeOperation,
    this.activeSectionKey,
    this.errorMessage,
    this.hasAcceptedCloudPrivacy = false,
    this.connectionStatus,
    this.lastGeneratedTime,
  });

  TeachingSuiteAiState copyWith({
    bool? isGenerating,
    String? activeOperation,
    String? activeSectionKey,
    String? errorMessage,
    bool? hasAcceptedCloudPrivacy,
    AiConnectionTestResult? connectionStatus,
    DateTime? lastGeneratedTime,
  }) {
    return TeachingSuiteAiState(
      isGenerating: isGenerating ?? this.isGenerating,
      activeOperation: activeOperation ?? this.activeOperation,
      activeSectionKey: activeSectionKey ?? this.activeSectionKey,
      errorMessage: errorMessage,
      hasAcceptedCloudPrivacy: hasAcceptedCloudPrivacy ?? this.hasAcceptedCloudPrivacy,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      lastGeneratedTime: lastGeneratedTime ?? this.lastGeneratedTime,
    );
  }
}

class TeachingSuiteAiNotifier extends StateNotifier<TeachingSuiteAiState> {
  final AiTextGenerationService _aiService;

  TeachingSuiteAiNotifier(this._aiService) : super(const TeachingSuiteAiState()) {
    checkConnection();
  }

  void acceptCloudPrivacy() {
    state = state.copyWith(hasAcceptedCloudPrivacy: true);
  }

  Future<void> checkConnection() async {
    try {
      final res = await _aiService.testConnection();
      final isLocal = res.provider == 'ilocal';
      state = state.copyWith(
        connectionStatus: res,
        hasAcceptedCloudPrivacy: isLocal ? true : state.hasAcceptedCloudPrivacy,
      );
    } catch (e) {
      AppLogger.warning('AI connection probe error: $e');
    }
  }

  Future<LessonPlanDocument?> generateLessonPlan(LessonProjectData project, {String? customInstruction}) async {
    state = state.copyWith(isGenerating: true, activeOperation: 'lessonPlan', errorMessage: null);
    try {
      final plan = await _aiService.generateLessonPlan(project, customInstruction: customInstruction);
      state = state.copyWith(isGenerating: false, activeOperation: null, lastGeneratedTime: DateTime.now());
      return plan;
    } catch (e, st) {
      AppLogger.error('Lỗi sinh giáo án AI: $e', e, st);
      state = state.copyWith(isGenerating: false, activeOperation: null, errorMessage: 'Lỗi tạo giáo án: $e');
      return null;
    }
  }

  Future<String?> regenerateSection({
    required String sectionKey,
    required String currentContent,
    required LessonProjectData project,
  }) async {
    state = state.copyWith(
      isGenerating: true,
      activeOperation: 'section',
      activeSectionKey: sectionKey,
      errorMessage: null,
    );
    try {
      final newContent = await _aiService.regenerateSection(
        sectionKey: sectionKey,
        currentContent: currentContent,
        project: project,
      );
      state = state.copyWith(
        isGenerating: false,
        activeOperation: null,
        activeSectionKey: null,
        lastGeneratedTime: DateTime.now(),
      );
      return newContent;
    } catch (e, st) {
      AppLogger.error('Lỗi viết lại mục $sectionKey: $e', e, st);
      state = state.copyWith(
        isGenerating: false,
        activeOperation: null,
        activeSectionKey: null,
        errorMessage: 'Lỗi viết lại mục: $e',
      );
      return null;
    }
  }

  Future<WorksheetModel?> generateWorksheet({
    required LessonProjectData project,
    required WorksheetPreset preset,
    required int taskCount,
  }) async {
    state = state.copyWith(isGenerating: true, activeOperation: 'worksheet', errorMessage: null);
    try {
      final ws = await _aiService.generateWorksheet(
        project: project,
        preset: preset,
        taskCount: taskCount,
      );
      state = state.copyWith(isGenerating: false, activeOperation: null, lastGeneratedTime: DateTime.now());
      return ws;
    } catch (e, st) {
      AppLogger.error('Lỗi tạo phiếu học tập AI: $e', e, st);
      state = state.copyWith(isGenerating: false, activeOperation: null, errorMessage: 'Lỗi tạo phiếu học tập: $e');
      return null;
    }
  }

  Future<List<QuestionItem>?> generateQuestions({
    required LessonProjectData project,
    required int count,
    QuestionDifficulty? difficulty,
    QuestionType? type,
  }) async {
    state = state.copyWith(isGenerating: true, activeOperation: 'questions', errorMessage: null);
    try {
      final items = await _aiService.generateQuestions(
        project: project,
        count: count,
        difficulty: difficulty,
        type: type,
      );
      state = state.copyWith(isGenerating: false, activeOperation: null, lastGeneratedTime: DateTime.now());
      return items;
    } catch (e, st) {
      AppLogger.error('Lỗi sinh câu hỏi AI: $e', e, st);
      state = state.copyWith(isGenerating: false, activeOperation: null, errorMessage: 'Lỗi sinh câu hỏi: $e');
      return null;
    }
  }

  Future<RubricModel?> generateRubric({
    required LessonProjectData project,
    int levelCount = 4,
  }) async {
    state = state.copyWith(isGenerating: true, activeOperation: 'rubric', errorMessage: null);
    try {
      final rubric = await _aiService.generateRubric(
        project: project,
        levelCount: levelCount,
      );
      state = state.copyWith(isGenerating: false, activeOperation: null, lastGeneratedTime: DateTime.now());
      return rubric;
    } catch (e, st) {
      AppLogger.error('Lỗi tạo rubric AI: $e', e, st);
      state = state.copyWith(isGenerating: false, activeOperation: null, errorMessage: 'Lỗi tạo Rubric: $e');
      return null;
    }
  }
}
