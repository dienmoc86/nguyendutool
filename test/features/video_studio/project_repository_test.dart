import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/database/app_database.dart';
import 'package:nguyendu_tool/features/video_studio/domain/models/audio_ducking_level.dart';
import 'package:nguyendu_tool/features/video_studio/domain/models/video_export_settings.dart';
import 'package:nguyendu_tool/features/video_studio/domain/models/video_project.dart';
import 'package:nguyendu_tool/features/video_studio/domain/models/video_scene.dart';
import 'package:nguyendu_tool/features/video_studio/infrastructure/project_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('ProjectRepository Persistence and Recovery Test Suite', () {
    late Directory tempDir;
    late AppDatabase appDatabase;
    late ProjectRepository repository;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('project_repo_test_');
      appDatabase = AppDatabase(inMemory: true);
      await appDatabase.init();
      repository = ProjectRepository(
        appDatabase: appDatabase,
        customProjectsDir: tempDir,
      );
    });

    tearDown(() async {
      await appDatabase.close();
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test('Saves project manifest to filesystem and syncs with SQLite database', () async {
      final project = VideoProject(
        id: 'proj_save_001',
        name: 'Dự án video hoạt động trường',
        aspectRatio: VideoAspectRatio.widescreen16x9,
        scenes: const [
          VideoScene(
            id: 'sc_001',
            projectId: 'proj_save_001',
            index: 0,
            title: 'Khai giảng',
            durationSeconds: 5.0,
          ),
          VideoScene(
            id: 'sc_002',
            projectId: 'proj_save_001',
            index: 1,
            title: 'Văn nghệ',
            durationSeconds: 7.0,
          ),
        ],
        audioDucking: AudioDuckingLevel.strong,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.saveProject(project);

      // Verify filesystem manifest
      final manifestFile = File('${repository.getProjectDirectory(project.id).path}/project.json');
      expect(manifestFile.existsSync(), isTrue);

      // Verify loaded from filesystem
      final loaded = await repository.loadProject(project.id);
      expect(loaded, isNotNull);
      expect(loaded!.id, project.id);
      expect(loaded.name, project.name);
      expect(loaded.scenes.length, 2);
      expect(loaded.scenes[0].title, 'Khai giảng');
      expect(loaded.scenes[1].title, 'Văn nghệ');
      expect(loaded.audioDucking, AudioDuckingLevel.strong);

      // Verify SQLite synchronization
      final db = await appDatabase.database;
      final projRows = await db.query('video_projects', where: 'id = ?', whereArgs: [project.id]);
      expect(projRows.length, 1);
      expect(projRows.first['name'], project.name);

      final sceneRows = await db.query('video_scenes', where: 'project_id = ?', whereArgs: [project.id]);
      expect(sceneRows.length, 2);
    });

    test('Autosave crash recovery detects newer autosave file correctly', () async {
      final original = VideoProject(
        id: 'proj_recovery_001',
        name: 'Dự án gốc',
        scenes: const [
          VideoScene(id: 's_base', projectId: 'proj_recovery_001', index: 0, title: 'Cảnh 1'),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 1. Save original project
      await repository.saveProject(original);

      // Check recovery initially -> null (autosave does not exist yet)
      final initialRecovery = await repository.checkRecovery(original.id);
      expect(initialRecovery, isNull);

      // Wait a moment so timestamp will be strictly newer
      await Future.delayed(const Duration(milliseconds: 50));

      // 2. Perform autosave with updated scene title
      final updatedInFlight = original.copyWith(
        scenes: [
          ...original.scenes,
          const VideoScene(
            id: 's_added_in_flight',
            projectId: 'proj_recovery_001',
            index: 1,
            title: 'Cảnh vừa thêm trước khi crash',
          ),
        ],
      );
      await repository.autosave(updatedInFlight);

      // 3. Crash recovery should detect the newer autosave file!
      final recovered = await repository.checkRecovery(original.id);
      expect(recovered, isNotNull);
      expect(recovered!.scenes.length, 2);
      expect(recovered.scenes[1].title, 'Cảnh vừa thêm trước khi crash');

      // 4. Clearing autosave removes recovery state
      await repository.clearAutosave(original.id);
      expect(await repository.checkRecovery(original.id), isNull);
    });

    test('Duplicates project with new unique ID and scene IDs', () async {
      final original = VideoProject(
        id: 'proj_orig',
        name: 'Bản gốc',
        scenes: const [
          VideoScene(id: 'orig_1', projectId: 'proj_orig', index: 0, title: 'Scene 1'),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repository.saveProject(original);

      final duplicate = await repository.duplicateProject('proj_orig', 'Bản sao chép');
      expect(duplicate, isNotNull);
      expect(duplicate!.name, 'Bản sao chép');
      expect(duplicate.id, isNot('proj_orig'));
      expect(duplicate.scenes.first.projectId, duplicate.id);

      final loadedDuplicate = await repository.loadProject(duplicate.id);
      expect(loadedDuplicate, isNotNull);
      expect(loadedDuplicate!.name, 'Bản sao chép');
    });

    test('Deletes project directory and database records cleanly', () async {
      final project = VideoProject(
        id: 'proj_to_delete',
        name: 'Dự án sẽ xóa',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repository.saveProject(project);

      final projDir = repository.getProjectDirectory(project.id);
      expect(projDir.existsSync(), isTrue);

      final success = await repository.deleteProject(project.id);
      expect(success, isTrue);
      expect(projDir.existsSync(), isFalse);

      final db = await appDatabase.database;
      final projRows = await db.query('video_projects', where: 'id = ?', whereArgs: [project.id]);
      expect(projRows.isEmpty, isTrue);
    });

    test('Lists all saved video projects sorted by updated date', () async {
      final p1 = VideoProject(
        id: 'list_p1',
        name: 'Dự án 1',
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        updatedAt: DateTime.now().subtract(const Duration(minutes: 10)),
      );
      final p2 = VideoProject(
        id: 'list_p2',
        name: 'Dự án 2',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.saveProject(p1);
      await repository.saveProject(p2);

      final list = await repository.listProjects();
      expect(list.length, 2);
      expect(list.first.id, 'list_p2'); // Newer project first
      expect(list.last.id, 'list_p1');
    });
  });
}
