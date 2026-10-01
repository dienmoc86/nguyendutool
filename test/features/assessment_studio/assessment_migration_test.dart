import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/database/database_tables.dart';
import 'package:nguyendu_tool/core/database/migrations/v8_to_v9.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Assessment Studio - Schema v8 to v9 Migration Tests (Section 57, 87)', () {
    late Database db;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);

      // 1. Build schema version 8 tables
      await db.execute('''
        CREATE TABLE ${DatabaseTables.tableWorkspaceProjects} (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          status TEXT NOT NULL,
          metadata_json TEXT
        );
      ''');

      await db.execute(DatabaseTables.createLessonPlanDraftsTable);
      await db.execute(DatabaseTables.createWorksheetsTable);
      await db.execute(DatabaseTables.createWorksheetTasksTable);
      await db.execute(DatabaseTables.createQuestionSetsTable);
      await db.execute(DatabaseTables.createQuestionItemsTable);
      await db.execute(DatabaseTables.createRubricsTable);
      await db.execute(DatabaseTables.createMiniAssessmentsTable);
      await db.execute(DatabaseTables.createMiniAssessmentItemsTable);
      await db.execute(DatabaseTables.createLearningObjectivesTable);
      await db.execute(DatabaseTables.createProjectArtifactsTable);

      // 2. Populate real Phase 6B-R data into v8 tables
      const projId = 'proj_v8_legacy';
      await db.insert(DatabaseTables.tableWorkspaceProjects, {
        'id': projId,
        'name': 'Dự án Soạn bài Lão Hạc',
        'type': 'teaching',
        'created_at': '2026-09-30T10:00:00Z',
        'updated_at': '2026-09-30T10:00:00Z',
        'status': 'active',
        'metadata_json': '{"lessonTitle":"Lão Hạc"}',
      });

      await db.insert(DatabaseTables.tableLessonPlanDrafts, {
        'id': 'lpd_1',
        'project_id': projId,
        'document_json': '{"title":"Kế hoạch bài dạy Lão Hạc"}',
        'prompt_version': '1.0',
        'created_at': '2026-09-30T10:00:00Z',
        'updated_at': '2026-09-30T10:00:00Z',
      });

      await db.insert(DatabaseTables.tableWorksheets, {
        'id': 'ws_1',
        'project_id': projId,
        'title': 'Phiếu học tập 01',
        'preset': 'standard',
        'duration': 15,
        'teacher_notes': 'Ghi chú cho giáo viên',
        'created_at': '2026-09-30T10:00:00Z',
        'updated_at': '2026-09-30T10:00:00Z',
      });

      await db.insert(DatabaseTables.tableQuestionSets, {
        'id': 'qs_1',
        'project_id': projId,
        'title': 'Bộ câu hỏi đọc hiểu',
        'subject': 'Ngữ văn',
        'grade': '9',
        'created_at': '2026-09-30T10:00:00Z',
        'updated_at': '2026-09-30T10:00:00Z',
      });

      await db.insert(DatabaseTables.tableQuestionItems, {
        'id': 'qi_1',
        'set_id': 'qs_1',
        'type': 'multipleChoice',
        'prompt': 'Nhân vật chính trong truyện ngắn là ai?',
        'choices_json': '["Lão Hạc","Ông giáo","Binh Tư","Cậu Vàng"]',
        'correct_answer': 'A',
        'difficulty': 'nhanBiet',
        'order_index': 0,
      });

      await db.insert(DatabaseTables.tableRubrics, {
        'id': 'rub_1',
        'project_id': projId,
        'title': 'Rubric đánh giá bài viết nghị luận',
        'criteria_json': '[]',
        'total_weight': 100.0,
        'created_at': '2026-09-30T10:00:00Z',
        'updated_at': '2026-09-30T10:00:00Z',
      });

      await db.insert(DatabaseTables.tableMiniAssessments, {
        'id': 'ma_1',
        'project_id': projId,
        'title': 'Khảo sát 15 phút đầu giờ',
        'duration': 15,
        'created_at': '2026-09-30T10:00:00Z',
      });

      await db.insert(DatabaseTables.tableLearningObjectives, {
        'id': 'obj_1',
        'project_id': projId,
        'code': 'NL_DOC_01',
        'description': 'Nhận biết được cốt truyện và nhân vật',
        'category': 'Đọc hiểu',
        'order_index': 1,
      });

      await db.insert(DatabaseTables.tableProjectArtifacts, {
        'id': 'art_1',
        'project_id': projId,
        'artifact_type': 'docx',
        'file_path': 'C:/Exports/Lao_Hac.docx',
        'created_at': '2026-09-30T10:00:00Z',
      });
    });

    tearDown(() async {
      await db.close();
    });

    test('Non-destructive migration from v8 to v9 preserves all existing data and creates new assessment tables (Section 57, 87)', () async {
      // Execute Migration
      await V8ToV9Migration.migrate(db);

      // 1. VERIFY: Old rows in all tables are completely preserved
      final projects = await db.query(DatabaseTables.tableWorkspaceProjects);
      expect(projects.length, equals(1));
      expect(projects.first['name'], equals('Dự án Soạn bài Lão Hạc'));

      final lessonPlans = await db.query(DatabaseTables.tableLessonPlanDrafts);
      expect(lessonPlans.length, equals(1));
      expect(lessonPlans.first['document_json'], contains('Lão Hạc'));

      final worksheets = await db.query(DatabaseTables.tableWorksheets);
      expect(worksheets.length, equals(1));
      expect(worksheets.first['title'], equals('Phiếu học tập 01'));

      final questionSets = await db.query(DatabaseTables.tableQuestionSets);
      expect(questionSets.length, equals(1));
      expect(questionSets.first['title'], equals('Bộ câu hỏi đọc hiểu'));

      final questionItems = await db.query(DatabaseTables.tableQuestionItems);
      expect(questionItems.length, equals(1));
      expect(questionItems.first['prompt'], contains('Nhân vật chính'));

      final rubrics = await db.query(DatabaseTables.tableRubrics);
      expect(rubrics.length, equals(1));
      expect(rubrics.first['title'], contains('Rubric'));

      final miniAssessments = await db.query(DatabaseTables.tableMiniAssessments);
      expect(miniAssessments.length, equals(1));

      final objectives = await db.query(DatabaseTables.tableLearningObjectives);
      expect(objectives.length, equals(1));
      expect(objectives.first['code'], equals('NL_DOC_01'));

      final artifacts = await db.query(DatabaseTables.tableProjectArtifacts);
      expect(artifacts.length, equals(1));

      // 2. VERIFY: New v9 tables exist and are functional
      await db.insert('exam_specifications', {
        'id': 'spec_v9_test',
        'project_id': 'proj_v8_legacy',
        'title': 'Đặc tả đề kiểm tra giữa kỳ 1',
        'subject': 'Ngữ văn',
        'grade': '9',
        'duration_minutes': 90,
        'total_score': 10.0,
        'question_count': 10,
        'created_at': '2026-09-30T15:00:00Z',
        'updated_at': '2026-09-30T15:00:00Z',
      });

      final specs = await db.query('exam_specifications');
      expect(specs.length, equals(1));
      expect(specs.first['title'], equals('Đặc tả đề kiểm tra giữa kỳ 1'));

      // Check exam_papers table
      await db.insert('exam_papers', {
        'id': 'paper_v9_test',
        'project_id': 'proj_v8_legacy',
        'specification_id': 'spec_v9_test',
        'title': 'Đề thi gốc v9',
        'exam_code': 'MASTER',
        'duration_minutes': 90,
        'total_score': 10.0,
        'created_at': '2026-09-30T15:00:00Z',
      });

      final papers = await db.query('exam_papers');
      expect(papers.length, equals(1));
      expect(papers.first['title'], equals('Đề thi gốc v9'));
    });
  });
}
