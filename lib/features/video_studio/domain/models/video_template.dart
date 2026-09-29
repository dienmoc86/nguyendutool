import 'audio_ducking_level.dart';
import 'ken_burns_effect.dart';
import 'transition.dart';
import 'video_export_settings.dart';
import 'video_project.dart';
import 'video_scene.dart';

/// Pre-configured project templates for school and educational video creation.
enum VideoTemplateType {
  lesson('Bài giảng', 'Video bài giảng chuẩn 16:9 với tiêu đề rõ ràng, hình ảnh minh họa và phụ đề'),
  announcement('Thông báo nhà trường', 'Video thông báo chính thức của trường học, thông điệp trang trọng'),
  activitySlideshow('Hoạt động trường', 'Slideshow ảnh sinh động các hoạt động ngoại khóa, lễ hội, đại hội'),
  photoAlbum('Slideshow ảnh kỷ yếu', 'Trình chiếu ảnh kỷ niệm, họp lớp với hiệu ứng chuyển cảnh mượt mà'),
  verticalShort('Video dọc 9:16', 'Video ngắn định dạng dọc chuẩn TikTok / Reel / YouTube Short');

  final String title;
  final String description;

  const VideoTemplateType(this.title, this.description);
}

class VideoTemplate {
  final VideoTemplateType type;
  final String name;
  final VideoAspectRatio aspectRatio;
  final VideoResolution resolution;
  final int defaultFps;
  final SceneTransition defaultTransition;
  final KenBurnsEffect defaultKenBurns;
  final AudioDuckingLevel defaultDucking;
  final bool defaultBurnSubtitles;

  const VideoTemplate({
    required this.type,
    required this.name,
    this.aspectRatio = VideoAspectRatio.widescreen16x9,
    this.resolution = VideoResolution.res1080p,
    this.defaultFps = 30,
    this.defaultTransition = const SceneTransition(type: TransitionType.fade, durationSeconds: 0.5),
    this.defaultKenBurns = KenBurnsEffect.none,
    this.defaultDucking = AudioDuckingLevel.medium,
    this.defaultBurnSubtitles = true,
  });

  /// Factory creating an empty VideoProject initialized according to this template.
  VideoProject createProject({
    required String projectId,
    required String projectName,
  }) {
    return VideoProject(
      id: projectId,
      name: projectName,
      aspectRatio: aspectRatio,
      resolution: resolution,
      fps: defaultFps,
      scenes: [
        VideoScene(
          id: '${projectId}_scene_1',
          projectId: projectId,
          index: 0,
          durationSeconds: 5.0,
          title: type == VideoTemplateType.lesson
              ? 'Tiêu đề bài giảng'
              : (type == VideoTemplateType.announcement ? 'Thông báo nhà trường' : 'Hoạt động nổi bật'),
          subtitle: type == VideoTemplateType.lesson ? 'Môn học / Khối lớp' : 'Niên khóa 2026 - 2027',
          transition: defaultTransition,
          kenBurns: defaultKenBurns,
          imageFitMode: aspectRatio == VideoAspectRatio.vertical9x16 ? ImageFitMode.fit : ImageFitMode.fill,
          blurBackground: aspectRatio == VideoAspectRatio.vertical9x16,
        ),
      ],
      audioDucking: defaultDucking,
      exportSettings: VideoExportSettings(
        aspectRatio: aspectRatio,
        resolution: resolution,
        fps: defaultFps,
        duckingLevel: defaultDucking,
        burnSubtitles: defaultBurnSubtitles,
      ),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static const List<VideoTemplate> builtInTemplates = [
    VideoTemplate(
      type: VideoTemplateType.lesson,
      name: 'Bài giảng giáo dục 16:9',
      aspectRatio: VideoAspectRatio.widescreen16x9,
      resolution: VideoResolution.res1080p,
      defaultTransition: SceneTransition(type: TransitionType.fade, durationSeconds: 0.5),
      defaultKenBurns: KenBurnsEffect.none,
      defaultDucking: AudioDuckingLevel.medium,
      defaultBurnSubtitles: true,
    ),
    VideoTemplate(
      type: VideoTemplateType.announcement,
      name: 'Thông báo nhà trường',
      aspectRatio: VideoAspectRatio.widescreen16x9,
      resolution: VideoResolution.res1080p,
      defaultTransition: SceneTransition(type: TransitionType.crossfade, durationSeconds: 0.5),
      defaultKenBurns: KenBurnsEffect.none,
      defaultDucking: AudioDuckingLevel.strong,
      defaultBurnSubtitles: true,
    ),
    VideoTemplate(
      type: VideoTemplateType.activitySlideshow,
      name: 'Hoạt động phong trào / Lễ hội',
      aspectRatio: VideoAspectRatio.widescreen16x9,
      resolution: VideoResolution.res1080p,
      defaultTransition: SceneTransition(type: TransitionType.slideLeft, durationSeconds: 0.5),
      defaultKenBurns: KenBurnsEffect.zoomIn,
      defaultDucking: AudioDuckingLevel.light,
      defaultBurnSubtitles: false,
    ),
    VideoTemplate(
      type: VideoTemplateType.photoAlbum,
      name: 'Slideshow ảnh kỷ yếu',
      aspectRatio: VideoAspectRatio.widescreen16x9,
      resolution: VideoResolution.res1080p,
      defaultTransition: SceneTransition(type: TransitionType.crossfade, durationSeconds: 1.0),
      defaultKenBurns: KenBurnsEffect.zoomOut,
      defaultDucking: AudioDuckingLevel.off,
      defaultBurnSubtitles: false,
    ),
    VideoTemplate(
      type: VideoTemplateType.verticalShort,
      name: 'Short Video dọc 9:16',
      aspectRatio: VideoAspectRatio.vertical9x16,
      resolution: VideoResolution.res1080p,
      defaultTransition: SceneTransition(type: TransitionType.fade, durationSeconds: 0.25),
      defaultKenBurns: KenBurnsEffect.none,
      defaultDucking: AudioDuckingLevel.medium,
      defaultBurnSubtitles: true,
    ),
  ];
}
