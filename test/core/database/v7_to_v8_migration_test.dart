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
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('Database Schema v7 -> v8 Migration Tests (Phase 6B-R)', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('nguyendu_v8_migration_test_');
      dbPath = p.join(tempDir.path, 'migration_v8_test.db');
    });

    tearDown(() async {
      try {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    test('Real migration from v7 to v8 preserves existing data and creates new Phase 6B-R tables', () async {
      final factory = databaseFactoryFfi;

      // 1. Create a genuine v7 database
      final v7Db = await factory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 7,
          onCreate: (db, version) async {
            // Base tables v1
            await db.execute(DatabaseTables.createAppSettingsTable);
            await db.execute(DatabaseTables.createProjectsTable);
            await db.execute(DatabaseTables.createFilesTable);
            await db.execute(DatabaseTables.createJobsTable);
            await db.execute(DatabaseTables.createProvidersTable);
            await db.execute(DatabaseTables.createPdfJobsTable);
            await db.execute(DatabaseTables.createOcrCacheTable);

            // Migrations up to v7
            await V1ToV2Migration.migrate(db);
            await V2ToV3Migration.migrate(db);
            await V3ToV4Migration.migrate(db);
            await V4ToV5Migration.migrate(db);
            await V5ToV6Migration.migrate(db);
            await V6ToV7Migration.migrate(db);
          },
        ),
      );

      // Verify v7 version
      final v7Version = await v7Db.getVersion();
      expect(v7Version, equals(7));

      // 2. Insert test data in v7 tables
      final now = DateTime.now().toIso8601String();
      await v7Db.insert(DatabaseTables.tableWorkspaceProjects, {
        'id': 'proj_test_v7',
        'type': 'lesson',
        'name': 'Dự án Truyện Kiều v7',
        'status': 'active',
        'created_at': now,
        'updated_at': now,
        'metadata_json': '{"lessonTitle":"Truyện Kiều"}',
      });

      await v7Db.insert(DatabaseTables.tableProjectArtifacts, {
        'id': 'art_test_v7',
        'project_id': 'proj_test_v7',
        'artifact_type': 'docx',
        'file_id': 'f_test_01',
        'file_path': 'C:/test/file.docx',
        'created_at': now,
        'metadata_json': '{"subtype":"lessonPlan"}',
      });

      await v7Db.insert(DatabaseTables.tableQuestionSets, {
        'id': 'qset_test_v7',
        'project_id': 'proj_test_v7',
        'title': 'Bộ câu hỏi Ngữ văn 9',
        'subject': 'Ngữ văn',
        'grade': '9',
        'created_at': now,
        'updated_at': now,
      });

      await v7Db.insert(DatabaseTables.tableQuestionItems, {
        'id': 'qitem_test_v7',
        'set_id': 'qset_test_v7',
        'type': 'multipleChoice',
        'prompt': 'Truyện Kiều do ai sáng tác?',
        'choices_json': '["A. Nguyễn Du", "B. Nguyễn Trãi", "C. Hồ Xuân Hương", "D. Đoàn Thị Điểm"]',
        'correct_answer': 'A',
        'difficulty': 'nhanBiet',
        'order_index': 0,
      });

      await v7Db.insert(DatabaseTables.tableRubrics, {
        'id': 'rubric_test_v7',
        'project_id': 'proj_test_v7',
        'title': 'Rubric đánh giá bài thuyết trình',
        'total_weight': 100.0,
        'criteria_json': '[]',
        'created_at': now,
        'updated_at': now,
      });

      await v7Db.close();

      // 3. Open with AppDatabase (upgrading to v8 via onUpgrade)
      final v8Db = await factory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 8,
          onUpgrade: (db, oldVersion, newVersion) async {
            if (oldVersion < 8) {
              await V7ToV8Migration.migrate(db);
            }
          },
        ),
      );

      final v8Version = await v8Db.getVersion();
      expect(v8Version, equals(8));

      // 4. Verify existing v7 rows survived intact
      final projects = await v8Db.query(DatabaseTables.tableWorkspaceProjects, where: 'id = ?', whereArgs: ['proj_test_v7']);
      expect(projects.length, equals(1));
      expect(projects.first['name'], equals('Dự án Truyện Kiều v7'));

      final artifacts = await v8Db.query(DatabaseTables.tableProjectArtifacts, where: 'id = ?', whereArgs: ['art_test_v7']);
      expect(artifacts.length, equals(1));

      final qsets = await v8Db.query(DatabaseTables.tableQuestionSets, where: 'id = ?', whereArgs: ['qset_test_v7']);
      expect(qsets.length, equals(1));

      final qitems = await v8Db.query(DatabaseTables.tableQuestionItems, where: 'id = ?', whereArgs: ['qitem_test_v7']);
      expect(qitems.length, equals(1));

      final rubrics = await v8Db.query(DatabaseTables.tableRubrics, where: 'id = ?', whereArgs: ['rubric_test_v7']);
      expect(rubrics.length, equals(1));

      // 5. Verify new v8 tables exist and can accept/return rows
      // 5a. lesson_plan_drafts
      await v8Db.insert(DatabaseTables.tableLessonPlanDrafts, {
        'id': 'draft_1',
        'project_id': 'proj_test_v7',
        'document_json': '{"title":"Giáo án thử nghiệm","sections":[]}',
        'prompt_version': '1.0',
        'created_at': now,
        'updated_at': now,
      });
      final drafts = await v8Db.query(DatabaseTables.tableLessonPlanDrafts, where: 'project_id = ?', whereArgs: ['proj_test_v7']);
      expect(drafts.length, equals(1));
      expect(drafts.first['prompt_version'], equals('1.0'));

      // 5b. worksheets and worksheet_tasks
      await v8Db.insert(DatabaseTables.tableWorksheets, {
        'id': 'ws_1',
        'project_id': 'proj_test_v7',
        'title': 'Phiếu học tập số 1',
        'preset': 'standard',
        'duration': 15,
        'teacher_notes': 'Ghi chú cho giáo viên',
        'created_at': now,
        'updated_at': now,
      });
      await v8Db.insert(DatabaseTables.tableWorksheetTasks, {
        'id': 'wst_1',
        'worksheet_id': 'ws_1',
        'instruction': 'Đọc đoạn thơ sau',
        'content': 'Kiều ở lầu Ngưng Bích',
        'task_type': 'shortAnswer',
        'points': 2.0,
        'order_index': 0,
        'answer_hint': 'Chú ý bút pháp tả cảnh ngụ tình',
      });
      final wsList = await v8Db.query(DatabaseTables.tableWorksheets, where: 'id = ?', whereArgs: ['ws_1']);
      expect(wsList.length, equals(1));
      final taskList = await v8Db.query(DatabaseTables.tableWorksheetTasks, where: 'worksheet_id = ?', whereArgs: ['ws_1']);
      expect(taskList.length, equals(1));
      expect(taskList.first['answer_hint'], equals('Chú ý bút pháp tả cảnh ngụ tình'));

      // 5c. mini_assessments and mini_assessment_items
      await v8Db.insert(DatabaseTables.tableMiniAssessments, {
        'id': 'mini_1',
        'project_id': 'proj_test_v7',
        'source_question_set_id': 'qset_test_v7',
        'title': 'Đề kiểm tra 15 phút',
        'duration': 15,
        'created_at': now,
      });
      await v8Db.insert(DatabaseTables.tableMiniAssessmentItems, {
        'id': 'mini_item_1',
        'mini_assessment_id': 'mini_1',
        'question_id': 'qitem_test_v7',
        'order_index': 0,
      });
      final miniList = await v8Db.query(DatabaseTables.tableMiniAssessments, where: 'id = ?', whereArgs: ['mini_1']);
      expect(miniList.length, equals(1));

      // 5d. learning_objectives
      await v8Db.insert(DatabaseTables.tableLearningObjectives, {
        'id': 'lo_1',
        'project_id': 'proj_test_v7',
        'code': 'YCDT_01',
        'description': 'Nhận biết được thể thơ lục bát',
        'category': 'Kiến thức',
        'order_index': 0,
      });
      final loList = await v8Db.query(DatabaseTables.tableLearningObjectives, where: 'project_id = ?', whereArgs: ['proj_test_v7']);
      expect(loList.length, equals(1));
      expect(loList.first['code'], equals('YCDT_01'));

      await v8Db.close();
    });
  });
}
