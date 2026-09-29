import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../core/ai/gemini_service.dart';
import '../../../core/ai/google_auth_service.dart';
import '../../../core/filesystem/workspace_manager.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/providers/app_providers.dart';
import '../domain/lesson_plan_models.dart';
import '../infrastructure/lesson_plan_docx_exporter.dart';

class LessonPlannerState {
  final bool isConnected;
  final GoogleUserProfile? userProfile;
  final bool isGenerating;
  final bool isExporting;
  final String? generatedPlan;
  final String? exportedFilePath;
  final String? errorMessage;
  final LessonPlanRequest? lastRequest;

  const LessonPlannerState({
    this.isConnected = false,
    this.userProfile,
    this.isGenerating = false,
    this.isExporting = false,
    this.generatedPlan,
    this.exportedFilePath,
    this.errorMessage,
    this.lastRequest,
  });

  LessonPlannerState copyWith({
    bool? isConnected,
    GoogleUserProfile? userProfile,
    bool? isGenerating,
    bool? isExporting,
    String? generatedPlan,
    String? exportedFilePath,
    String? errorMessage,
    LessonPlanRequest? lastRequest,
  }) {
    return LessonPlannerState(
      isConnected: isConnected ?? this.isConnected,
      userProfile: userProfile ?? this.userProfile,
      isGenerating: isGenerating ?? this.isGenerating,
      isExporting: isExporting ?? this.isExporting,
      generatedPlan: generatedPlan ?? this.generatedPlan,
      exportedFilePath: exportedFilePath ?? this.exportedFilePath,
      errorMessage: errorMessage ?? this.errorMessage,
      lastRequest: lastRequest ?? this.lastRequest,
    );
  }
}

class LessonPlannerNotifier extends StateNotifier<LessonPlannerState> {
  final GoogleAuthService _authService;
  final WorkspaceManager _workspaceManager;

  LessonPlannerNotifier(this._authService, this._workspaceManager)
      : super(const LessonPlannerState()) {
    checkConnection();
  }

  Future<void> checkConnection() async {
    final isAuthed = await _authService.isAuthenticated();
    if (isAuthed) {
      final profile = await _authService.getUserProfile();
      state = state.copyWith(isConnected: true, userProfile: profile);
    } else {
      state = state.copyWith(isConnected: false, userProfile: null);
    }
  }

  Future<void> connectWithGoogleKey(String apiKey, {String? email, String? name}) async {
    try {
      await _authService.saveCredentials(apiKey: apiKey, email: email, displayName: name);
      final profile = await _authService.getUserProfile();
      state = state.copyWith(
        isConnected: true,
        userProfile: profile,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'Lỗi kết nối Google Gemini: $e');
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    state = state.copyWith(
      isConnected: false,
      userProfile: null,
      generatedPlan: null,
      exportedFilePath: null,
    );
  }

  Future<void> generateLessonPlan(LessonPlanRequest request) async {
    final apiKey = await _authService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Vui lòng kết nối Google Gemini AI trước khi bắt đầu soạn giáo án.',
      );
      return;
    }

    state = state.copyWith(
      isGenerating: true,
      errorMessage: null,
      generatedPlan: null,
      exportedFilePath: null,
      lastRequest: request,
    );

    try {
      final gemini = GeminiService(apiKey: apiKey);
      final content = await gemini.generate5512LessonPlan(
        subject: request.subject,
        grade: request.grade,
        bookSeries: request.bookSeries,
        lessonTitle: request.lessonTitle,
        duration: request.duration,
        requirements: request.customRequirements,
        sourceMaterial: request.referenceText,
      );

      state = state.copyWith(
        isGenerating: false,
        generatedPlan: content,
      );
      AppLogger.info('Successfully generated 5512 lesson plan for: ${request.lessonTitle}');
    } catch (e, st) {
      AppLogger.error('Lesson plan generation failed: $e', e, st);
      state = state.copyWith(
        isGenerating: false,
        errorMessage: 'Lỗi khi soạn giáo án: $e',
      );
    }
  }

  Future<String?> exportToWord() async {
    final content = state.generatedPlan;
    final req = state.lastRequest;
    if (content == null || content.isEmpty || req == null) return null;

    state = state.copyWith(isExporting: true, errorMessage: null);

    try {
      final safeTitle = req.lessonTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final filename = 'GiaoAn_5512_${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.docx';
      final outputPath = p.join(_workspaceManager.exportsDir.path, filename);

      await LessonPlanDocxExporter.export(
        title: req.lessonTitle,
        subject: req.subject,
        grade: req.grade,
        content: content,
        outputPath: outputPath,
      );

      state = state.copyWith(
        isExporting: false,
        exportedFilePath: outputPath,
      );
      return outputPath;
    } catch (e, st) {
      AppLogger.error('DOCX export error: $e', e, st);
      state = state.copyWith(
        isExporting: false,
        errorMessage: 'Lỗi khi xuất tệp Word: $e',
      );
      return null;
    }
  }
}

/// Provider for GoogleAuthService
final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return GoogleAuthService(storage);
});

/// Riverpod provider for LessonPlannerNotifier
final lessonPlannerNotifierProvider =
    StateNotifierProvider<LessonPlannerNotifier, LessonPlannerState>((ref) {
  final auth = ref.watch(googleAuthServiceProvider);
  final ws = ref.watch(workspaceManagerProvider);
  return LessonPlannerNotifier(auth, ws);
});
