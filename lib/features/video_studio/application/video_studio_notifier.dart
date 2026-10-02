import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../core/logging/app_logger.dart';
import '../../../core/media/ffmpeg_service.dart';
import '../../text_to_speech/application/tts_service.dart';
import '../../text_to_speech/domain/models/tts_options.dart';
import '../../text_to_speech/domain/models/tts_voice.dart';
import '../domain/models/audio_ducking_level.dart';
import '../domain/models/ken_burns_effect.dart';
import '../domain/models/media_asset.dart';
import '../domain/models/transition.dart';
import '../domain/models/video_export_settings.dart';
import '../domain/models/video_scene.dart';
import '../domain/models/video_template.dart';
import '../infrastructure/project_repository.dart';
import 'video_render_service.dart';
import 'video_studio_state.dart';

/// Riverpod StateNotifier controlling Video Studio operations and desktop UI interactions.
class VideoStudioNotifier extends StateNotifier<VideoStudioState> {
  final ProjectRepository _projectRepository;
  final VideoRenderService _renderService;
  final TtsService _ttsService;
  final FfmpegService _ffmpegService;

  VideoStudioNotifier({
    required ProjectRepository projectRepository,
    required VideoRenderService renderService,
    required TtsService ttsService,
    FfmpegService? ffmpegService,
  })  : _projectRepository = projectRepository,
        _renderService = renderService,
        _ttsService = ttsService,
        _ffmpegService = ffmpegService ?? FfmpegService.instance,
        super(
          VideoStudioState(
            currentProject: VideoTemplate.builtInTemplates.first.createProject(
              projectId: 'proj_${DateTime.now().millisecondsSinceEpoch}',
              projectName: 'Video Bài Giảng Mới',
            ),
          ),
        ) {
    _init();
  }

  Future<void> _init() async {
    await _ffmpegService.initialize();
    await refreshRecentProjects();
  }

  /// Refreshes list of recent video projects from disk and database.
  Future<void> refreshRecentProjects() async {
    try {
      final list = await _projectRepository.listProjects();
      state = state.copyWith(recentProjects: list);
    } catch (e) {
      AppLogger.warning('Failed to load recent projects: $e');
    }
  }

  /// Creates a new project from a selected template.
  void newProject({
    VideoTemplateType templateType = VideoTemplateType.lesson,
    String name = 'Dự án Video Mới',
  }) {
    final template = VideoTemplate.builtInTemplates.firstWhere(
      (t) => t.type == templateType,
      orElse: () => VideoTemplate.builtInTemplates.first,
    );

    final newProj = template.createProject(
      projectId: 'proj_${DateTime.now().millisecondsSinceEpoch}',
      projectName: name,
    );

    state = state.copyWith(
      currentProject: newProj,
      selectedSceneIndex: 0,
      lastRenderResult: null,
      renderProgress: 0.0,
      renderStage: '',
    );
  }

