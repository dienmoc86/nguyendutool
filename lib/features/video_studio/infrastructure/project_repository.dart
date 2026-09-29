import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../core/database/app_database.dart';
import '../../../core/filesystem/workspace_manager.dart';
import '../../../core/logging/app_logger.dart';
import '../domain/models/video_project.dart';

/// Repository responsible for persisting, loading, and managing Video Projects
/// on the local filesystem and syncing metadata to SQLite database.
class ProjectRepository {
  final AppDatabase _appDatabase;
  final Directory _baseProjectsDir;

  ProjectRepository({
    required AppDatabase appDatabase,
    Directory? customProjectsDir,
  })  : _appDatabase = appDatabase,
        _baseProjectsDir = customProjectsDir ??
            Directory(p.join(WorkspaceManager.getDefaultWorkspacePath(), 'projects', 'video')) {
    if (!_baseProjectsDir.existsSync()) {
      _baseProjectsDir.createSync(recursive: true);
    }
  }

  /// Directory root for a given project ID.
  Directory getProjectDirectory(String projectId) {
    return Directory(p.join(_baseProjectsDir.path, projectId));
  }

  /// Subdirectories inside a project folder.
  Directory getProjectAssetsDir(String projectId) =>
      Directory(p.join(getProjectDirectory(projectId).path, 'assets'))..createSync(recursive: true);

  Directory getProjectAudioDir(String projectId) =>
      Directory(p.join(getProjectDirectory(projectId).path, 'audio'))..createSync(recursive: true);

  Directory getProjectSubtitlesDir(String projectId) =>
      Directory(p.join(getProjectDirectory(projectId).path, 'subtitles'))..createSync(recursive: true);

  Directory getProjectRendersDir(String projectId) =>
      Directory(p.join(getProjectDirectory(projectId).path, 'renders'))..createSync(recursive: true);

  Directory getProjectThumbnailsDir(String projectId) =>
      Directory(p.join(getProjectDirectory(projectId).path, 'thumbnails'))..createSync(recursive: true);

