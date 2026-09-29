import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../logging/app_logger.dart';

/// Database migration from Schema Version 1 (Foundation) to Schema Version 2 (PDF + OCR + Library).
class V1ToV2Migration {
  static const String createPdfJobsTable = '''
    CREATE TABLE IF NOT EXISTS pdf_jobs (
      id TEXT PRIMARY KEY,
      input_path TEXT NOT NULL,
      output_format TEXT NOT NULL,
      ocr_language TEXT NOT NULL,
      dpi INTEGER NOT NULL,
      classification TEXT NOT NULL,
      total_pages INTEGER NOT NULL,
      processed_pages INTEGER NOT NULL DEFAULT 0,
      docx_output_path TEXT,
      xlsx_output_path TEXT,
      status TEXT NOT NULL,
      progress REAL NOT NULL DEFAULT 0.0,
      error_message TEXT,
      duration_ms INTEGER,
      created_at TEXT NOT NULL,
      finished_at TEXT
    );
  ''';

  static const String createOcrCacheTable = '''
    CREATE TABLE IF NOT EXISTS ocr_cache (
      page_hash TEXT PRIMARY KEY,
      language TEXT NOT NULL,
      ocr_result_json TEXT NOT NULL,
      created_at TEXT NOT NULL
    );
  ''';

  static const List<String> indexStatements = [
    'CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status);',
    'CREATE INDEX IF NOT EXISTS idx_pdf_jobs_status ON pdf_jobs(status);',
    'CREATE INDEX IF NOT EXISTS idx_files_project ON files(project_id);',
    'CREATE INDEX IF NOT EXISTS idx_files_created ON files(created_at);',
  ];

  /// Executes migration logic on the target SQLite database instance.
  static Future<void> migrate(Database db) async {
    AppLogger.info('Starting SQLite migration: v1 -> v2 (PDF Converter, OCR Cache, Indexes)...');
    
    await db.execute(createPdfJobsTable);
    await db.execute(createOcrCacheTable);

    for (final idx in indexStatements) {
      await db.execute(idx);
    }

    AppLogger.info('SQLite migration v1 -> v2 completed successfully.');
  }
}
