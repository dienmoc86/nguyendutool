import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../text_to_speech/application/tts_providers.dart';
import '../infrastructure/project_repository.dart';
import '../infrastructure/thumbnail_service.dart';
import 'video_render_service.dart';
import 'video_studio_notifier.dart';
import 'video_studio_state.dart';

/// Provider for Video Project Repository.
final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  final appDb = ref.watch(databaseProvider);
  return ProjectRepository(appDatabase: appDb);
});

/// Provider for Thumbnail Service.
final thumbnailServiceProvider = Provider<ThumbnailService>((ref) {
  return ThumbnailService();
});

/// Provider for Video Render Service.
final videoRenderServiceProvider = Provider<VideoRenderService>((ref) {
  final ttsService = ref.watch(ttsServiceProvider);
  final projectRepo = ref.watch(projectRepositoryProvider);
  final fileRepo = ref.watch(fileRepositoryProvider);
  final jobRepo = ref.watch(jobRepositoryProvider);
  final appDb = ref.watch(databaseProvider);

  return VideoRenderService(
    ttsService: ttsService,
    projectRepository: projectRepo,
    fileRepository: fileRepo,
    jobRepository: jobRepo,
    appDatabase: appDb,
  );
});

/// StateNotifierProvider for Video Studio desktop workspace.
final videoStudioNotifierProvider =
    StateNotifierProvider<VideoStudioNotifier, VideoStudioState>((ref) {
  final projectRepo = ref.watch(projectRepositoryProvider);
  final renderService = ref.watch(videoRenderServiceProvider);
  final ttsService = ref.watch(ttsServiceProvider);

  return VideoStudioNotifier(
    projectRepository: projectRepo,
    renderService: renderService,
    ttsService: ttsService,
  );
});
