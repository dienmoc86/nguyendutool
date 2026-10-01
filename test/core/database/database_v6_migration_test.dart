import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/database/app_database.dart';
import 'package:nguyendu_tool/core/database/database_tables.dart';
import 'package:nguyendu_tool/core/database/migrations/v1_to_v2.dart';
import 'package:nguyendu_tool/core/database/migrations/v2_to_v3.dart';
import 'package:nguyendu_tool/core/database/migrations/v3_to_v4.dart';
import 'package:nguyendu_tool/core/database/migrations/v4_to_v5.dart';
import 'package:nguyendu_tool/core/modules/module_usage_service.dart';
import 'package:nguyendu_tool/core/projects/data/workspace_project_repository.dart';
import 'package:nguyendu_tool/core/projects/domain/artifact_type.dart';
import 'package:nguyendu_tool/core/projects/domain/project_artifact.dart';
import 'package:nguyendu_tool/core/projects/domain/project_type.dart';
import 'package:nguyendu_tool/core/projects/domain/workspace_project.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('Database Schema v5 -> v6 Migration Tests (Phase 6A)', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('nguyendu_v6_migration_test_');
      dbPath = p.join(tempDir.path, 'migration_test.db');
    });

    tearDown(() async {
      try {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    test('Real migration from v5 to v6 preserves all existing data and creates new tables', () async {
      // Step 1: Create a genuine v5 database manually
      final factory = databaseFactoryFfi;
      final v5Db = await factory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 5,
          onCreate: (db, version) async {
            // Base v1 tables
            await db.execute(DatabaseTables.createAppSettingsTable);
            await db.execute(DatabaseTables.createProjectsTable);
            await db.execute(DatabaseTables.createFilesTable);
            await db.execute(DatabaseTables.createJobsTable);
            await db.execute(DatabaseTables.createProvidersTable);
            await db.execute(DatabaseTables.createPdfJobsTable);
            await db.execute(DatabaseTables.createOcrCacheTable);

            // Migrations up to v5
            await V1ToV2Migration.migrate(db);
            await V2ToV3Migration.migrate(db);
            await V3ToV4Migration.migrate(db);
            await V4ToV5Migration.migrate(db);
          },
        ),
      );

      // Verify initial v5 version
      final v5Version = await v5Db.getVersion();
      expect(v5Version, equals(5));

      // Step 2: Insert realistic sample data into v5 tables
      await v5Db.insert(DatabaseTables.tableFiles, {
        'id': 'file-101',
        'original_name': 'de_kiem_tra_toan.pdf',
        'local_path': 'C:/data/de_kiem_tra_toan.pdf',
        'mime_type': 'application/pdf',
        'size': 102400,
        'created_at': '2026-09-28T08:00:00.000',
      });

      await v5Db.insert(DatabaseTables.tableJobs, {
        'id': 'job-201',
        'job_type': 'pdf_conversion',
        'module_type': 'pdf_converter',
        'status': 'completed',
        'progress': 1.0,
        'created_at': '2026-09-28T08:05:00.000',
      });

      await v5Db.insert(DatabaseTables.tableScanSessions, {
        'id': 'scan-301',
        'name': 'Quét Sổ điểm Học kỳ 1',
        'source_type': 'scanner_wia',
        'status': 'completed',
        'created_at': '2026-09-28T08:10:00.000',
        'updated_at': '2026-09-28T08:15:00.000',
      });

      await v5Db.insert(DatabaseTables.tableTtsJobs, {
        'id': 'tts-401',
        'title': 'Đọc truyện Kiều đoạn 1',
        'input_source': 'direct_text',
        'status': 'completed',
        'voice_id': 'vi-VN-Standard-A',
        'voice_name': 'Vietnamese Standard',
        'language': 'vi-VN',
        'provider_id': 'local_sapi',
        'raw_text': 'Trăm năm trong cõi người ta...',
        'normalized_text': 'Trăm năm trong cõi người ta...',
        'created_at': '2026-09-28T08:20:00.000',
        'updated_at': '2026-09-28T08:20:00.000',
      });

      await v5Db.insert(DatabaseTables.tableVideoProjects, {
        'id': 'video-501',
        'name': 'Bài giảng Lịch sử Lớp 9',
        'aspect_ratio': '16:9',
        'resolution': '1920x1080',
        'created_at': '2026-09-28T08:25:00.000',
        'updated_at': '2026-09-28T08:30:00.000',
      });

      // Close v5 database cleanly
      await v5Db.close();

      // Step 3: Open database through AppDatabase which triggers upgrade to v6
      final appDb = AppDatabase(customPath: dbPath);
      await appDb.init();

      final upgradedDb = appDb.db;
      final newVersion = await upgradedDb.getVersion();
      expect(newVersion, greaterThanOrEqualTo(6), reason: 'Database schema must be upgraded to v6 or higher');

      // Step 4: Verify existing data remains completely intact
      final files = await upgradedDb.query(DatabaseTables.tableFiles, where: 'id = ?', whereArgs: ['file-101']);
      expect(files, hasLength(1));
      expect(files.first['original_name'], equals('de_kiem_tra_toan.pdf'));

      final jobs = await upgradedDb.query(DatabaseTables.tableJobs, where: 'id = ?', whereArgs: ['job-201']);
      expect(jobs, hasLength(1));
      expect(jobs.first['status'], equals('completed'));

      final scans = await upgradedDb.query(DatabaseTables.tableScanSessions, where: 'id = ?', whereArgs: ['scan-301']);
      expect(scans, hasLength(1));
      expect(scans.first['name'], equals('Quét Sổ điểm Học kỳ 1'));

      final tts = await upgradedDb.query(DatabaseTables.tableTtsJobs, where: 'id = ?', whereArgs: ['tts-401']);
      expect(tts, hasLength(1));
      expect(tts.first['title'], equals('Đọc truyện Kiều đoạn 1'));

      final video = await upgradedDb.query(DatabaseTables.tableVideoProjects, where: 'id = ?', whereArgs: ['video-501']);
      expect(video, hasLength(1));
      expect(video.first['name'], equals('Bài giảng Lịch sử Lớp 9'));

      // Step 5: Test new schema v6 tables and repositories
      final projectRepo = WorkspaceProjectRepository(appDatabase: appDb);

      final newProject = WorkspaceProject(
        id: 'proj-001',
        type: ProjectType.lesson,
        name: 'Giáo án KHTN Lớp 8 - Bài 12',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await projectRepo.createProject(newProject);

      final fetchedProject = await projectRepo.getProject('proj-001');
      expect(fetchedProject, isNotNull);
      expect(fetchedProject!.name, equals('Giáo án KHTN Lớp 8 - Bài 12'));
      expect(fetchedProject.type, equals(ProjectType.lesson));

      // Attach artifact
      final artifact = ProjectArtifact(
        id: 'art-001',
        projectId: 'proj-001',
        artifactType: ArtifactType.docx,
        filePath: 'C:/exports/giao_an_bai_12.docx',
        createdAt: DateTime.now(),
      );
      await projectRepo.attachArtifact(artifact);

      final artifacts = await projectRepo.listArtifacts('proj-001');
      expect(artifacts, hasLength(1));
      expect(artifacts.first.artifactType, equals(ArtifactType.docx));

      // Test module usage service
      final usageService = ModuleUsageService(appDatabase: appDb);
      await usageService.recordModuleOpened('lesson_planner');
      await usageService.toggleFavorite('lesson_planner');

      final isFav = await usageService.isFavorite('lesson_planner');
      expect(isFav, isTrue);

      final recents = await usageService.getRecentModules();
      expect(recents.map((m) => m.id), contains('lesson_planner'));

      // Step 6: Test safe deletion (deleting project doesn't crash or delete arbitrary files)
      await projectRepo.deleteProject('proj-001');
      final deletedProject = await projectRepo.getProject('proj-001');
      expect(deletedProject, isNull);

      final remainingArtifacts = await projectRepo.listArtifacts('proj-001');
      expect(remainingArtifacts, isEmpty); // Cascade deleted link table metadata

      await appDb.db.close();
    });
  });
}
