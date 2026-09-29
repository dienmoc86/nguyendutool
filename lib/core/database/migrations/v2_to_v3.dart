import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../logging/app_logger.dart';

/// Database migration from Schema Version 2 (PDF Converter) to Schema Version 3 (Document Scanner).
class V2ToV3Migration {
  static const String createScanSessionsTable = '''
    CREATE TABLE IF NOT EXISTS scan_sessions (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      source_type TEXT NOT NULL,
      status TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  static const String createScanPagesTable = '''
    CREATE TABLE IF NOT EXISTS scan_pages (
      id TEXT PRIMARY KEY,
      session_id TEXT NOT NULL,
      page_index INTEGER NOT NULL,
      original_path TEXT NOT NULL,
      processed_path TEXT NOT NULL,
      rotation INTEGER NOT NULL DEFAULT 0,
      crop_json TEXT,
      quality_json TEXT,
      ocr_status TEXT,
      ocr_text TEXT,
      ocr_json TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (session_id) REFERENCES scan_sessions (id) ON DELETE CASCADE
    );
  ''';

  static const String createScanProfilesTable = '''
    CREATE TABLE IF NOT EXISTS scan_profiles (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      dpi INTEGER NOT NULL DEFAULT 300,
      color_mode TEXT NOT NULL DEFAULT 'color',
      source TEXT NOT NULL DEFAULT 'flatbed',
      paper_size TEXT NOT NULL DEFAULT 'a4',
      auto_crop INTEGER NOT NULL DEFAULT 1,
      deskew INTEGER NOT NULL DEFAULT 1,
      contrast_normalize INTEGER NOT NULL DEFAULT 1,
      is_preset INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  static const List<String> indexStatements = [
    'CREATE INDEX IF NOT EXISTS idx_scan_pages_session ON scan_pages(session_id);',
    'CREATE INDEX IF NOT EXISTS idx_scan_pages_page_index ON scan_pages(session_id, page_index);',
    'CREATE INDEX IF NOT EXISTS idx_scan_sessions_status ON scan_sessions(status);',
  ];

  /// Executes migration logic on the target SQLite database instance.
  static Future<void> migrate(Database db) async {
    AppLogger.info('Starting SQLite migration: v2 -> v3 (Document Scanner tables)...');

    await db.execute(createScanSessionsTable);
    await db.execute(createScanPagesTable);
    await db.execute(createScanProfilesTable);

    for (final idx in indexStatements) {
      await db.execute(idx);
    }

    // Seed default scan profiles if not already present
    final now = DateTime.now().toIso8601String();
    final defaultProfiles = [
      {
        'id': 'profile_doc_std',
        'name': 'Document Standard',
        'dpi': 200,
        'color_mode': 'color',
        'source': 'flatbed',
        'paper_size': 'a4',
        'auto_crop': 1,
        'deskew': 1,
        'contrast_normalize': 1,
        'is_preset': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'id': 'profile_doc_hq',
        'name': 'Document High Quality',
        'dpi': 300,
        'color_mode': 'color',
        'source': 'flatbed',
        'paper_size': 'a4',
        'auto_crop': 1,
        'deskew': 1,
        'contrast_normalize': 1,
        'is_preset': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'id': 'profile_photo',
        'name': 'Photo',
        'dpi': 600,
        'color_mode': 'color',
        'source': 'flatbed',
        'paper_size': 'auto',
        'auto_crop': 0,
        'deskew': 0,
        'contrast_normalize': 0,
        'is_preset': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'id': 'profile_bw',
        'name': 'Black & White',
        'dpi': 300,
        'color_mode': 'bw',
        'source': 'flatbed',
        'paper_size': 'a4',
        'auto_crop': 1,
        'deskew': 1,
        'contrast_normalize': 1,
        'is_preset': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'id': 'profile_ocr_opt',
        'name': 'OCR Optimized',
        'dpi': 300,
        'color_mode': 'grayscale',
        'source': 'flatbed',
        'paper_size': 'a4',
        'auto_crop': 1,
        'deskew': 1,
        'contrast_normalize': 1,
        'is_preset': 1,
        'created_at': now,
        'updated_at': now,
      },
    ];

    for (final prof in defaultProfiles) {
      await db.insert('scan_profiles', prof, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    AppLogger.info('SQLite migration v2 -> v3 completed successfully.');
  }
}
