import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../logging/app_logger.dart';

/// Database migration from Schema Version 7 (Teaching Suite Completion) to Schema Version 8 (Data Integrity Remediation).
///
/// Adds:
/// - `lesson_plan_drafts`: Dedicated persistence for 5512 lesson plan drafts separate from project metadata.
/// - `worksheets`: Structured persistence for student worksheets.
/// - `worksheet_tasks`: Individual structured learning tasks for worksheets.
/// - `mini_assessments`: Structured mini assessment exams with fixed question order and timing.
/// - `mini_assessment_items`: Questions selected for each mini assessment with snapshot backup.
/// - `learning_objectives`: Structured learning objectives with codes and categories for GDPT 2018.
class V7ToV8Migration {
  static const String createLessonPlanDraftsTable = '''
    CREATE TABLE IF NOT EXISTS lesson_plan_drafts (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL UNIQUE,
      document_json TEXT NOT NULL,
      prompt_version TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (project_id) REFERENCES workspace_projects (id) ON DELETE CASCADE
    );
  ''';

  static const String createWorksheetsTable = '''
    CREATE TABLE IF NOT EXISTS worksheets (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      title TEXT NOT NULL,
      preset TEXT,
      duration INTEGER DEFAULT 45,
      teacher_notes TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (project_id) REFERENCES workspace_projects (id) ON DELETE CASCADE
    );
  ''';

  static const String createWorksheetTasksTable = '''
    CREATE TABLE IF NOT EXISTS worksheet_tasks (
      id TEXT PRIMARY KEY,
      worksheet_id TEXT NOT NULL,
      instruction TEXT NOT NULL,
      content TEXT NOT NULL,
      task_type TEXT NOT NULL,
      points REAL DEFAULT 1.0,
      order_index INTEGER NOT NULL DEFAULT 0,
      answer_hint TEXT,
      FOREIGN KEY (worksheet_id) REFERENCES worksheets (id) ON DELETE CASCADE
    );
  ''';

  static const String createMiniAssessmentsTable = '''
    CREATE TABLE IF NOT EXISTS mini_assessments (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      source_question_set_id TEXT,
      title TEXT NOT NULL,
      duration INTEGER DEFAULT 15,
      created_at TEXT NOT NULL,
      FOREIGN KEY (project_id) REFERENCES workspace_projects (id) ON DELETE CASCADE
    );
  ''';

  static const String createMiniAssessmentItemsTable = '''
    CREATE TABLE IF NOT EXISTS mini_assessment_items (
      id TEXT PRIMARY KEY,
      mini_assessment_id TEXT NOT NULL,
      question_id TEXT NOT NULL,
      order_index INTEGER NOT NULL DEFAULT 0,
      snapshot_json TEXT,
      FOREIGN KEY (mini_assessment_id) REFERENCES mini_assessments (id) ON DELETE CASCADE
    );
  ''';

  static const String createLearningObjectivesTable = '''
    CREATE TABLE IF NOT EXISTS learning_objectives (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      code TEXT NOT NULL,
      description TEXT NOT NULL,
      category TEXT,
      order_index INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (project_id) REFERENCES workspace_projects (id) ON DELETE CASCADE
    );
  ''';

  static const List<String> indexes = [
    'CREATE INDEX IF NOT EXISTS idx_lesson_plan_drafts_project ON lesson_plan_drafts(project_id);',
    'CREATE INDEX IF NOT EXISTS idx_worksheets_project ON worksheets(project_id);',
    'CREATE INDEX IF NOT EXISTS idx_worksheet_tasks_worksheet ON worksheet_tasks(worksheet_id);',
    'CREATE INDEX IF NOT EXISTS idx_mini_assessments_project ON mini_assessments(project_id);',
    'CREATE INDEX IF NOT EXISTS idx_mini_assessment_items_assessment ON mini_assessment_items(mini_assessment_id);',
    'CREATE INDEX IF NOT EXISTS idx_learning_objectives_project ON learning_objectives(project_id);',
  ];

  static Future<void> migrate(Database db) async {
    AppLogger.info('Starting SQLite Schema v7 -> v8 migration (Phase 6B-R)...');

    await db.transaction((txn) async {
      await txn.execute(createLessonPlanDraftsTable);
      await txn.execute(createWorksheetsTable);
      await txn.execute(createWorksheetTasksTable);
      await txn.execute(createMiniAssessmentsTable);
      await txn.execute(createMiniAssessmentItemsTable);
      await txn.execute(createLearningObjectivesTable);

      for (final idx in indexes) {
        await txn.execute(idx);
      }
    });

    AppLogger.info('SQLite Schema v7 -> v8 migration completed successfully.');
  }
}
