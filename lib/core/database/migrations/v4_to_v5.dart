import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../logging/app_logger.dart';

/// Database migration from Schema Version 4 (Text to Speech) to Schema Version 5 (Video Studio).
class V4ToV5Migration {
  static const String createVideoProjectsTable = '''
    CREATE TABLE IF NOT EXISTS video_projects (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      aspect_ratio TEXT NOT NULL,
      resolution TEXT NOT NULL,
      fps INTEGER NOT NULL DEFAULT 30,
      duration_seconds REAL NOT NULL DEFAULT 0.0,
      background_music_path TEXT,
      background_music_volume REAL NOT NULL DEFAULT 0.35,
      background_music_loop INTEGER NOT NULL DEFAULT 1,
      audio_ducking TEXT NOT NULL DEFAULT 'medium',
      export_settings_json TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  static const String createVideoScenesTable = '''
    CREATE TABLE IF NOT EXISTS video_scenes (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      scene_index INTEGER NOT NULL,
      duration_seconds REAL NOT NULL DEFAULT 5.0,
      background_image_path TEXT,
      video_clip_path TEXT,
      clip_trim_start_seconds REAL NOT NULL DEFAULT 0.0,
      clip_trim_end_seconds REAL,
      clip_mute_original_audio INTEGER NOT NULL DEFAULT 0,
      image_fit_mode TEXT NOT NULL DEFAULT 'fit',
      blur_background INTEGER NOT NULL DEFAULT 1,
      ken_burns TEXT NOT NULL DEFAULT 'none',
      transition_type TEXT NOT NULL DEFAULT 'fade',
      transition_duration_seconds REAL NOT NULL DEFAULT 0.5,
      title TEXT,
      subtitle TEXT,
      body_text TEXT,
      narration_text TEXT,
      voiceover_audio_path TEXT,
      voiceover_duration_seconds REAL,
      subtitle_segments_json TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (project_id) REFERENCES video_projects (id) ON DELETE CASCADE
    );
  ''';

  static const String createVideoAssetsTable = '''
    CREATE TABLE IF NOT EXISTS video_assets (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      name TEXT NOT NULL,
      path TEXT NOT NULL,
      media_type TEXT NOT NULL,
      width INTEGER,
      height INTEGER,
      duration_ms INTEGER,
      file_size INTEGER NOT NULL,
      mime_type TEXT,
      imported_at TEXT NOT NULL,
      FOREIGN KEY (project_id) REFERENCES video_projects (id) ON DELETE CASCADE
    );
  ''';

  static const String createVideoRendersTable = '''
    CREATE TABLE IF NOT EXISTS video_renders (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      output_mp4_path TEXT NOT NULL,
      resolution TEXT NOT NULL,
      fps INTEGER NOT NULL,
      duration_seconds REAL NOT NULL,
      file_size_bytes INTEGER NOT NULL,
      render_time_seconds REAL NOT NULL,
      hardware_encoder TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (project_id) REFERENCES video_projects (id) ON DELETE CASCADE
    );
  ''';

  static Future<void> migrate(Database db) async {
    AppLogger.info('Executing SQLite migration v4 -> v5 (Video Studio)...');

    await db.transaction((txn) async {
      await txn.execute(createVideoProjectsTable);
      await txn.execute(createVideoScenesTable);
      await txn.execute(createVideoAssetsTable);
      await txn.execute(createVideoRendersTable);

      // Indexes for fast lookup by project_id and scene_index
      await txn.execute('CREATE INDEX IF NOT EXISTS idx_video_scenes_project ON video_scenes(project_id, scene_index);');
      await txn.execute('CREATE INDEX IF NOT EXISTS idx_video_assets_project ON video_assets(project_id);');
      await txn.execute('CREATE INDEX IF NOT EXISTS idx_video_renders_project ON video_renders(project_id);');
    });

    AppLogger.info('SQLite migration v4 -> v5 completed successfully.');
  }
}
