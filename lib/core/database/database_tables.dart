/// DDL schemas and table definitions for NguyenDu Tool local SQLite database.
class DatabaseTables {
  static const String tableAppSettings = 'app_settings';
  static const String tableProjects = 'projects';
  static const String tableFiles = 'files';
  static const String tableJobs = 'jobs';
  static const String tableProviders = 'providers';
  static const String tablePdfJobs = 'pdf_jobs';
  static const String tableOcrCache = 'ocr_cache';

  static const String createAppSettingsTable = '''
    CREATE TABLE IF NOT EXISTS $tableAppSettings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  static const String createProjectsTable = '''
    CREATE TABLE IF NOT EXISTS $tableProjects (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      module_type TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  static const String createFilesTable = '''
    CREATE TABLE IF NOT EXISTS $tableFiles (
      id TEXT PRIMARY KEY,
      project_id TEXT,
      original_name TEXT NOT NULL,
      local_path TEXT NOT NULL,
      mime_type TEXT,
      size INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      FOREIGN KEY (project_id) REFERENCES $tableProjects (id) ON DELETE SET NULL
    );
  ''';

  static const String createJobsTable = '''
    CREATE TABLE IF NOT EXISTS $tableJobs (
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
  ''';

  static const String createProvidersTable = '''
    CREATE TABLE IF NOT EXISTS $tableProviders (
      id TEXT PRIMARY KEY,
      provider_type TEXT NOT NULL,
      provider_name TEXT NOT NULL,
      is_enabled INTEGER NOT NULL DEFAULT 1,
      config_json TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  static const String createPdfJobsTable = '''
    CREATE TABLE IF NOT EXISTS $tablePdfJobs (
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
    CREATE TABLE IF NOT EXISTS $tableOcrCache (
      page_hash TEXT PRIMARY KEY,
      language TEXT NOT NULL,
      ocr_result_json TEXT NOT NULL,
      created_at TEXT NOT NULL
    );
  ''';

  static const String tableScanSessions = 'scan_sessions';
  static const String tableScanPages = 'scan_pages';
  static const String tableScanProfiles = 'scan_profiles';

  static const String createScanSessionsTable = '''
    CREATE TABLE IF NOT EXISTS $tableScanSessions (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      source_type TEXT NOT NULL,
      status TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  static const String createScanPagesTable = '''
    CREATE TABLE IF NOT EXISTS $tableScanPages (
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
      FOREIGN KEY (session_id) REFERENCES $tableScanSessions (id) ON DELETE CASCADE
    );
  ''';

  static const String createScanProfilesTable = '''
    CREATE TABLE IF NOT EXISTS $tableScanProfiles (
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

  static const String tableTtsJobs = 'tts_jobs';
  static const String tableTtsChunks = 'tts_chunks';
  static const String tableTtsPresets = 'tts_presets';
  static const String tablePronunciationDictionary = 'pronunciation_dictionary';

  static const String createTtsJobsTable = '''
    CREATE TABLE IF NOT EXISTS $tableTtsJobs (
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
    CREATE TABLE IF NOT EXISTS $tableTtsChunks (
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
      FOREIGN KEY (job_id) REFERENCES $tableTtsJobs (id) ON DELETE CASCADE
    );
  ''';

  static const String createTtsPresetsTable = '''
    CREATE TABLE IF NOT EXISTS $tableTtsPresets (
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
    CREATE TABLE IF NOT EXISTS $tablePronunciationDictionary (
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

  static const String tableVideoProjects = 'video_projects';
  static const String tableVideoScenes = 'video_scenes';
  static const String tableVideoAssets = 'video_assets';
  static const String tableVideoRenders = 'video_renders';

  static const String createVideoProjectsTable = '''
    CREATE TABLE IF NOT EXISTS $tableVideoProjects (
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
    CREATE TABLE IF NOT EXISTS $tableVideoScenes (
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
      FOREIGN KEY (project_id) REFERENCES $tableVideoProjects (id) ON DELETE CASCADE
    );
  ''';

  static const String createVideoAssetsTable = '''
    CREATE TABLE IF NOT EXISTS $tableVideoAssets (
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
      FOREIGN KEY (project_id) REFERENCES $tableVideoProjects (id) ON DELETE CASCADE
    );
  ''';

  static const String createVideoRendersTable = '''
    CREATE TABLE IF NOT EXISTS $tableVideoRenders (
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
      FOREIGN KEY (project_id) REFERENCES $tableVideoProjects (id) ON DELETE CASCADE
    );
  ''';

  static const List<String> indexStatements = [
    'CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status);',
    'CREATE INDEX IF NOT EXISTS idx_pdf_jobs_status ON pdf_jobs(status);',
    'CREATE INDEX IF NOT EXISTS idx_files_project ON files(project_id);',
    'CREATE INDEX IF NOT EXISTS idx_files_created ON files(created_at);',
    'CREATE INDEX IF NOT EXISTS idx_scan_pages_session ON scan_pages(session_id);',
    'CREATE INDEX IF NOT EXISTS idx_scan_pages_page_index ON scan_pages(session_id, page_index);',
    'CREATE INDEX IF NOT EXISTS idx_scan_sessions_status ON scan_sessions(status);',
    'CREATE INDEX IF NOT EXISTS idx_tts_jobs_status ON tts_jobs(status);',
    'CREATE INDEX IF NOT EXISTS idx_tts_chunks_job ON tts_chunks(job_id);',
    'CREATE INDEX IF NOT EXISTS idx_tts_chunks_job_index ON tts_chunks(job_id, chunk_index);',
    'CREATE INDEX IF NOT EXISTS idx_pronunciation_source ON pronunciation_dictionary(source_phrase);',
    'CREATE INDEX IF NOT EXISTS idx_video_scenes_project ON video_scenes(project_id, scene_index);',
    'CREATE INDEX IF NOT EXISTS idx_video_assets_project ON video_assets(project_id);',
    'CREATE INDEX IF NOT EXISTS idx_video_renders_project ON video_renders(project_id);',
  ];

  static List<String> get allCreationStatements => [
    createAppSettingsTable,
    createProjectsTable,
    createFilesTable,
    createJobsTable,
    createProvidersTable,
    createPdfJobsTable,
    createOcrCacheTable,
    createScanSessionsTable,
    createScanPagesTable,
    createScanProfilesTable,
    createTtsJobsTable,
    createTtsChunksTable,
    createTtsPresetsTable,
    createPronunciationDictionaryTable,
    createVideoProjectsTable,
    createVideoScenesTable,
    createVideoAssetsTable,
    createVideoRendersTable,
    ...indexStatements,
  ];
}
