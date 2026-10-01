import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/database/database_tables.dart';
import 'package:nguyendu_tool/core/database/migrations/v1_to_v2.dart';
import 'package:nguyendu_tool/core/database/migrations/v2_to_v3.dart';
import 'package:nguyendu_tool/core/database/migrations/v3_to_v4.dart';
import 'package:nguyendu_tool/core/database/migrations/v4_to_v5.dart';
import 'package:nguyendu_tool/core/database/migrations/v5_to_v6.dart';
import 'package:nguyendu_tool/core/database/migrations/v6_to_v7.dart';
import 'package:nguyendu_tool/core/database/migrations/v7_to_v8.dart';
import 'package:nguyendu_tool/core/database/app_database.dart';
import 'package:nguyendu_tool/core/projects/data/workspace_project_repository.dart';
import 'package:nguyendu_tool/core/projects/domain/project_type.dart';
import 'package:nguyendu_tool/core/projects/domain/workspace_project.dart';
import 'package:nguyendu_tool/features/teaching_suite/data/teaching_suite_repository.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/lesson_plan_document.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _TestAppDatabase extends AppDatabase {
  final Database _dbInstance;
  _TestAppDatabase(this._dbInstance);
  @override
  Future<Database> get database async => _dbInstance;
}

void main() {
  sqfliteFfiInit();

  group('Lesson Plan Persistence Restart Test (Phase 6B-R)', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('nguyendu_lp_persist_test_');
      dbPath = p.join(tempDir.path, 'lesson_plan_persist.db');
    });

    tearDown(() async {
      try {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    Future<Database> openV8Db() async {
      return await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 8,
          onCreate: (db, version) async {
            await db.execute(DatabaseTables.createAppSettingsTable);
            await db.execute(DatabaseTables.createProjectsTable);
            await db.execute(DatabaseTables.createFilesTable);
            await db.execute(DatabaseTables.createJobsTable);
            await db.execute(DatabaseTables.createProvidersTable);
            await db.execute(DatabaseTables.createPdfJobsTable);
            await db.execute(DatabaseTables.createOcrCacheTable);

            await V1ToV2Migration.migrate(db);
            await V2ToV3Migration.migrate(db);
            await V3ToV4Migration.migrate(db);
            await V4ToV5Migration.migrate(db);
            await V5ToV6Migration.migrate(db);
            await V6ToV7Migration.migrate(db);
            await V7ToV8Migration.migrate(db);
          },
        ),
      );
    }

    test('Lesson plan draft survives restart, DB close, reopen, and project reload', () async {
      const projectId = 'proj_lp_persist_101';
      final now = DateTime.now();

      // 1. Initial session: create project and save lesson plan
      var db = await openV8Db();
      var projectRepo = WorkspaceProjectRepository(appDatabase: _TestAppDatabase(db));
      var teachingRepo = TeachingSuiteRepository.withDb(db);

      final project = WorkspaceProject(
        id: projectId,
        name: 'Ngữ văn 9 - Bài học Truyện Kiều',
        type: ProjectType.lesson,
        createdAt: now,
        updatedAt: now,
      );
      await projectRepo.createProject(project);

      // Create a lesson plan document
      final initialPlan = LessonPlanDocument.createDefault5512(
        topic: 'Chị em Thúy Kiều',
        grade: '9',
        subject: 'Ngữ văn',
      );

      // Edit objectives
      final editedPlan = initialPlan.copyWith(
        title: 'Giáo án Chị em Thúy Kiều (Đã chỉnh sửa)',
        objectives: 'MỤC TIÊU ĐÃ ĐƯỢC GIÁO VIÊN CHỈNH SỬA: Học sinh cảm nhận được vẻ đẹp đoan trang của Thúy Vân và sắc sảo mặn mà của Thúy Kiều.',
        lastModified: DateTime.now(),
      );

      // Persist draft to teaching suite repository
      await teachingRepo.saveLessonPlanDraft(projectId, editedPlan);

      // Verify draft is stored in DB
      var draftInDb = await teachingRepo.getLessonPlanDraft(projectId);
      expect(draftInDb, isNotNull);
      expect(draftInDb!.title, equals('Giáo án Chị em Thúy Kiều (Đã chỉnh sửa)'));
      expect(draftInDb.objectives, contains('MỤC TIÊU ĐÃ ĐƯỢC GIÁO VIÊN CHỈNH SỬA'));

      // 2. Simulate Application Restart: Close DB and destroy repositories
      await db.close();

      // 3. New session: Reopen DB and recreate repositories
      db = await openV8Db();
      projectRepo = WorkspaceProjectRepository(appDatabase: _TestAppDatabase(db));
      teachingRepo = TeachingSuiteRepository.withDb(db);

      // Reload project and draft
      final reloadedProject = await projectRepo.getProject(projectId);
      expect(reloadedProject, isNotNull);
      expect(reloadedProject!.id, equals(projectId));

      final reloadedPlan = await teachingRepo.getLessonPlanDraft(projectId);
      expect(reloadedPlan, isNotNull);
      expect(reloadedPlan!.title, equals(editedPlan.title));
      expect(reloadedPlan.subject, equals(editedPlan.subject));
      expect(reloadedPlan.grade, equals(editedPlan.grade));
      expect(reloadedPlan.objectives, equals(editedPlan.objectives));
      expect(reloadedPlan.activities.length, equals(editedPlan.activities.length));

      await db.close();
    });
  });
}