  /// Loads an existing project by ID.
  Future<void> loadProject(String projectId) async {
    try {
      final proj = await _projectRepository.loadProject(projectId);
      if (proj != null) {
        state = state.copyWith(
          currentProject: proj,
          selectedSceneIndex: 0,
        );
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Không thể mở dự án: $e');
    }
  }

  /// Saves current project manifest to disk.
  Future<void> saveProject() async {
    try {
      await _projectRepository.saveProject(state.currentProject);
      await refreshRecentProjects();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Lưu dự án thất bại: $e');
    }
  }

  /// Selects active scene index for editing in Inspector panel.
  void selectScene(int index) {
    if (index >= 0 && index < state.currentProject.scenes.length) {
      state = state.copyWith(selectedSceneIndex: index);
    }
  }

  /// Adds a new scene to the timeline.
  void addScene({int? atIndex}) {
    final proj = state.currentProject;
    final insertIndex = atIndex ?? proj.scenes.length;
    final newSceneId = '${proj.id}_scene_${DateTime.now().millisecondsSinceEpoch}';

    final newScene = VideoScene(
      id: newSceneId,
      projectId: proj.id,
      index: insertIndex,
      durationSeconds: 5.0,
      title: 'Phân cảnh ${insertIndex + 1}',
      imageFitMode: proj.aspectRatio == VideoAspectRatio.vertical9x16
          ? ImageFitMode.fit
          : ImageFitMode.fill,
      blurBackground: proj.aspectRatio == VideoAspectRatio.vertical9x16,
    );

    final updatedScenes = List<VideoScene>.from(proj.scenes);
    updatedScenes.insert(insertIndex, newScene);

    // Reindex
    for (int i = 0; i < updatedScenes.length; i++) {
      updatedScenes[i] = updatedScenes[i].copyWith(index: i);
    }

    state = state.copyWith(
      currentProject: proj.copyWith(scenes: updatedScenes, updatedAt: DateTime.now()),
      selectedSceneIndex: insertIndex,
    );
    _projectRepository.autosave(state.currentProject);
  }

  /// Inserts an AI generated video clip (e.g. from Open-Sora) directly into the project timeline.
  void addAiGeneratedScene({
    required String videoPath,
    required String prompt,
    double durationSeconds = 5.0,
  }) {
    final proj = state.currentProject;
    final insertIndex = proj.scenes.length;
    final newSceneId = '${proj.id}_ai_scene_${DateTime.now().millisecondsSinceEpoch}';

    final newScene = VideoScene(
      id: newSceneId,
      projectId: proj.id,
      index: insertIndex,
      durationSeconds: durationSeconds,
      title: 'Video AI: ${prompt.length > 30 ? "${prompt.substring(0, 30)}..." : prompt}',
      videoClipPath: videoPath,
      imageFitMode: proj.aspectRatio == VideoAspectRatio.vertical9x16
          ? ImageFitMode.fit
          : ImageFitMode.fill,
      blurBackground: proj.aspectRatio == VideoAspectRatio.vertical9x16,
    );

    final updatedScenes = List<VideoScene>.from(proj.scenes);
    updatedScenes.add(newScene);

    for (int i = 0; i < updatedScenes.length; i++) {
      updatedScenes[i] = updatedScenes[i].copyWith(index: i);
    }

    state = state.copyWith(
      currentProject: proj.copyWith(scenes: updatedScenes, updatedAt: DateTime.now()),
      selectedSceneIndex: insertIndex,
    );
    _projectRepository.autosave(state.currentProject);
  }

  /// Deletes a scene at specified index.
  void deleteScene(int index) {
    final proj = state.currentProject;
    if (proj.scenes.length <= 1) return; // Keep at least one scene

    final updatedScenes = List<VideoScene>.from(proj.scenes);
    updatedScenes.removeAt(index);

    // Reindex
    for (int i = 0; i < updatedScenes.length; i++) {
      updatedScenes[i] = updatedScenes[i].copyWith(index: i);
    }

    final newSelectIndex = index.clamp(0, updatedScenes.length - 1);
    state = state.copyWith(
      currentProject: proj.copyWith(scenes: updatedScenes, updatedAt: DateTime.now()),
      selectedSceneIndex: newSelectIndex,
    );
    _projectRepository.autosave(state.currentProject);
  }

  /// Duplicates a scene.
  void duplicateScene(int index) {
    final proj = state.currentProject;
    if (index < 0 || index >= proj.scenes.length) return;

    final target = proj.scenes[index];
    final copyId = '${proj.id}_scene_${DateTime.now().millisecondsSinceEpoch}';
    final duplicated = target.copyWith(
      id: copyId,
      index: index + 1,
      title: '${target.title ?? "Phân cảnh"} (Bản sao)',
    );

    final updatedScenes = List<VideoScene>.from(proj.scenes);
    updatedScenes.insert(index + 1, duplicated);

    for (int i = 0; i < updatedScenes.length; i++) {
      updatedScenes[i] = updatedScenes[i].copyWith(index: i);
    }

    state = state.copyWith(
      currentProject: proj.copyWith(scenes: updatedScenes, updatedAt: DateTime.now()),
      selectedSceneIndex: index + 1,
    );
    _projectRepository.autosave(state.currentProject);
  }

  /// Reorders scenes in the timeline via drag and drop.
  void reorderScenes(int oldIndex, int newIndex) {
    final proj = state.currentProject;
    var targetNew = newIndex;
    if (oldIndex < newIndex) {
      targetNew -= 1;
    }

    final updatedScenes = List<VideoScene>.from(proj.scenes);
    final moved = updatedScenes.removeAt(oldIndex);
    updatedScenes.insert(targetNew, moved);

    for (int i = 0; i < updatedScenes.length; i++) {
      updatedScenes[i] = updatedScenes[i].copyWith(index: i);
    }

    state = state.copyWith(
      currentProject: proj.copyWith(scenes: updatedScenes, updatedAt: DateTime.now()),
      selectedSceneIndex: targetNew,
    );
    _projectRepository.autosave(state.currentProject);
  }

  /// Updates a scene's properties.
  void updateScene(int index, VideoScene updated) {
    final proj = state.currentProject;
    if (index < 0 || index >= proj.scenes.length) return;

    final updatedScenes = List<VideoScene>.from(proj.scenes);
    updatedScenes[index] = updated;

    state = state.copyWith(
      currentProject: proj.copyWith(scenes: updatedScenes, updatedAt: DateTime.now()),
    );
    _projectRepository.autosave(state.currentProject);
  }

  /// Updates duration of a scene.
  void updateSceneDuration(int index, double durationSeconds) {
    final proj = state.currentProject;
    if (index < 0 || index >= proj.scenes.length) return;

    final target = proj.scenes[index];
    updateScene(index, target.copyWith(durationSeconds: durationSeconds.clamp(1.0, 300.0)));
  }

  /// Updates text of a scene (Title, Subtitle, Narration text).
  void updateSceneText(int index, {String? title, String? subtitle, String? narrationText}) {
    final proj = state.currentProject;
    if (index < 0 || index >= proj.scenes.length) return;

    final target = proj.scenes[index];
    updateScene(
      index,
      target.copyWith(
        title: title ?? target.title,
        subtitle: subtitle ?? target.subtitle,
        narrationText: narrationText ?? target.narrationText,
      ),
    );
  }

  /// Updates media attached to a scene (Background Image or Video Clip).
  void updateSceneMedia(int index, {String? imagePath, String? videoPath}) {
    final proj = state.currentProject;
    if (index < 0 || index >= proj.scenes.length) return;

    final target = proj.scenes[index];
    updateScene(
      index,
      target.copyWith(
        backgroundImagePath: imagePath ?? target.backgroundImagePath,
        videoClipPath: videoPath ?? target.videoClipPath,
      ),
    );
  }

  /// Updates transition effect for a scene.
  void updateSceneTransition(int index, SceneTransition transition) {
    final proj = state.currentProject;
    if (index < 0 || index >= proj.scenes.length) return;

    updateScene(index, proj.scenes[index].copyWith(transition: transition));
  }

  /// Updates Ken Burns motion effect for a scene.
  void updateSceneMotion(int index, KenBurnsEffect kenBurns) {
    final proj = state.currentProject;
    if (index < 0 || index >= proj.scenes.length) return;

    updateScene(index, proj.scenes[index].copyWith(kenBurns: kenBurns));
  }

  /// Updates project aspect ratio and target resolution.
  void updateProjectFormat({
    VideoAspectRatio? aspectRatio,
    VideoResolution? resolution,
    int? fps,
  }) {
    final proj = state.currentProject;
    state = state.copyWith(
      currentProject: proj.copyWith(
        aspectRatio: aspectRatio ?? proj.aspectRatio,
        resolution: resolution ?? proj.resolution,
        fps: fps ?? proj.fps,
        exportSettings: proj.exportSettings,
        updatedAt: DateTime.now(),
      ),
    );
    _projectRepository.autosave(state.currentProject);
  }

  /// Sets background music track and ducking parameters.
  void setBackgroundMusic(
    String? musicPath, {
    double? volume,
    AudioDuckingLevel? ducking,
    bool? loop,
  }) {
    final proj = state.currentProject;
    state = state.copyWith(
      currentProject: proj.copyWith(
        backgroundMusicPath: musicPath,
        backgroundMusicVolume: volume ?? proj.backgroundMusicVolume,
        audioDucking: ducking ?? proj.audioDucking,
        backgroundMusicLoop: loop ?? proj.backgroundMusicLoop,
        updatedAt: DateTime.now(),
      ),
    );
    _projectRepository.autosave(state.currentProject);
  }

  /// Imports a media file into the project asset list.
  Future<void> importMediaFile(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return;

    final ext = p.extension(filePath).toLowerCase();
    MediaType type;
    if (['.jpg', '.jpeg', '.png', '.webp', '.bmp'].contains(ext)) {
      type = MediaType.image;
    } else if (['.mp4', '.mov', '.avi', '.mkv'].contains(ext)) {
      type = MediaType.video;
    } else if (['.wav', '.mp3', '.m4a', '.aac'].contains(ext)) {
      type = MediaType.audio;
    } else if (['.srt', '.vtt'].contains(ext)) {
      type = MediaType.subtitle;
    } else {
      type = MediaType.image;
    }

    final probe = await _ffmpegService.probeMedia(filePath);
    final asset = MediaAsset(
      id: 'asset_${DateTime.now().millisecondsSinceEpoch}',
      name: p.basename(filePath),
      path: filePath,
      type: type,
      width: probe.width,
      height: probe.height,
      durationMs: probe.durationMs > 0 ? probe.durationMs : null,
      fileSize: file.lengthSync(),
      importedAt: DateTime.now(),
    );

    final updatedAssets = List<MediaAsset>.from(state.currentProject.assets)..add(asset);
    state = state.copyWith(
      currentProject: state.currentProject.copyWith(assets: updatedAssets),
    );
  }

  /// Generates voiceover audio for a scene narration text using Phase 3 TTS.
  Future<void> generateVoiceoverForScene(int index, {TtsVoice? voice}) async {
    final proj = state.currentProject;
    if (index < 0 || index >= proj.scenes.length) return;

    final scene = proj.scenes[index];
    if (scene.narrationText == null || scene.narrationText!.trim().isEmpty) return;

    try {
      final voices = await _ttsService.getVoices(offlineOnly: true);
      final activeVoice = voice ?? (voices.isNotEmpty ? voices.first : null);
      if (activeVoice == null) {
        throw Exception('Không tìm thấy giọng đọc nào khả dụng trên máy.');
      }

      final audioDir = _projectRepository.getProjectAudioDir(proj.id);
      final outPath = p.join(audioDir.path, 'voice_scene_${index + 1}.wav');

      final resultPath = await _ttsService.synthesizeDirect(
        text: scene.narrationText!,
        voice: activeVoice,
        outputPath: outPath,
        options: const TtsOptions(speed: 1.0, format: TtsAudioFormat.wav),
      );

      final probe = await _ffmpegService.probeMedia(resultPath);
      final durSec = probe.durationSeconds > 0 ? probe.durationSeconds : 5.0;

      // Auto adjust scene duration: voice duration + 0.8s tail padding
      final autoDuration = (durSec + 0.8).clamp(3.0, 300.0);

      updateScene(
        index,
        scene.copyWith(
          voiceoverAudioPath: resultPath,
          voiceoverDurationSeconds: durSec,
          durationSeconds: autoDuration,
        ),
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'Lỗi tạo giọng đọc: $e');
    }
  }

  /// Starts project rendering to MP4 with real progress tracking.
  Future<void> startRender() async {
    if (state.isRendering) return;

    state = state.copyWith(
      isRendering: true,
      renderProgress: 0.0,
      renderStage: 'Đang khởi động render...',
      errorMessage: null,
    );

    try {
      final result = await _renderService.renderProject(
        project: state.currentProject,
        onProgress: (prog, stage) {
          state = state.copyWith(
            renderProgress: prog,
            renderStage: stage,
          );
        },
      );

      state = state.copyWith(
        isRendering: false,
        renderProgress: result.isSuccess ? 1.0 : 0.0,
        renderStage: result.isSuccess ? 'Kết xuất thành công!' : 'Kết xuất thất bại.',
        lastRenderResult: result,
      );
    } catch (e) {
      state = state.copyWith(
        isRendering: false,
        renderStage: 'Lỗi: $e',
        errorMessage: e.toString(),
      );
    }
  }

  /// Cancels currently running render.
  Future<void> cancelRender() async {
    await _renderService.cancelRender();
    state = state.copyWith(
      isRendering: false,
      renderProgress: 0.0,
      renderStage: 'Đã hủy kết xuất.',
    );
  }

  /// Toggles between Simple Mode and Advanced Mode.
  void toggleSimpleMode() {
    state = state.copyWith(isSimpleMode: !state.isSimpleMode);
  }
}
