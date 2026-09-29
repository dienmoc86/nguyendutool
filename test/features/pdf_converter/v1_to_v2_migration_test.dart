import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/database/migrations/v1_to_v2.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  final databaseFactory = databaseFactoryFfi;

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          // Schema v1 tables
          await db.execute('''
            CREATE TABLE IF NOT EXISTS app_settings (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS projects (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              module_type TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS files (
              id TEXT PRIMARY KEY,
              project_id TEXT,
              original_name TEXT NOT NULL,
              local_path TEXT NOT NULL,
              mime_type TEXT,
              size INTEGER NOT NULL,
              created_at TEXT NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS jobs (
              id TEXT PRIMARY KEY,
              job_type TEXT NOT NULL,
              module_type TEXT NOT NULL,
              status TEXT NOT NULL,
              progress REAL NOT NULL DEFAULT 0.0,
              input_json TEXT,
              output_json TEXT,
              error_message TEXT,
              created_at TEXT NOT NULL,
              started_at TEXT,
              finished_at TEXT
            );
          ''');
        },
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('V1 to V2 Migration Tests', () {
    test('Migrates database cleanly adding pdf_jobs and ocr_cache tables', () async {
      // Insert sample v1 record
      await db.insert('app_settings', {
        'key': 'test_setting',
        'value': 'initial_value',
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Run migration v1 -> v2
      await V1ToV2Migration.migrate(db);

      // Verify v1 data is still intact
      final rows = await db.query('app_settings', where: 'key = ?', whereArgs: ['test_setting']);
      expect(rows.length, 1);
      expect(rows.first['value'], 'initial_value');

      // Verify new v2 tables exist and are operable
      await db.insert('pdf_jobs', {
        'id': 'job_001',
        'input_path': 'C:/docs/test.pdf',
        'output_format': 'docx',
        'ocr_language': 'vie',
        'dpi': 200,
        'classification': 'text',
        'total_pages': 5,
        'processed_pages': 0,
        'status': 'queued',
        'created_at': DateTime.now().toIso8601String(),
      });

      final jobRows = await db.query('pdf_jobs');
      expect(jobRows.length, 1);
      expect(jobRows.first['id'], 'job_001');

      await db.insert('ocr_cache', {
        'page_hash': 'hash_123456',
        'language': 'vie',
        'ocr_result_json': '{"fullText": "Cộng hòa Xã hội"}',
        'created_at': DateTime.now().toIso8601String(),
      });

      final cacheRows = await db.query('ocr_cache');
      expect(cacheRows.length, 1);
    });
  });
}
