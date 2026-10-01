import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/projects/data/workspace_project_repository.dart';
import '../../../core/projects/domain/project_artifact.dart';
import '../../../core/providers/app_providers.dart';
import '../data/assessment_repository.dart';
import '../domain/models/assessment_project_data.dart';

class AssessmentProjectState {
  final AssessmentProjectData? activeProject;
  final List<ProjectArtifact> artifacts;
  final bool isLoading;
  final String? errorMessage;

  const AssessmentProjectState({
    this.activeProject,
    this.artifacts = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  AssessmentProjectState copyWith({
    AssessmentProjectData? activeProject,
    bool clearActiveProject = false,
    List<ProjectArtifact>? artifacts,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AssessmentProjectState(
      activeProject: clearActiveProject ? null : (activeProject ?? this.activeProject),
      artifacts: artifacts ?? this.artifacts,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AssessmentProjectNotifier extends StateNotifier<AssessmentProjectState> {
  final AssessmentRepository _repository;
  final WorkspaceProjectRepository _projectRepo;

  AssessmentProjectNotifier(this._repository, this._projectRepo)
      : super(const AssessmentProjectState());

  /// Creates a new assessment project.
  Future<AssessmentProjectData> createProject({
    required String name,
    required String subject,
    required String grade,
    required ExamType examType,
    int durationMinutes = 45,
    double totalScore = 10.0,
    String schoolYear = '2026 - 2027',
    String semester = 'Học kỳ I',
    String? lessonProjectId,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final id = 'as_proj_${DateTime.now().millisecondsSinceEpoch}';
    final header = ExamHeaderConfig(
      subject: subject,
      grade: grade,
      durationMinutes: durationMinutes,
      schoolYear: schoolYear,
      semester: semester,
    );

    final project = AssessmentProjectData(
      id: id,
      name: name,
      subject: subject,
      grade: grade,
      examType: examType,
      durationMinutes: durationMinutes,
      totalScore: totalScore,
      schoolYear: schoolYear,
      semester: semester,
      lessonProjectId: lessonProjectId,
      headerConfig: header,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await _repository.saveProjectData(project);
      state = state.copyWith(activeProject: project, artifacts: [], isLoading: false);
      AppLogger.info('Created Assessment Project: $id ($name)');
      return project;
    } catch (e, st) {
      AppLogger.error('Failed to create assessment project', e, st);
      state = state.copyWith(isLoading: false, errorMessage: 'Lỗi tạo dự án: $e');
      rethrow;
    }
  }

  /// Selects an assessment project and ensures full state isolation (Section 92).
  Future<void> selectProject(String projectId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final project = await _repository.getProjectData(projectId);
      if (project == null) {
        state = state.copyWith(isLoading: false, errorMessage: 'Không tìm thấy dự án: $projectId');
        return;
      }

      final artifacts = await _projectRepo.listArtifacts(projectId);
      state = state.copyWith(activeProject: project, artifacts: artifacts, isLoading: false);
      AppLogger.info('Selected Assessment Project: $projectId');
    } catch (e, st) {
      AppLogger.error('Failed to select assessment project', e, st);
      state = state.copyWith(isLoading: false, errorMessage: 'Lỗi tải dự án: $e');
    }
  }

  /// Updates active project data and persists changes.
  Future<void> updateProject(AssessmentProjectData updated) async {
    try {
      await _repository.saveProjectData(updated);
      state = state.copyWith(activeProject: updated);
    } catch (e) {
      AppLogger.error('Failed to update project: $e');
      state = state.copyWith(errorMessage: 'Lỗi cập nhật dự án: $e');
    }
  }

  /// Refreshes artifacts list for active project.
  Future<void> refreshArtifacts() async {
    if (state.activeProject == null) return;
    try {
      final arts = await _projectRepo.listArtifacts(state.activeProject!.id);
      state = state.copyWith(artifacts: arts);
    } catch (e) {
      AppLogger.warning('Failed to refresh artifacts: $e');
    }
  }

  /// Removes an artifact from project and optionally deletes physical file.
  Future<void> removeArtifact(ProjectArtifact artifact, {bool deletePhysicalFile = false}) async {
    try {
      await _projectRepo.removeArtifact(artifact.id);
      if (deletePhysicalFile && artifact.filePath != null) {
        final f = File(artifact.filePath!);
        if (f.existsSync()) {
          try {
            f.deleteSync();
          } catch (_) {}
        }
      }
      await refreshArtifacts();
    } catch (e) {
      AppLogger.error('Failed to remove artifact: $e');
    }
  }

  void reset() {
    state = const AssessmentProjectState();
  }
}

final assessmentRepositoryProvider = Provider<AssessmentRepository>((ref) {
  final appDb = ref.watch(databaseProvider);
  return AssessmentRepository(appDb);
});

final assessmentProjectNotifierProvider =
    StateNotifierProvider<AssessmentProjectNotifier, AssessmentProjectState>((ref) {
  final repo = ref.watch(assessmentRepositoryProvider);
  final projRepo = ref.watch(workspaceProjectRepositoryProvider);
  return AssessmentProjectNotifier(repo, projRepo);
});
