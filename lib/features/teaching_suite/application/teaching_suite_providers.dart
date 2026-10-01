import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ai/ai_model_config.dart';
import '../../../core/ai/google_auth_service.dart';
import '../../../core/providers/app_providers.dart';
import '../data/teaching_suite_repository.dart';
import '../infrastructure/gemini_ai_text_generation_service.dart';
import '../infrastructure/ilocal_ai_text_generation_service.dart';
import 'ai_text_generation_service.dart';
import 'teaching_suite_ai_notifier.dart';
import 'teaching_suite_project_notifier.dart';
import 'teaching_suite_questions_notifier.dart';
import 'teaching_suite_rubric_notifier.dart';
import 'teaching_suite_worksheet_notifier.dart';

/// Provider for SQLite TeachingSuiteRepository.
final teachingSuiteRepositoryProvider = Provider<TeachingSuiteRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return TeachingSuiteRepository(db);
});

/// Provider for active AI Configuration state.
final teachingSuiteAiConfigProvider = StateProvider<AiModelConfig>((ref) {
  return const AiModelConfig();
});

/// Provider for AiTextGenerationService.
/// Defaults to ILocalAiTextGenerationService (100% offline, GPU accelerated, zero API key needed).
/// Seamlessly falls back to or uses GeminiAiTextGenerationService if configured.
final aiTextGenerationServiceProvider = Provider<AiTextGenerationService>((ref) {
  final config = ref.watch(teachingSuiteAiConfigProvider);
  final storage = ref.watch(secureStorageProvider);
  final authService = GoogleAuthService(storage);

  if (config.provider == AiModelConfig.providerGemini) {
    return GeminiAiTextGenerationService(
      apiKeyGetter: () => authService.getApiKey(),
      model: config.model,
    );
  }

  return ILocalAiTextGenerationService(
    model: config.model,
    port: 18181,
  );
});

/// Riverpod notifier provider for Project state.
final teachingSuiteProjectNotifierProvider =
    StateNotifierProvider<TeachingSuiteProjectNotifier, TeachingSuiteProjectState>((ref) {
  final projectRepo = ref.watch(workspaceProjectRepositoryProvider);
  final teachingRepo = ref.watch(teachingSuiteRepositoryProvider);
  return TeachingSuiteProjectNotifier(projectRepo, teachingRepo);
});

/// Riverpod notifier provider for AI generation & privacy state.
final teachingSuiteAiNotifierProvider =
    StateNotifierProvider<TeachingSuiteAiNotifier, TeachingSuiteAiState>((ref) {
  final aiService = ref.watch(aiTextGenerationServiceProvider);
  return TeachingSuiteAiNotifier(aiService);
});

/// Riverpod notifier provider for Student Worksheet.
final teachingSuiteWorksheetNotifierProvider =
    StateNotifierProvider<TeachingSuiteWorksheetNotifier, TeachingSuiteWorksheetState>((ref) {
  final repo = ref.watch(teachingSuiteRepositoryProvider);
  return TeachingSuiteWorksheetNotifier(repo);
});

/// Riverpod notifier provider for Question Bank & Mini Assessment.
final teachingSuiteQuestionsNotifierProvider =
    StateNotifierProvider<TeachingSuiteQuestionsNotifier, TeachingSuiteQuestionsState>((ref) {
  final repo = ref.watch(teachingSuiteRepositoryProvider);
  return TeachingSuiteQuestionsNotifier(repo);
});

/// Riverpod notifier provider for Evaluation Rubrics.
final teachingSuiteRubricNotifierProvider =
    StateNotifierProvider<TeachingSuiteRubricNotifier, TeachingSuiteRubricState>((ref) {
  final repo = ref.watch(teachingSuiteRepositoryProvider);
  return TeachingSuiteRubricNotifier(repo);
});