  /// Saves a project manifest to filesystem `project.json` and syncs summary to SQLite.
  Future<void> saveProject(VideoProject project) async {
    final projDir = getProjectDirectory(project.id);
    if (!projDir.existsSync()) projDir.createSync(recursive: true);

    // Write manifest JSON
    final manifestFile = File(p.join(projDir.path, 'project.json'));
    final jsonStr = const JsonEncoder.withIndent('  ').convert(project.toJson());
    await manifestFile.writeAsString(jsonStr, encoding: utf8);

    // Clean prior autosave file since project is now saved cleanly
    final autosaveFile = File(p.join(projDir.path, 'autosave.json'));
    if (autosaveFile.existsSync()) {
      try {
        autosaveFile.deleteSync();
      } catch (_) {}
    }

    // Sync to SQLite database
    try {
      final db = await _appDatabase.database;
      await db.insert(
        'video_projects',
        {
          'id': project.id,
          'name': project.name,
          'aspect_ratio': project.aspectRatio.name,
          'resolution': project.resolution.name,
          'fps': project.fps,
          'duration_seconds': project.totalDurationSeconds,
          'background_music_path': project.backgroundMusicPath,
          'background_music_volume': project.backgroundMusicVolume,
          'background_music_loop': project.backgroundMusicLoop ? 1 : 0,
          'audio_ducking': project.audioDucking.name,
          'export_settings_json': jsonEncode(project.exportSettings.toJson()),
          'created_at': project.createdAt.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Sync scenes
      final batch = db.batch();
      batch.delete('video_scenes', where: 'project_id = ?', whereArgs: [project.id]);

      for (int i = 0; i < project.scenes.length; i++) {
        final s = project.scenes[i];
        batch.insert('video_scenes', {
          'id': s.id,
          'project_id': project.id,
          'scene_index': i,
          'duration_seconds': s.durationSeconds,
          'background_image_path': s.backgroundImagePath,
          'video_clip_path': s.videoClipPath,
          'clip_trim_start_seconds': s.clipTrimStartSeconds,
          'clip_trim_end_seconds': s.clipTrimEndSeconds,
          'clip_mute_original_audio': s.clipMuteOriginalAudio ? 1 : 0,
          'image_fit_mode': s.imageFitMode.name,
          'blur_background': s.blurBackground ? 1 : 0,
          'ken_burns': s.kenBurns.name,
          'transition_type': s.transition.type.name,
          'transition_duration_seconds': s.transition.durationSeconds,
          'title': s.title,
          'subtitle': s.subtitle,
          'body_text': s.bodyText,
          'narration_text': s.narrationText,
          'voiceover_audio_path': s.voiceoverAudioPath,
          'voiceover_duration_seconds': s.voiceoverDurationSeconds,
          'subtitle_segments_json': jsonEncode(s.subtitleSegments.map((seg) => seg.toJson()).toList()),
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      await batch.commit(noResult: true);
    } catch (e) {
      AppLogger.warning('Database sync warning on saveProject: $e');
    }

    AppLogger.info('Video Project saved: "${project.name}" [${project.id}] (${project.scenes.length} scenes)');
  }

  /// Loads a project by ID from filesystem manifest `project.json`.
  Future<VideoProject?> loadProject(String projectId) async {
    final manifestFile = File(p.join(getProjectDirectory(projectId).path, 'project.json'));
    if (!manifestFile.existsSync()) {
      AppLogger.warning('Project manifest not found: ${manifestFile.path}');
      return null;
    }

    try {
      final jsonStr = await manifestFile.readAsString(encoding: utf8);
      final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
      final project = VideoProject.fromJson(jsonMap);
      return project;
    } catch (e) {
      AppLogger.error('Failed to parse project.json for $projectId: $e');
      return null;
    }
  }

  /// Lists all projects available on disk and in database.
  Future<List<VideoProject>> listProjects() async {
    final list = <VideoProject>[];

    if (_baseProjectsDir.existsSync()) {
      final entries = _baseProjectsDir.listSync();
      for (final e in entries) {
        if (e is Directory) {
          final id = p.basename(e.path);
          final proj = await loadProject(id);
          if (proj != null) {
            list.add(proj);
          }
        }
      }
    }

    // Sort by updatedAt descending
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  /// Deletes a project folder and its database rows.
  Future<bool> deleteProject(String projectId) async {
    try {
      final dir = getProjectDirectory(projectId);
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }

      final db = await _appDatabase.database;
      await db.delete('video_projects', where: 'id = ?', whereArgs: [projectId]);
      await db.delete('video_scenes', where: 'project_id = ?', whereArgs: [projectId]);

      AppLogger.info('Project deleted: $projectId');
      return true;
    } catch (e) {
      AppLogger.warning('Delete project failed: $e');
      return false;
    }
  }

  /// Duplicates an existing project with a new ID and title.
  Future<VideoProject?> duplicateProject(String projectId, String newName) async {
    final original = await loadProject(projectId);
    if (original == null) return null;

    final newId = 'proj_${DateTime.now().millisecondsSinceEpoch}';
    final duplicatedScenes = original.scenes.map((s) {
      return s.copyWith(
        id: '${newId}_scene_${s.index + 1}',
        projectId: newId,
      );
    }).toList();

    final duplicated = original.copyWith(
      id: newId,
      name: newName,
      scenes: duplicatedScenes,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await saveProject(duplicated);
    return duplicated;
  }

  /// Autosaves project state for crash recovery.
  Future<void> autosave(VideoProject project) async {
    final projDir = getProjectDirectory(project.id);
    if (!projDir.existsSync()) {
      projDir.createSync(recursive: true);
    }
    final autosaveFile = File(p.join(projDir.path, 'autosave.json'));
    final jsonStr = const JsonEncoder.withIndent('  ').convert(project.toJson());
    await autosaveFile.writeAsString(jsonStr, encoding: utf8);
  }

  /// Checks if an autosaved project recovery file exists (e.g. from abnormal termination).
  Future<VideoProject?> checkRecovery(String projectId) async {
    final projDir = getProjectDirectory(projectId);
    final autosaveFile = File(p.join(projDir.path, 'autosave.json'));

    if (autosaveFile.existsSync()) {
      try {
        final jsonStr = await autosaveFile.readAsString(encoding: utf8);
        return VideoProject.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
      } catch (e) {
        AppLogger.warning('Failed to parse autosave recovery file: $e');
      }
    }
    return null;
  }

  /// Cleans up autosave file once recovered or discarded.
  Future<void> clearAutosave(String projectId) async {
    final autosaveFile = File(p.join(getProjectDirectory(projectId).path, 'autosave.json'));
    if (autosaveFile.existsSync()) {
      try {
        autosaveFile.deleteSync();
      } catch (_) {}
    }
  }
}
