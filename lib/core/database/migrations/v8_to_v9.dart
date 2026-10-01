import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../logging/app_logger.dart';

/// Database migration from Schema Version 8 (Phase 6B-R Data Integrity) to Schema Version 9 (Phase 7 Assessment Studio Core).
///
/// Adds:
/// - `exam_specifications`: Exam blueprints and test structure configuration.
/// - `exam_matrix_cells`: Cognitive level & objective distribution grid cells (GDPT 2018).
/// - `exam_papers`: Master exam paper and revisions with immutable snapshot metadata.
/// - `exam_paper_questions`: Selected questions with frozen snapshot JSON for immutability.
/// - `exam_codes`: Multi-code student exams (101, 102, 103, 104...).
/// - `exam_code_questions`: Shuffled questions and choices with deterministic answer remapping.
class V8ToV9Migration {
  static const String createExamSpecificationsTable = '''
    CREATE TABLE IF NOT EXISTS exam_specifications (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      title TEXT NOT NULL,
      subject TEXT NOT NULL,
      grade TEXT NOT NULL,
      duration_minutes INTEGER NOT NULL DEFAULT 45,
      total_score REAL NOT NULL DEFAULT 10.0,
      question_count INTEGER NOT NULL DEFAULT 0,
      instructions TEXT,
      allowed_question_types_json TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (project_id) REFERENCES workspace_projects (id) ON DELETE CASCADE
    );
  ''';

  static const String createExamMatrixCellsTable = '''
    CREATE TABLE IF NOT EXISTS exam_matrix_cells (
      id TEXT PRIMARY KEY,
      specification_id TEXT NOT NULL,
      objective_id TEXT NOT NULL,
      difficulty TEXT NOT NULL,
      question_count INTEGER NOT NULL DEFAULT 0,
      score_per_question REAL NOT NULL DEFAULT 0.0,
      question_type_distribution_json TEXT,
      FOREIGN KEY (specification_id) REFERENCES exam_specifications (id) ON DELETE CASCADE
    );
  ''';

  static const String createExamPapersTable = '''
    CREATE TABLE IF NOT EXISTS exam_papers (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      specification_id TEXT NOT NULL,
      title TEXT NOT NULL,
      exam_code TEXT NOT NULL DEFAULT 'MASTER',
      duration_minutes INTEGER NOT NULL DEFAULT 45,
      total_score REAL NOT NULL DEFAULT 10.0,
      random_seed INTEGER,
      revision_number INTEGER NOT NULL DEFAULT 1,
      is_finalized INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      finalized_at TEXT,
      FOREIGN KEY (project_id) REFERENCES workspace_projects (id) ON DELETE CASCADE
    );
  ''';

  static const String createExamPaperQuestionsTable = '''
    CREATE TABLE IF NOT EXISTS exam_paper_questions (
      id TEXT PRIMARY KEY,
      exam_paper_id TEXT NOT NULL,
      question_id TEXT NOT NULL,
      order_index INTEGER NOT NULL DEFAULT 0,
      score REAL NOT NULL DEFAULT 0.0,
      section_index INTEGER NOT NULL DEFAULT 0,
      snapshot_json TEXT NOT NULL,
      FOREIGN KEY (exam_paper_id) REFERENCES exam_papers (id) ON DELETE CASCADE
    );
  ''';

  static const String createExamCodesTable = '''
    CREATE TABLE IF NOT EXISTS exam_codes (
      id TEXT PRIMARY KEY,
      exam_paper_id TEXT NOT NULL,
      code TEXT NOT NULL,
      created_at TEXT NOT NULL,
      FOREIGN KEY (exam_paper_id) REFERENCES exam_papers (id) ON DELETE CASCADE
    );
  ''';

  static const String createExamCodeQuestionsTable = '''
    CREATE TABLE IF NOT EXISTS exam_code_questions (
      id TEXT PRIMARY KEY,
      exam_code_id TEXT NOT NULL,
      question_id TEXT NOT NULL,
      order_index INTEGER NOT NULL DEFAULT 0,
      score REAL NOT NULL DEFAULT 0.0,
      correct_display_answer TEXT NOT NULL,
      choice_order_json TEXT,
      snapshot_json TEXT NOT NULL,
      FOREIGN KEY (exam_code_id) REFERENCES exam_codes (id) ON DELETE CASCADE
    );
  ''';

  static const List<String> indexes = [
    'CREATE INDEX IF NOT EXISTS idx_exam_specs_project ON exam_specifications(project_id);',
    'CREATE INDEX IF NOT EXISTS idx_exam_matrix_spec ON exam_matrix_cells(specification_id);',
    'CREATE INDEX IF NOT EXISTS idx_exam_papers_project ON exam_papers(project_id);',
    'CREATE INDEX IF NOT EXISTS idx_exam_paper_questions_paper ON exam_paper_questions(exam_paper_id);',
    'CREATE INDEX IF NOT EXISTS idx_exam_codes_paper ON exam_codes(exam_paper_id);',
    'CREATE INDEX IF NOT EXISTS idx_exam_code_questions_code ON exam_code_questions(exam_code_id);',
  ];

  static Future<void> migrate(Database db) async {
    AppLogger.info('Starting SQLite Schema v8 -> v9 migration (Phase 7 Assessment Studio)...');

    await db.transaction((txn) async {
      await txn.execute(createExamSpecificationsTable);
      await txn.execute(createExamMatrixCellsTable);
      await txn.execute(createExamPapersTable);
      await txn.execute(createExamPaperQuestionsTable);
      await txn.execute(createExamCodesTable);
      await txn.execute(createExamCodeQuestionsTable);

      for (final idx in indexes) {
        await txn.execute(idx);
      }
    });

    AppLogger.info('SQLite Schema v8 -> v9 migration completed successfully.');
  }
}
