import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/database/migrations/v2_to_v3.dart';
import 'package:nguyendu_tool/core/database/migrations/v3_to_v4.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('Database v3 to v4 Migration Tests', () {
    test('Non-destructively migrates v3 database to v4 and seeds presets and dictionary', () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (db, version) async {
            // Setup v3 schema
            await db.execute('''
              CREATE TABLE IF NOT EXISTS files (
                id TEXT PRIMARY KEY,
                original_name TEXT NOT NULL,
                local_path TEXT NOT NULL,
                size INTEGER NOT NULL,
                created_at TEXT NOT NULL
              );
            ''');
            await V2ToV3Migration.migrate(db);
          },
        ),
      );

      // Insert mock existing Phase 2 scan session
      await db.insert('scan_sessions', {
        'id': 'scan_test_001',
        'name': 'Scan Document Phase 2',
        'source_type': 'scanner',
        'status': 'completed',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Execute v3 -> v4 migration
      await V3ToV4Migration.migrate(db);

      // 1. Verify existing Phase 2 data is intact
      final existingSessions = await db.query('scan_sessions', where: 'id = ?', whereArgs: ['scan_test_001']);
      expect(existingSessions.length, equals(1));
      expect(existingSessions.first['name'], equals('Scan Document Phase 2'));

      // 2. Verify new TTS tables exist
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final tableNames = tables.map((t) => t['name'] as String).toList();

      expect(tableNames, contains('tts_jobs'));
      expect(tableNames, contains('tts_chunks'));
      expect(tableNames, contains('tts_presets'));
      expect(tableNames, contains('pronunciation_dictionary'));

      // 3. Verify seeded presets
      final presets = await db.query('tts_presets');
      expect(presets.length, equals(4));
      final presetIds = presets.map((p) => p['id']).toList();
      expect(presetIds, contains('preset_normal'));
      expect(presetIds, contains('preset_slow'));
      expect(presetIds, contains('preset_presentation'));
      expect(presetIds, contains('preset_announcement'));

      // 4. Verify seeded educational pronunciation dictionary
      final rules = await db.query('pronunciation_dictionary');
      expect(rules.length, equals(7));
      final sourcePhrases = rules.map((r) => r['source_phrase']).toList();
      expect(sourcePhrases, contains('NguyenDu Tool'));
      expect(sourcePhrases, contains('STEM'));
      expect(sourcePhrases, contains('AI'));
      expect(sourcePhrases, contains('THCS'));
      expect(sourcePhrases, contains('TP.HCM'));

      await db.close();
    });
  });
}
