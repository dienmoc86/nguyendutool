import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/database/migrations/v3_to_v4.dart';
import 'package:nguyendu_tool/core/database/migrations/v4_to_v5.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('Database v4 to v5 Migration Tests', () {
    test('Non-destructively migrates v4 database to v5 and creates Video Studio tables', () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 4,
          onCreate: (db, version) async {
            // Setup base schema and v4 tables
            await db.execute('''
              CREATE TABLE IF NOT EXISTS files (
                id TEXT PRIMARY KEY,
                original_name TEXT NOT NULL,
                local_path TEXT NOT NULL,
                size INTEGER NOT NULL,
                created_at TEXT NOT NULL
              );
            ''');
            await V3ToV4Migration.migrate(db);
          },
        ),
      );

      // Insert mock existing Phase 3 TTS job
      await db.insert('tts_jobs', {
        'id': 'tts_test_001',
        'title': 'TTS Lesson Audio',
        'input_source': 'text',
        'raw_text': 'Xin chào bài giảng',
        'normalized_text': 'Xin chào bài giảng',
        'provider_id': 'windows_local',
        'voice_id': 'Microsoft Hazel Desktop',
        'voice_name': 'Microsoft Hazel Desktop',
        'language': 'en-GB',
        'audio_format': 'wav',
        'status': 'completed',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Execute v4 -> v5 migration
      await V4ToV5Migration.migrate(db);

      // 1. Verify existing Phase 3 data is preserved non-destructively
      final existingTts = await db.query('tts_jobs', where: 'id = ?', whereArgs: ['tts_test_001']);
      expect(existingTts.length, equals(1));
      expect(existingTts.first['title'], equals('TTS Lesson Audio'));

      // 2. Verify new Video Studio tables exist
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final tableNames = tables.map((t) => t['name'] as String).toList();

      expect(tableNames, contains('video_projects'));
      expect(tableNames, contains('video_scenes'));
      expect(tableNames, contains('video_assets'));
      expect(tableNames, contains('video_renders'));

      // 3. Test insert and query on new Video Studio tables
      await db.insert('video_projects', {
        'id': 'proj_v5_001',
        'name': 'Dự án Video Bài Giảng Lịch Sử',
        'aspect_ratio': 'widescreen16x9',
        'resolution': 'res1080p',
        'fps': 30,
        'duration_seconds': 15.0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await db.insert('video_scenes', {
        'id': 'scene_v5_001',
        'project_id': 'proj_v5_001',
        'scene_index': 0,
        'duration_seconds': 5.0,
        'title': 'Nguyễn Du - Cuộc đời và Sự nghiệp',
        'subtitle': 'Văn học trung đại Việt Nam',
        'transition_type': 'fade',
        'transition_duration_seconds': 0.5,
        'created_at': DateTime.now().toIso8601String(),
      });

      final projectRows = await db.query('video_projects', where: 'id = ?', whereArgs: ['proj_v5_001']);
      expect(projectRows.length, equals(1));
      expect(projectRows.first['name'], equals('Dự án Video Bài Giảng Lịch Sử'));

      final sceneRows = await db.query('video_scenes', where: 'project_id = ?', whereArgs: ['proj_v5_001']);
      expect(sceneRows.length, equals(1));
      expect(sceneRows.first['title'], equals('Nguyễn Du - Cuộc đời và Sự nghiệp'));

      await db.close();
    });
  });
}
