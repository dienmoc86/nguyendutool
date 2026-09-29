import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../logging/app_logger.dart';

/// Database migration from Schema Version 3 (Document Scanner) to Schema Version 4 (Text to Speech).
class V3ToV4Migration {
  static const String createTtsJobsTable = '''
    CREATE TABLE IF NOT EXISTS tts_jobs (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      input_source TEXT NOT NULL,
      input_path TEXT,
      raw_text TEXT NOT NULL,
      normalized_text TEXT NOT NULL,
      provider_id TEXT NOT NULL,
      voice_id TEXT NOT NULL,
      voice_name TEXT NOT NULL,
      language TEXT NOT NULL,
      audio_format TEXT NOT NULL DEFAULT 'wav',
      speed REAL NOT NULL DEFAULT 1.0,
      pitch REAL NOT NULL DEFAULT 1.0,
      volume REAL NOT NULL DEFAULT 1.0,
      total_chunks INTEGER NOT NULL DEFAULT 0,
      completed_chunks INTEGER NOT NULL DEFAULT 0,
      total_duration_ms INTEGER NOT NULL DEFAULT 0,
      output_audio_path TEXT,
      output_srt_path TEXT,
      output_vtt_path TEXT,
      status TEXT NOT NULL,
      progress REAL NOT NULL DEFAULT 0.0,
      error_message TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  static const String createTtsChunksTable = '''
    CREATE TABLE IF NOT EXISTS tts_chunks (
      id TEXT PRIMARY KEY,
      job_id TEXT NOT NULL,
      chunk_index INTEGER NOT NULL,
      text TEXT NOT NULL,
      character_count INTEGER NOT NULL,
      audio_path TEXT,
      duration_ms INTEGER NOT NULL DEFAULT 0,
      start_ms INTEGER NOT NULL DEFAULT 0,
      end_ms INTEGER NOT NULL DEFAULT 0,
      status TEXT NOT NULL,
      retry_count INTEGER NOT NULL DEFAULT 0,
      error_message TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (job_id) REFERENCES tts_jobs (id) ON DELETE CASCADE
    );
  ''';

  static const String createTtsPresetsTable = '''
    CREATE TABLE IF NOT EXISTS tts_presets (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT,
      voice_id TEXT,
      speed REAL NOT NULL DEFAULT 1.0,
      pitch REAL NOT NULL DEFAULT 1.0,
      volume REAL NOT NULL DEFAULT 1.0,
      paragraph_pause_ms INTEGER NOT NULL DEFAULT 500,
      sentence_pause_ms INTEGER NOT NULL DEFAULT 250,
      audio_format TEXT NOT NULL DEFAULT 'wav',
      is_preset INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    );
  ''';

  static const String createPronunciationDictionaryTable = '''
    CREATE TABLE IF NOT EXISTS pronunciation_dictionary (
      id TEXT PRIMARY KEY,
      source_phrase TEXT NOT NULL UNIQUE,
      replacement_phrase TEXT NOT NULL,
      is_case_sensitive INTEGER NOT NULL DEFAULT 0,
      is_regex INTEGER NOT NULL DEFAULT 0,
      notes TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  static const List<String> indexStatements = [
    'CREATE INDEX IF NOT EXISTS idx_tts_jobs_status ON tts_jobs(status);',
    'CREATE INDEX IF NOT EXISTS idx_tts_chunks_job ON tts_chunks(job_id);',
    'CREATE INDEX IF NOT EXISTS idx_tts_chunks_job_index ON tts_chunks(job_id, chunk_index);',
    'CREATE INDEX IF NOT EXISTS idx_pronunciation_source ON pronunciation_dictionary(source_phrase);',
  ];

  static const List<Map<String, dynamic>> defaultPresets = [
    {
      'id': 'preset_normal',
      'name': 'Đọc chuẩn (Normal Reading)',
      'description': 'Tốc độ 1.0x, cao độ chuẩn, phù hợp bài giảng và sách nói.',
      'voice_id': null,
      'speed': 1.0,
      'pitch': 1.0,
      'volume': 1.0,
      'paragraph_pause_ms': 500,
      'sentence_pause_ms': 250,
      'audio_format': 'wav',
      'is_preset': 1,
    },
    {
      'id': 'preset_slow',
      'name': 'Đọc chậm rãi (Slow Reading)',
      'description': 'Tốc độ 0.75x, ngắt nghỉ rõ ràng cho học sinh luyện đọc.',
      'voice_id': null,
      'speed': 0.75,
      'pitch': 1.0,
      'volume': 1.0,
      'paragraph_pause_ms': 700,
      'sentence_pause_ms': 350,
      'audio_format': 'wav',
      'is_preset': 1,
    },
    {
      'id': 'preset_presentation',
      'name': 'Thuyết trình bài giảng (Presentation)',
      'description': 'Tốc độ 1.1x, sinh động, xuất MP3 nén gọn cho video slide.',
      'voice_id': null,
      'speed': 1.1,
      'pitch': 1.05,
      'volume': 1.0,
      'paragraph_pause_ms': 600,
      'sentence_pause_ms': 300,
      'audio_format': 'mp3',
      'is_preset': 1,
    },
    {
      'id': 'preset_announcement',
      'name': 'Thông báo nhà trường (Announcement)',
      'description': 'Tốc độ 0.9x, giọng dõng dạc, khoảng dừng dài cho phát thanh.',
      'voice_id': null,
      'speed': 0.9,
      'pitch': 1.0,
      'volume': 1.0,
      'paragraph_pause_ms': 800,
      'sentence_pause_ms': 400,
      'audio_format': 'wav',
      'is_preset': 1,
    },
  ];

  static const List<Map<String, dynamic>> defaultPronunciations = [
    {
      'id': 'pronun_nguyendu',
      'source_phrase': 'NguyenDu Tool',
      'replacement_phrase': 'Nguyễn Du Tool',
      'is_case_sensitive': 0,
      'is_regex': 0,
      'notes': 'Tên bộ công cụ trường học',
    },
    {
      'id': 'pronun_stem',
      'source_phrase': 'STEM',
      'replacement_phrase': 'ét tem',
      'is_case_sensitive': 1,
      'is_regex': 0,
      'notes': 'Mô hình giáo dục STEM',
    },
    {
      'id': 'pronun_ai',
      'source_phrase': 'AI',
      'replacement_phrase': 'A I',
      'is_case_sensitive': 1,
      'is_regex': 0,
      'notes': 'Trí tuệ nhân tạo',
    },
    {
      'id': 'pronun_ict',
      'source_phrase': 'ICT',
      'replacement_phrase': 'I C T',
      'is_case_sensitive': 1,
      'is_regex': 0,
      'notes': 'Công nghệ thông tin và truyền thông',
    },
    {
      'id': 'pronun_thcs',
      'source_phrase': 'THCS',
      'replacement_phrase': 'Trung học cơ sở',
      'is_case_sensitive': 1,
      'is_regex': 0,
      'notes': 'Cấp 2',
    },
    {
      'id': 'pronun_thpt',
      'source_phrase': 'THPT',
      'replacement_phrase': 'Trung học phổ thông',
      'is_case_sensitive': 1,
      'is_regex': 0,
      'notes': 'Cấp 3',
    },
    {
      'id': 'pronun_tphcm',
      'source_phrase': 'TP.HCM',
      'replacement_phrase': 'thành phố Hồ Chí Minh',
      'is_case_sensitive': 0,
      'is_regex': 0,
      'notes': 'Địa danh TP.HCM',
    },
  ];

  /// Executes migration logic on the target SQLite database instance.
  static Future<void> migrate(Database db) async {
    AppLogger.info('Starting SQLite migration: v3 -> v4 (Text to Speech tables & dictionary)...');

    await db.execute(createTtsJobsTable);
    await db.execute(createTtsChunksTable);
    await db.execute(createTtsPresetsTable);
    await db.execute(createPronunciationDictionaryTable);

    for (final idx in indexStatements) {
      await db.execute(idx);
    }

    final now = DateTime.now().toIso8601String();

    // Seed default presets
    for (final preset in defaultPresets) {
      await db.insert(
        'tts_presets',
        {
          ...preset,
          'created_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    // Seed default pronunciation dictionary
    for (final pronun in defaultPronunciations) {
      await db.insert(
        'pronunciation_dictionary',
        {
          ...pronun,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    AppLogger.info('SQLite migration v3 -> v4 completed successfully.');
  }
}
