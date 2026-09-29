import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:nguyendu_tool/core/database/migrations/v1_to_v2.dart';
import 'package:nguyendu_tool/core/database/migrations/v2_to_v3.dart';

void main() {
  sqfliteFfiInit();
  final databaseFactory = databaseFactoryFfi;

  group('SQLite Migration v2 -> v3', () {
    test('Non-destructively upgrades schema, preserves Phase 1 data and seeds profiles', () async {
      // 1. Initialize DB at version 2
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, version) async {
            // Foundation tables
            await db.execute('''
              CREATE TABLE app_settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL,
                updated_at TEXT NOT NULL
              );
            ''');
            await db.execute('''
              CREATE TABLE projects (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                module_type TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
              );
            ''');
            await db.execute('''
              CREATE TABLE files (
                id TEXT PRIMARY KEY,
                project_id TEXT,
                original_name TEXT NOT NULL,
                local_path TEXT NOT NULL,
                mime_type TEXT,
                size INTEGER NOT NULL,
                created_at TEXT NOT NULL,
                FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE SET NULL
              );
            ''');
            await db.execute('''
              CREATE TABLE providers (
                id TEXT PRIMARY KEY,
                provider_type TEXT NOT NULL,
                provider_name TEXT NOT NULL,
                is_enabled INTEGER NOT NULL DEFAULT 1,
                config_json TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
              );
            ''');
            await db.execute('''
              CREATE TABLE jobs (
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
            // Phase 1 migration
            await V1ToV2Migration.migrate(db);
          },
        ),
      );

      // Insert mock Phase 1 PDF job data
      await db.insert('pdf_jobs', {
        'id': 'phase1_job_001',
        'input_path': 'C:/docs/giao_an.pdf',
        'output_format': 'docx',
        'ocr_language': 'vie',
        'dpi': 200,
        'classification': 'rasterOnly',
        'total_pages': 10,
        'processed_pages': 10,
        'status': 'completed',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Verify Phase 1 data exists
      final phase1Rows = await db.query('pdf_jobs');
      expect(phase1Rows.length, equals(1));
      expect(phase1Rows.first['id'], equals('phase1_job_001'));

      // 2. Execute migration v2 -> v3
      await V2ToV3Migration.migrate(db);

      // 3. Verify Phase 1 data is still intact
      final phase1After = await db.query('pdf_jobs');
      expect(phase1After.length, equals(1));
      expect(phase1After.first['id'], equals('phase1_job_001'));

      // 4. Verify Phase 2 Scanner tables exist
      final sessionCount = await db.query('scan_sessions');
      expect(sessionCount, isEmpty);

      final pagesCount = await db.query('scan_pages');
      expect(pagesCount, isEmpty);

      final profiles = await db.query('scan_profiles');
      expect(profiles.length, equals(5));

      final profileIds = profiles.map((p) => p['id']).toList();
      expect(profileIds, contains('profile_doc_std'));
      expect(profileIds, contains('profile_doc_hq'));
      expect(profileIds, contains('profile_photo'));
      expect(profileIds, contains('profile_bw'));
      expect(profileIds, contains('profile_ocr_opt'));

      await db.close();
    });
  });
}
