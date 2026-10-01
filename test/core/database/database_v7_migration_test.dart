import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/database/app_database.dart';
import 'package:nguyendu_tool/core/database/database_tables.dart';
import 'package:nguyendu_tool/core/database/migrations/v1_to_v2.dart';
import 'package:nguyendu_tool/core/database/migrations/v2_to_v3.dart';
import 'package:nguyendu_tool/core/database/migrations/v3_to_v4.dart';
import 'package:nguyendu_tool/core/database/migrations/v4_to_v5.dart';
import 'package:nguyendu_tool/core/database/migrations/v5_to_v6.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('Database Schema v6 -> v7 Migration Tests (Phase 6B)', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('nguyendu_v7_migration_test_');
      dbPath = p.join(tempDir.path, 'migration_test.db');
    });

    tearDown(() async {
      try {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    test('Real migration from v6 to v7 preserves existing data and creates teaching suite tables', () async {
      // Step 1: Create a genuine v6 database manually
      final factory = databaseFactoryFfi;
      final v6Db = await factory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 6,
          onCreate: (db, version) async {
            // Base v1 tables
            await db.execute(DatabaseTables.createAppSettingsTable);
            await db.execute(DatabaseTables.createProjectsTable);
            await db.execute(DatabaseTables.createFilesTable);
            await db.execute(DatabaseTables.createJobsTable);
            await db.execute(DatabaseTables.createProvidersTable);
            await db.execute(DatabaseTables.createPdfJobsTable);
            await db.execute(DatabaseTables.createOcrCacheTable);

            // Migrations up to v6
            await V1ToV2Migration.migrate(db);
            await V2ToV3Migration.migrate(db);
            await V3ToV4Migration.migrate(db);
            await V4ToV5Migration.migrate(db);
            await V5ToV6Migration.migrate(db);
          },
        ),
      );

      // Verify initial v6 version
      final v6Version = await v6Db.getVersion();
      expect(v6Version, equals(6));

      // Step 2: Insert realistic sample data into v6 tables
      await v6Db.insert(DatabaseTables.tableWorkspaceProjects, {
        'id': 'proj-kieu-9',
        'type': 'lesson',
        'name': 'Ngữ văn 9 - Truyện Kiều',
        'status': 'active',
        'created_at': '2026-09-28T09:00:00.000',
        'updated_at': '2026-09-28T09:00:00.000',
        'metadata_json': '{"subject":"Ngữ văn","grade":"9"}',
      });

      await v6Db.insert(DatabaseTables.tableProjectArtifacts, {
        'id': 'art-001',
        'project_id': 'proj-kieu-9',
        'artifact_type': 'document',
        'file_id': 'file-101',
        'file_path': 'C:/data/projects/kieu_9/01_Giao_an.docx',
        'created_at': '2026-09-28T09:05:00.000',
        'metadata_json': '{"subtype":"lessonPlan"}',
      });

      await v6Db.insert(DatabaseTables.tableModuleUsage, {
        'module_id': 'lesson_planner',
        'open_count': 5,
        'is_favorite': 1,
        'last_opened_at': '2026-09-28T09:10:00.000',
      });

      await v6Db.close();

      // Step 3: Upgrade to v7 via AppDatabase
      final appDb = AppDatabase(customPath: dbPath);
      await appDb.init();
      final upgradedDb = appDb.db;

      // Verify database version is upgraded to latest (v8 which incorporates v7)
      final upgradedVersion = await upgradedDb.getVersion();
      expect(upgradedVersion, equals(AppDatabase.databaseVersion));

      // Step 4: Verify existing v6 data is preserved
      final projects = await upgradedDb.query(
        DatabaseTables.tableWorkspaceProjects,
        where: 'id = ?',
        whereArgs: ['proj-kieu-9'],
      );
      expect(projects.length, equals(1));
      expect(projects.first['name'], equals('Ngữ văn 9 - Truyện Kiều'));

      final artifacts = await upgradedDb.query(
        DatabaseTables.tableProjectArtifacts,
        where: 'id = ?',
        whereArgs: ['art-001'],
      );
      expect(artifacts.length, equals(1));
      expect(artifacts.first['file_path'], contains('01_Giao_an.docx'));

      final moduleUsages = await upgradedDb.query(
        DatabaseTables.tableModuleUsage,
        where: 'module_id = ?',
        whereArgs: ['lesson_planner'],
      );
      expect(moduleUsages.length, equals(1));
      expect(moduleUsages.first['open_count'], equals(5));

      // Step 5: Test new v7 tables (question_sets, question_items, rubrics)
      await upgradedDb.insert(DatabaseTables.tableQuestionSets, {
        'id': 'set-kieu-01',
        'project_id': 'proj-kieu-9',
        'title': 'Bộ câu hỏi Truyện Kiều đoạn trích Chị em Thúy Kiều',
        'subject': 'Ngữ văn',
        'grade': '9',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await upgradedDb.insert(DatabaseTables.tableQuestionItems, {
        'id': 'q-001',
        'set_id': 'set-kieu-01',
        'type': 'multipleChoice',
        'prompt': 'Hai chị em Thúy Kiều mang vẻ đẹp như thế nào theo câu thơ "Mai cốt cách tuyết tinh thần"?',
        'choices_json': '["A. Dịu dàng, thanh mảnh","B. Cốt cách như mai, tâm hồn trong trắng như tuyết","C. Kiêu sa, sắc sảo","D. Trầm mặc, đoan trang"]',
        'correct_answer': 'B',
        'explanation': 'Câu thơ thể hiện vẻ thanh cao, trong sạch của hai chị em.',
        'difficulty': 'nhanBiet',
        'objective_id': 'M1.1',
        'order_index': 0,
        'metadata_json': '{"tags":["truyen_kieu","van_9"]}',
      });

      await upgradedDb.insert(DatabaseTables.tableRubrics, {
        'id': 'rubric-001',
        'project_id': 'proj-kieu-9',
        'title': 'Rubric đánh giá bài thuyết trình Chị em Thúy Kiều',
        'criteria_json': '[]',
        'total_weight': 100.0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Verify queried records
      final qSets = await upgradedDb.query(DatabaseTables.tableQuestionSets);
      expect(qSets.length, equals(1));
      expect(qSets.first['id'], equals('set-kieu-01'));

      final qItems = await upgradedDb.query(DatabaseTables.tableQuestionItems);
      expect(qItems.length, equals(1));
      expect(qItems.first['correct_answer'], equals('B'));

      final rubrics = await upgradedDb.query(DatabaseTables.tableRubrics);
      expect(rubrics.length, equals(1));
      expect(rubrics.first['total_weight'], equals(100.0));

      await appDb.close();
    });
  });
}
