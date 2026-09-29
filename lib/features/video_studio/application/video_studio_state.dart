import '../domain/models/video_project.dart';
import '../domain/models/video_scene.dart';
import 'video_render_service.dart';

/// State of the Video Studio desktop workspace.
class VideoStudioState {
  final VideoProject currentProject;
  final int selectedSceneIndex;
  final bool isRendering;
  final double renderProgress;
  final String renderStage;
  final VideoRenderResult? lastRenderResult;
  final bool isSimpleMode;
  final List<VideoProject> recentProjects;
  final String? errorMessage;

  const VideoStudioState({
    required this.currentProject,
    this.selectedSceneIndex = 0,
    this.isRendering = false,
    this.renderProgress = 0.0,
    this.renderStage = '',
    this.lastRenderResult,
    this.isSimpleMode = true,
    this.recentProjects = const [],
    this.errorMessage,
  });

  VideoScene? get selectedScene {
    if (selectedSceneIndex >= 0 && selectedSceneIndex < currentProject.scenes.length) {
      return currentProject.scenes[selectedSceneIndex];
    }
    return null;
  }

  VideoStudioState copyWith({
    VideoProject? currentProject,
    int? selectedSceneIndex,
    bool? isRendering,
    double? renderProgress,
    String? renderStage,
    VideoRenderResult? lastRenderResult,
    bool? isSimpleMode,
    List<VideoProject>? recentProjects,
    String? errorMessage,
  }) =>
      VideoStudioState(
        currentProject: currentProject ?? this.currentProject,
        selectedSceneIndex: selectedSceneIndex ?? this.selectedSceneIndex,
        isRendering: isRendering ?? this.isRendering,
        renderProgress: renderProgress ?? this.renderProgress,
        renderStage: renderStage ?? this.renderStage,
        lastRenderResult: lastRenderResult ?? this.lastRenderResult,
        isSimpleMode: isSimpleMode ?? this.isSimpleMode,
        recentProjects: recentProjects ?? this.recentProjects,
        errorMessage: errorMessage,
      );
}
