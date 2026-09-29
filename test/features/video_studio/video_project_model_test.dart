import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/features/video_studio/domain/models/audio_ducking_level.dart';
import 'package:nguyendu_tool/features/video_studio/domain/models/ken_burns_effect.dart';
import 'package:nguyendu_tool/features/video_studio/domain/models/media_asset.dart';
import 'package:nguyendu_tool/features/video_studio/domain/models/transition.dart';
import 'package:nguyendu_tool/features/video_studio/domain/models/video_export_settings.dart';
import 'package:nguyendu_tool/features/video_studio/domain/models/video_project.dart';
import 'package:nguyendu_tool/features/video_studio/domain/models/video_scene.dart';
import 'package:nguyendu_tool/features/video_studio/domain/models/video_template.dart';

void main() {
  group('Video Studio Domain Models Test Suite', () {
    test('VideoAspectRatio and VideoResolution calculate dimensions correctly', () {
      expect(VideoAspectRatio.widescreen16x9.value, 16 / 9);
      expect(VideoAspectRatio.vertical9x16.value, 9 / 16);
      expect(VideoAspectRatio.square1x1.value, 1.0);
      expect(VideoAspectRatio.standard4x3.value, 4 / 3);

      // 1080p
      expect(
        VideoResolution.res1080p.getDimensionsFor(VideoAspectRatio.widescreen16x9),
        equals((1920, 1080)),
      );
      expect(
        VideoResolution.res1080p.getDimensionsFor(VideoAspectRatio.vertical9x16),
        equals((1080, 1920)),
      );
      expect(
        VideoResolution.res1080p.getDimensionsFor(VideoAspectRatio.square1x1),
        equals((1080, 1080)),
      );
      expect(
        VideoResolution.res1080p.getDimensionsFor(VideoAspectRatio.standard4x3),
        equals((1440, 1080)),
      );

      // 720p
      expect(
        VideoResolution.res720p.getDimensionsFor(VideoAspectRatio.widescreen16x9),
        equals((1280, 720)),
      );
      expect(
        VideoResolution.res720p.getDimensionsFor(VideoAspectRatio.vertical9x16),
        equals((720, 1280)),
      );
    });

    test('VideoScene calculates durations and identifies media types correctly', () {
      const sceneWithoutVoice = VideoScene(
        id: 'scene_1',
        projectId: 'proj_1',
        index: 0,
        title: 'Giới thiệu',
        durationSeconds: 5.0,
      );
      expect(sceneWithoutVoice.durationSeconds, 5.0);
      expect(sceneWithoutVoice.hasVoiceover, isFalse);
      expect(sceneWithoutVoice.hasImage, isFalse);
      expect(sceneWithoutVoice.hasVideoClip, isFalse);

      const sceneWithMedia = VideoScene(
        id: 'scene_2',
        projectId: 'proj_1',
        index: 1,
        title: 'Thuyết minh',
        durationSeconds: 8.0,
        backgroundImagePath: r'C:\images\bg.png',
        voiceoverAudioPath: r'C:\audio\voice.wav',
        voiceoverDurationSeconds: 7.2,
      );
      expect(sceneWithMedia.hasVoiceover, isTrue);
      expect(sceneWithMedia.hasImage, isTrue);
      expect(sceneWithMedia.hasVideoClip, isFalse);
      expect(sceneWithMedia.voiceoverDurationSeconds, 7.2);
    });

    test('VideoScene JSON serialization and deserialization roundtrip', () {
      const original = VideoScene(
        id: 'sc_json_1',
        projectId: 'proj_roundtrip',
        index: 2,
        title: 'Phân cảnh 1: Mở đầu',
        subtitle: 'Nhà trường và xã hội',
        bodyText: 'Nội dung chi tiết của bài học văn học.',
        durationSeconds: 6.5,
        backgroundImagePath: r'C:\assets\bg.png',
        imageFitMode: ImageFitMode.fit,
        blurBackground: true,
        kenBurns: KenBurnsEffect.zoomIn,
        transition: SceneTransition(type: TransitionType.fade, durationSeconds: 0.5),
        narrationText: 'Xin chào quý thầy cô và các em học sinh.',
        voiceoverAudioPath: r'C:\audio\voice.wav',
        voiceoverDurationSeconds: 4.8,
      );

      final json = original.toJson();
      final restored = VideoScene.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.projectId, original.projectId);
      expect(restored.index, original.index);
      expect(restored.title, original.title);
      expect(restored.subtitle, original.subtitle);
      expect(restored.bodyText, original.bodyText);
      expect(restored.durationSeconds, original.durationSeconds);
      expect(restored.backgroundImagePath, original.backgroundImagePath);
      expect(restored.imageFitMode, original.imageFitMode);
      expect(restored.blurBackground, isTrue);
      expect(restored.kenBurns, KenBurnsEffect.zoomIn);
      expect(restored.transition.type, TransitionType.fade);
      expect(restored.transition.durationSeconds, 0.5);
      expect(restored.narrationText, original.narrationText);
      expect(restored.voiceoverAudioPath, original.voiceoverAudioPath);
      expect(restored.voiceoverDurationSeconds, original.voiceoverDurationSeconds);
    });

    test('VideoProject calculates total duration correctly with multiple scenes', () {
      const s1 = VideoScene(id: '1', projectId: 'proj_test', index: 0, durationSeconds: 5.0);
      const s2 = VideoScene(id: '2', projectId: 'proj_test', index: 1, durationSeconds: 9.0);
      const s3 = VideoScene(id: '3', projectId: 'proj_test', index: 2, durationSeconds: 4.0);

      final project = VideoProject(
        id: 'proj_test',
        name: 'Dự án kiểm thử',
        scenes: const [s1, s2, s3],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Total duration = 5.0 + 9.0 + 4.0 = 18.0
      expect(project.totalDurationSeconds, closeTo(18.0, 0.01));
      expect(project.scenes.length, 3);
    });

    test('VideoProject JSON serialization and deserialization roundtrip', () {
      final now = DateTime.now();
      final project = VideoProject(
        id: 'proj_full_1',
        name: 'Video Bài Giảng Văn Học',
        aspectRatio: VideoAspectRatio.widescreen16x9,
        backgroundMusicPath: r'D:\music\gentle.mp3',
        backgroundMusicVolume: 0.25,
        audioDucking: AudioDuckingLevel.medium,
        scenes: const [
          VideoScene(
            id: 'sc_1',
            projectId: 'proj_full_1',
            index: 0,
            title: 'Nguyễn Du và Truyện Kiều',
            durationSeconds: 6.0,
          ),
          VideoScene(
            id: 'sc_2',
            projectId: 'proj_full_1',
            index: 1,
            title: 'Giá trị nhân đạo sâu sắc',
            durationSeconds: 7.0,
          ),
        ],
        exportSettings: const VideoExportSettings(
          resolution: VideoResolution.res1080p,
          fps: 30,
          quality: ExportQuality.highQuality,
          burnSubtitles: true,
        ),
        createdAt: now,
        updatedAt: now,
      );

      final jsonString = jsonEncode(project.toJson());
      final restored = VideoProject.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

      expect(restored.id, project.id);
      expect(restored.name, project.name);
      expect(restored.aspectRatio, VideoAspectRatio.widescreen16x9);
      expect(restored.backgroundMusicPath, r'D:\music\gentle.mp3');
      expect(restored.backgroundMusicVolume, 0.25);
      expect(restored.audioDucking, AudioDuckingLevel.medium);
      expect(restored.scenes.length, 2);
      expect(restored.scenes[0].title, 'Nguyễn Du và Truyện Kiều');
      expect(restored.scenes[1].title, 'Giá trị nhân đạo sâu sắc');
      expect(restored.exportSettings.resolution, VideoResolution.res1080p);
      expect(restored.exportSettings.burnSubtitles, isTrue);
    });

    test('VideoTemplate built-in presets instantiate valid project structures', () {
      expect(VideoTemplate.builtInTemplates.length, greaterThanOrEqualTo(5));

      final lessonTemplate = VideoTemplate.builtInTemplates.firstWhere(
        (t) => t.type == VideoTemplateType.lesson,
      );
      final lessonProject = lessonTemplate.createProject(
        projectId: 'lesson_001',
        projectName: 'Bài Giảng Ngữ Văn Lớp 10',
      );

      expect(lessonProject.id, 'lesson_001');
      expect(lessonProject.name, 'Bài Giảng Ngữ Văn Lớp 10');
      expect(lessonProject.aspectRatio, VideoAspectRatio.widescreen16x9);
      expect(lessonProject.scenes.length, 1);
      expect(lessonProject.exportSettings.burnSubtitles, isTrue);

      final verticalTemplate = VideoTemplate.builtInTemplates.firstWhere(
        (t) => t.type == VideoTemplateType.verticalShort,
      );
      final verticalProject = verticalTemplate.createProject(
        projectId: 'vertical_001',
        projectName: 'Short Video 9:16',
      );
      expect(verticalProject.aspectRatio, VideoAspectRatio.vertical9x16);
      expect(verticalProject.scenes.first.blurBackground, isTrue);
    });

    test('MediaAsset supports image, video, audio, and subtitle typing', () {
      final img = MediaAsset(
        id: 'asset_img',
        name: 'school.jpg',
        path: r'C:\photos\school.jpg',
        type: MediaType.image,
        fileSize: 1048576,
        width: 1920,
        height: 1080,
        importedAt: DateTime.now(),
      );
      expect(img.type, MediaType.image);

      final aud = MediaAsset(
        id: 'asset_aud',
        name: 'theme.mp3',
        path: r'C:\music\theme.mp3',
        type: MediaType.audio,
        fileSize: 3145728,
        durationMs: 124500,
        importedAt: DateTime.now(),
      );
      expect(aud.type, MediaType.audio);
      expect(aud.durationMs, 124500);

      final json = aud.toJson();
      final restored = MediaAsset.fromJson(json);
      expect(restored.id, aud.id);
      expect(restored.name, aud.name);
      expect(restored.path, aud.path);
      expect(restored.type, MediaType.audio);
    });
  });
}
