import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/projects/data/workspace_project_repository.dart';
import '../../../core/projects/domain/project_artifact.dart';
import '../../../core/projects/domain/project_type.dart';
import '../../../core/projects/domain/workspace_project.dart';
import '../data/teaching_suite_repository.dart';
import '../domain/models/lesson_plan_document.dart';
import '../domain/models/lesson_project_data.dart';

class TeachingSuiteProjectState {
  final WorkspaceProject? activeProject;
  final LessonProjectData projectData;
  final LessonPlanDocument? lessonPlan;
  final List<ProjectArtifact> artifacts;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  const TeachingSuiteProjectState({
    this.activeProject,
    this.projectData = const LessonProjectData(),
    this.lessonPlan,
    this.artifacts = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
  });

  TeachingSuiteProjectState copyWith({
    WorkspaceProject? activeProject,
    LessonProjectData? projectData,
    LessonPlanDocument? lessonPlan,
    List<ProjectArtifact>? artifacts,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearLessonPlan = false,
  }) {
    return TeachingSuiteProjectState(
      activeProject: activeProject ?? this.activeProject,
      projectData: projectData ?? this.projectData,
      lessonPlan: clearLessonPlan ? null : (lessonPlan ?? this.lessonPlan),
      artifacts: artifacts ?? this.artifacts,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class TeachingSuiteProjectNotifier extends StateNotifier<TeachingSuiteProjectState> {
  final WorkspaceProjectRepository _projectRepo;
  final TeachingSuiteRepository _teachingRepo;
  static const _uuid = Uuid();
  Timer? _debounceSaveTimer;
  Timer? _debounceLessonPlanTimer;

  TeachingSuiteProjectNotifier(this._projectRepo, this._teachingRepo)
      : super(const TeachingSuiteProjectState()) {
    initDefaultProject();
  }

  @override
  void dispose() {
    _debounceSaveTimer?.cancel();
    _debounceLessonPlanTimer?.cancel();
    super.dispose();
  }

  /// Initializes by loading the most recently updated lesson project or creating one.
  Future<void> initDefaultProject() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final lessonProjects = await _projectRepo.listProjects(type: ProjectType.lesson);
      if (!mounted) return;
      if (lessonProjects.isNotEmpty) {
        await selectProject(lessonProjects.first.id);
      } else {
        await createNewProject(
          title: 'Bài học mới (GDPT 2018)',
          subject: 'Ngữ văn',
          grade: '9',
        );
      }
    } catch (e, st) {
      if (!mounted) return;
      AppLogger.error('Lỗi khởi tạo dự án bài học: $e', e, st);
      state = state.copyWith(isLoading: false, errorMessage: 'Không thể tải dự án: $e');
    }
  }

  /// Selects and loads a project by ID with full persistence hydration.
  Future<void> selectProject(String projectId) async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final project = await _projectRepo.getProject(projectId);
      if (!mounted) return;
      if (project == null) {
        state = state.copyWith(isLoading: false, errorMessage: 'Không tìm thấy dự án $projectId');
        return;
      }

      LessonProjectData data = const LessonProjectData();
      if (project.metadataJson != null && project.metadataJson!.isNotEmpty) {
        data = LessonProjectData.fromJson(project.metadataJson!);
      }

      // Restore persisted LessonPlanDocument draft from SQLite table lesson_plan_drafts
      final plan = await _teachingRepo.getLessonPlanDraft(projectId);

      final artifacts = await _projectRepo.listArtifacts(projectId);
      if (!mounted) return;

      state = state.copyWith(
        activeProject: project,
        projectData: data,
        lessonPlan: plan,
        artifacts: artifacts,
        isLoading: false,
      );
      AppLogger.info('Loaded teaching project with persisted draft: ${project.name} (${project.id})');
    } catch (e, st) {
      if (!mounted) return;
      AppLogger.error('Lỗi khi mở dự án $projectId: $e', e, st);
      state = state.copyWith(isLoading: false, errorMessage: 'Lỗi tải dự án: $e');
    }
  }

  /// Creates a new lesson project.
  Future<WorkspaceProject> createNewProject({
    required String title,
    String subject = 'Ngữ văn',
    String grade = '9',
    String bookSeries = 'Kết nối tri thức với cuộc sống',
    String duration = '2 tiết (90 phút)',
  }) async {
    final projId = 'lesson_${_uuid.v4()}';
    final initialData = LessonProjectData(
      subject: subject,
      grade: grade,
      bookSeries: bookSeries,
      lessonTitle: title,
      duration: duration,
    );

    final project = WorkspaceProject(
      id: projId,
      name: title,
      type: ProjectType.lesson,
      metadataJson: initialData.toJson(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _projectRepo.createProject(project);
    if (!mounted) return project;

    state = state.copyWith(
      activeProject: project,
      projectData: initialData,
      clearLessonPlan: true,
      artifacts: const [],
      isLoading: false,
    );
    AppLogger.info('Created new lesson project: $title ($projId)');
    return project;
  }

  /// Updates project data with debounced auto-save.
  void updateProjectData(LessonProjectData newData) {
    if (!mounted) return;
    state = state.copyWith(projectData: newData);

    _debounceSaveTimer?.cancel();
    _debounceSaveTimer = Timer(const Duration(milliseconds: 600), () {
      saveActiveProject();
    });
  }

  /// Updates and immediately persists LessonPlanDocument to lesson_plan_drafts.
  Future<void> setLessonPlan(LessonPlanDocument plan) async {
    if (!mounted) return;
    state = state.copyWith(lessonPlan: plan);
    final current = state.activeProject;
    if (current != null) {
      await _teachingRepo.saveLessonPlanDraft(current.id, plan);
    }
    await saveActiveProject();
  }

  /// Updates lesson plan content from manual text edits with debounced persistence.
  void updateLessonPlanContent(String rawContent) {
    if (!mounted) return;
    final updatedPlan = LessonPlanDocument.parseFromMarkdown(
      title: state.projectData.lessonTitle,
      subject: state.projectData.subject,
      grade: state.projectData.grade,
      duration: state.projectData.duration,
      bookSeries: state.projectData.bookSeries,
      markdown: rawContent,
    );
    state = state.copyWith(lessonPlan: updatedPlan);

    _debounceLessonPlanTimer?.cancel();
    _debounceLessonPlanTimer = Timer(const Duration(milliseconds: 600), () async {
      final current = state.activeProject;
      if (current != null) {
        await _teachingRepo.saveLessonPlanDraft(current.id, updatedPlan);
      }
    });
  }

  /// Persists current project metadata to SQLite database.
  Future<void> saveActiveProject() async {
    if (!mounted) return;
    final current = state.activeProject;
    if (current == null) return;

    state = state.copyWith(isSaving: true);
    try {
      final updated = current.copyWith(
        name: state.projectData.lessonTitle.isNotEmpty ? state.projectData.lessonTitle : current.name,
        metadataJson: state.projectData.toJson(),
        updatedAt: DateTime.now(),
      );

      await _projectRepo.updateProject(updated);
      if (!mounted) return;
      state = state.copyWith(activeProject: updated, isSaving: false);
      AppLogger.info('Auto-saved lesson project: ${updated.id}');
    } catch (e, st) {
      if (!mounted) return;
      AppLogger.error('Lỗi lưu dự án bài học: $e', e, st);
      state = state.copyWith(isSaving: false, errorMessage: 'Không thể lưu dự án: $e');
    }
  }

  /// Duplicates current lesson project including its lesson plan draft.
  Future<WorkspaceProject?> duplicateProject() async {
    if (!mounted) return null;
    final current = state.activeProject;
    if (current == null) return null;

    final newId = 'lesson_${_uuid.v4()}';
    final duplicated = WorkspaceProject(
      id: newId,
      name: '${current.name} (Bản sao)',
      type: ProjectType.lesson,
      metadataJson: current.metadataJson,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _projectRepo.createProject(duplicated);
    if (!mounted) return duplicated;

    // Duplicate lesson plan draft if exists
    if (state.lessonPlan != null) {
      await _teachingRepo.saveLessonPlanDraft(newId, state.lessonPlan!);
    }

    await selectProject(newId);
    AppLogger.info('Duplicated project ${current.id} -> $newId');
    return duplicated;
  }

  /// Removes an artifact record from the project database.
  Future<void> removeArtifact(String artifactId) async {
    if (!mounted) return;
    final current = state.activeProject;
    if (current == null) return;

    await _projectRepo.deleteArtifact(artifactId);
    await refreshArtifacts();
    AppLogger.info('Removed artifact $artifactId from project ${current.id}');
  }

  /// Refreshes artifacts list from database.
  Future<void> refreshArtifacts() async {
    if (!mounted) return;
    final current = state.activeProject;
    if (current == null) return;
    final arts = await _projectRepo.listArtifacts(current.id);
    if (!mounted) return;
    state = state.copyWith(artifacts: arts);
  }
}
