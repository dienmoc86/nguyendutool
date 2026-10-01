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
import 'package:nguyendu_tool/features/teaching_suite/domain/models/worksheet_models.dart';
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

  group('Worksheet Persistence Restart Test (Phase 6B-R)', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('nguyendu_ws_persist_test_');
      dbPath = p.join(tempDir.path, 'worksheet_persist.db');
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

    test('Worksheet and structured tasks survive restart, DB close, reopen, and project reload', () async {
      const projectId = 'proj_ws_persist_202';
      final now = DateTime.now();

      // 1. Initial session: create project and save worksheet with tasks
      var db = await openV8Db();
      var projectRepo = WorkspaceProjectRepository(appDatabase: _TestAppDatabase(db));
      var teachingRepo = TeachingSuiteRepository.withDb(db);

      final project = WorkspaceProject(
        id: projectId,
        name: 'Ngữ văn 9 - Phiếu học tập Truyện Kiều',
        type: ProjectType.lesson,
        createdAt: now,
        updatedAt: now,
      );
      await projectRepo.createProject(project);

      final initialWorksheet = WorksheetModel(
        id: 'ws_test_001',
        projectId: projectId,
        title: 'Phiếu học tập: Phân tích 8 câu thơ cuối Kiều ở lầu Ngưng Bích',
        preset: 'critical_thinking',
        durationMinutes: 20,
        teacherNotes: 'Cho học sinh thảo luận cặp đôi trước khi viết câu trả lời.',
        tasks: [
          const WorksheetTask(
            id: 'task_001',
            worksheetId: 'ws_test_001',
            instruction: 'Tìm các từ ngữ miêu tả thiên nhiên trong 8 câu thơ cuối.',
            content: 'Buồn trông cửa bể chiều hôm...',
            taskType: WorksheetTaskType.shortAnswer,
            points: 2.0,
            orderIndex: 0,
            hint: 'Cửa bể chiều hôm, ngọn nước mới sa, hoa trôi man mác...',
          ),
          const WorksheetTask(
            id: 'task_002',
            worksheetId: 'ws_test_001',
            instruction: 'Phân tích điệp ngữ "Buồn trông" và tác dụng nghệ thuật.',
            content: '',
            taskType: WorksheetTaskType.discussion,
            points: 3.0,
            orderIndex: 1,
            hint: 'Điệp từ tạo âm hưởng trầm buồn, nhấn mạnh nỗi sầu dằng dặc.',
          ),
        ],
        updatedAt: now,
      );

      await teachingRepo.saveWorksheet(initialWorksheet);

      // Verify immediate save
      final savedWs = await teachingRepo.getWorksheet(projectId);
      expect(savedWs, isNotNull);
      expect(savedWs!.tasks.length, equals(2));

      // 2. Edit a task
      final updatedTasks = List<WorksheetTask>.from(savedWs.tasks);
      updatedTasks[0] = updatedTasks[0].copyWith(
        points: 4.0,
        instruction: 'HÃY CHỈ RÕ CÁC HÌNH ẢNH BIỂU TƯỢNG VÀ PHÂN TÍCH Ý NGHĨA.',
      );
      final editedWs = savedWs.copyWith(
        title: 'Phiếu học tập Nâng cao: Kiều ở lầu Ngưng Bích',
        tasks: updatedTasks,
        updatedAt: DateTime.now(),
      );
      await teachingRepo.saveWorksheet(editedWs);

      // 3. Restart: Close DB and destroy repositories
      await db.close();

      // 4. Reopen and reload
      db = await openV8Db();
      projectRepo = WorkspaceProjectRepository(appDatabase: _TestAppDatabase(db));
      teachingRepo = TeachingSuiteRepository.withDb(db);

      final reloadedWs = await teachingRepo.getWorksheet(projectId);
      expect(reloadedWs, isNotNull);
      expect(reloadedWs!.id, equals('ws_test_001'));
      expect(reloadedWs.projectId, equals(projectId));
      expect(reloadedWs.title, equals('Phiếu học tập Nâng cao: Kiều ở lầu Ngưng Bích'));
      expect(reloadedWs.durationMinutes, equals(20));
      expect(reloadedWs.teacherNotes, equals('Cho học sinh thảo luận cặp đôi trước khi viết câu trả lời.'));
      expect(reloadedWs.tasks.length, equals(2));
      expect(reloadedWs.tasks[0].instruction, equals('HÃY CHỈ RÕ CÁC HÌNH ẢNH BIỂU TƯỢNG VÀ PHÂN TÍCH Ý NGHĨA.'));
      expect(reloadedWs.tasks[0].points, equals(4.0));
      expect(reloadedWs.tasks[1].taskType, equals(WorksheetTaskType.discussion));

      await db.close();
    });
  });
}
