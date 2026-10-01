import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../logging/app_logger.dart';

/// Database migration from Schema Version 6 (Product Expansion Foundation) to Schema Version 7 (Teaching Suite Completion).
///
/// Adds:
/// - `question_sets`: Grouping container for questions belonging to a lesson WorkspaceProject.
/// - `question_items`: Structured question items (MCQ, True/False, Short Answer, Essay) with answers and explanations.
/// - `rubrics`: Standard evaluation rubrics with criteria, levels, descriptions, and weighted scoring.
class V6ToV7Migration {
  static const String createQuestionSetsTable = '''
    CREATE TABLE IF NOT EXISTS question_sets (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      title TEXT NOT NULL,
      subject TEXT NOT NULL,
      grade TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      metadata_json TEXT,
      FOREIGN KEY (project_id) REFERENCES workspace_projects (id) ON DELETE CASCADE
    );
  ''';

  static const String createQuestionItemsTable = '''
    CREATE TABLE IF NOT EXISTS question_items (
      id TEXT PRIMARY KEY,
      set_id TEXT NOT NULL,
      type TEXT NOT NULL,
      prompt TEXT NOT NULL,
      choices_json TEXT,
      correct_answer TEXT NOT NULL,
      explanation TEXT,
      difficulty TEXT NOT NULL,
      objective_id TEXT,
      order_index INTEGER NOT NULL DEFAULT 0,
      metadata_json TEXT,
      FOREIGN KEY (set_id) REFERENCES question_sets (id) ON DELETE CASCADE
    );
  ''';

  static const String createRubricsTable = '''
    CREATE TABLE IF NOT EXISTS rubrics (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      title TEXT NOT NULL,
      criteria_json TEXT NOT NULL,
      total_weight REAL NOT NULL DEFAULT 100.0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (project_id) REFERENCES workspace_projects (id) ON DELETE CASCADE
    );
  ''';

  static const List<String> indexes = [
    'CREATE INDEX IF NOT EXISTS idx_question_sets_project ON question_sets(project_id);',
    'CREATE INDEX IF NOT EXISTS idx_question_items_set ON question_items(set_id);',
    'CREATE INDEX IF NOT EXISTS idx_question_items_type ON question_items(type);',
    'CREATE INDEX IF NOT EXISTS idx_question_items_difficulty ON question_items(difficulty);',
    'CREATE INDEX IF NOT EXISTS idx_rubrics_project ON rubrics(project_id);',
  ];

  static Future<void> migrate(Database db) async {
    AppLogger.info('Starting SQLite Schema v6 -> v7 migration (Phase 6B Teaching Suite)...');

    await db.transaction((txn) async {
      await txn.execute(createQuestionSetsTable);
      await txn.execute(createQuestionItemsTable);
      await txn.execute(createRubricsTable);

      for (final indexStmt in indexes) {
        await txn.execute(indexStmt);
      }
    });

    AppLogger.info('SQLite Schema v6 -> v7 migration completed successfully.');
  }
}
