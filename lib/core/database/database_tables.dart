/// DDL schemas and table definitions for NguyenDu Tool local SQLite database.
class DatabaseTables {
  static const String tableAppSettings = 'app_settings';
  static const String tableProjects = 'projects';
  static const String tableFiles = 'files';
  static const String tableJobs = 'jobs';
  static const String tableProviders = 'providers';
  static const String tablePdfJobs = 'pdf_jobs';
  static const String tableOcrCache = 'ocr_cache';
  static const String tableWorkspaceProjects = 'workspace_projects';
  static const String tableProjectArtifacts = 'project_artifacts';
  static const String tableModuleUsage = 'module_usage';
  static const String tableQuestionSets = 'question_sets';
  static const String tableQuestionItems = 'question_items';
  static const String tableRubrics = 'rubrics';
  static const String tableLessonPlanDrafts = 'lesson_plan_drafts';
  static const String tableWorksheets = 'worksheets';
  static const String tableWorksheetTasks = 'worksheet_tasks';
  static const String tableMiniAssessments = 'mini_assessments';
  static const String tableMiniAssessmentItems = 'mini_assessment_items';
  static const String tableLearningObjectives = 'learning_objectives';
  static const String tableExamSpecifications = 'exam_specifications';
  static const String tableExamMatrixCells = 'exam_matrix_cells';
  static const String tableExamPapers = 'exam_papers';
  static const String tableExamPaperQuestions = 'exam_paper_questions';
  static const String tableExamCodes = 'exam_codes';
  static const String tableExamCodeQuestions = 'exam_code_questions';

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

  static const String createWorkspaceProjectsTable = '''
    CREATE TABLE IF NOT EXISTS $tableWorkspaceProjects (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      name TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'active',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      metadata_json TEXT,
      thumbnail_path TEXT
    );
  ''';

  static const String createProjectArtifactsTable = '''
    CREATE TABLE IF NOT EXISTS $tableProjectArtifacts (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      artifact_type TEXT NOT NULL,
      file_id TEXT,
      file_path TEXT,
      created_at TEXT NOT NULL,
      metadata_json TEXT,
      FOREIGN KEY (project_id) REFERENCES $tableWorkspaceProjects (id) ON DELETE CASCADE
    );
  ''';

  static const String createModuleUsageTable = '''
    CREATE TABLE IF NOT EXISTS $tableModuleUsage (
      module_id TEXT PRIMARY KEY,
      open_count INTEGER NOT NULL DEFAULT 0,
      last_opened_at TEXT NOT NULL,
      is_favorite INTEGER NOT NULL DEFAULT 0
    );
  ''';

  static const String createQuestionSetsTable = '''
    CREATE TABLE IF NOT EXISTS $tableQuestionSets (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      title TEXT NOT NULL,
      subject TEXT NOT NULL,
      grade TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      metadata_json TEXT,
      FOREIGN KEY (project_id) REFERENCES $tableWorkspaceProjects (id) ON DELETE CASCADE
    );
  ''';

  static const String createQuestionItemsTable = '''
    CREATE TABLE IF NOT EXISTS $tableQuestionItems (
      id TEXT PRIMARY KEY,
      set_id TEXT NOT NULL,
      type TEXT NOT NULL,
      prompt TEXT NOT NULL,
      choices_json TEXT,
      correct_answer TEXT NOT NULL,
      explanation TEXT,
      difficulty TEXT NOT NULL,
      objective_id TEXT,
      order_index INTEGER NOT NULL DEFAULT 0,
      metadata_json TEXT,
      FOREIGN KEY (set_id) REFERENCES $tableQuestionSets (id) ON DELETE CASCADE
    );
  ''';

  static const String createRubricsTable = '''
    CREATE TABLE IF NOT EXISTS $tableRubrics (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      title TEXT NOT NULL,
      criteria_json TEXT NOT NULL,
      total_weight REAL NOT NULL DEFAULT 100.0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (project_id) REFERENCES $tableWorkspaceProjects (id) ON DELETE CASCADE
    );
  ''';

  static const String createLessonPlanDraftsTable = '''
    CREATE TABLE IF NOT EXISTS $tableLessonPlanDrafts (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL UNIQUE,
      document_json TEXT NOT NULL,
      prompt_version TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (project_id) REFERENCES $tableWorkspaceProjects (id) ON DELETE CASCADE
    );
  ''';

  static const String createWorksheetsTable = '''
    CREATE TABLE IF NOT EXISTS $tableWorksheets (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      title TEXT NOT NULL,
      preset TEXT,
      duration INTEGER DEFAULT 45,
      teacher_notes TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (project_id) REFERENCES $tableWorkspaceProjects (id) ON DELETE CASCADE
    );
  ''';

  static const String createWorksheetTasksTable = '''
    CREATE TABLE IF NOT EXISTS $tableWorksheetTasks (
      id TEXT PRIMARY KEY,
      worksheet_id TEXT NOT NULL,
      instruction TEXT NOT NULL,
      content TEXT NOT NULL,
      task_type TEXT NOT NULL,
      points REAL DEFAULT 1.0,
      order_index INTEGER NOT NULL DEFAULT 0,
      answer_hint TEXT,
      FOREIGN KEY (worksheet_id) REFERENCES $tableWorksheets (id) ON DELETE CASCADE
    );
  ''';

  static const String createMiniAssessmentsTable = '''
    CREATE TABLE IF NOT EXISTS $tableMiniAssessments (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      source_question_set_id TEXT,
      title TEXT NOT NULL,
      duration INTEGER DEFAULT 15,
      created_at TEXT NOT NULL,
      FOREIGN KEY (project_id) REFERENCES $tableWorkspaceProjects (id) ON DELETE CASCADE
    );
  ''';

  static const String createMiniAssessmentItemsTable = '''
    CREATE TABLE IF NOT EXISTS $tableMiniAssessmentItems (
      id TEXT PRIMARY KEY,
      mini_assessment_id TEXT NOT NULL,
      question_id TEXT NOT NULL,
      order_index INTEGER NOT NULL DEFAULT 0,
      snapshot_json TEXT,
      FOREIGN KEY (mini_assessment_id) REFERENCES $tableMiniAssessments (id) ON DELETE CASCADE
    );
  ''';

  static const String createLearningObjectivesTable = '''
    CREATE TABLE IF NOT EXISTS $tableLearningObjectives (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      code TEXT NOT NULL,
      description TEXT NOT NULL,
      category TEXT,
      order_index INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (project_id) REFERENCES $tableWorkspaceProjects (id) ON DELETE CASCADE
    );
  ''';

  static const String createExamSpecificationsTable = '''
    CREATE TABLE IF NOT EXISTS $tableExamSpecifications (
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
      FOREIGN KEY (project_id) REFERENCES $tableWorkspaceProjects (id) ON DELETE CASCADE
    );
  ''';

  static const String createExamMatrixCellsTable = '''
    CREATE TABLE IF NOT EXISTS $tableExamMatrixCells (
      id TEXT PRIMARY KEY,
      specification_id TEXT NOT NULL,
      objective_id TEXT NOT NULL,
      difficulty TEXT NOT NULL,
      question_count INTEGER NOT NULL DEFAULT 0,
      score_per_question REAL NOT NULL DEFAULT 0.0,
      question_type_distribution_json TEXT,
      FOREIGN KEY (specification_id) REFERENCES $tableExamSpecifications (id) ON DELETE CASCADE
    );
  ''';

  static const String createExamPapersTable = '''
    CREATE TABLE IF NOT EXISTS $tableExamPapers (
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
      FOREIGN KEY (project_id) REFERENCES $tableWorkspaceProjects (id) ON DELETE CASCADE
    );
  ''';

  static const String createExamPaperQuestionsTable = '''
    CREATE TABLE IF NOT EXISTS $tableExamPaperQuestions (
      id TEXT PRIMARY KEY,
      exam_paper_id TEXT NOT NULL,
      question_id TEXT NOT NULL,
      order_index INTEGER NOT NULL DEFAULT 0,
      score REAL NOT NULL DEFAULT 0.0,
      section_index INTEGER NOT NULL DEFAULT 0,
      snapshot_json TEXT NOT NULL,
      FOREIGN KEY (exam_paper_id) REFERENCES $tableExamPapers (id) ON DELETE CASCADE
    );
  ''';

  static const String createExamCodesTable = '''
    CREATE TABLE IF NOT EXISTS $tableExamCodes (
      id TEXT PRIMARY KEY,
      exam_paper_id TEXT NOT NULL,
      code TEXT NOT NULL,
      created_at TEXT NOT NULL,
      FOREIGN KEY (exam_paper_id) REFERENCES $tableExamPapers (id) ON DELETE CASCADE
    );
  ''';

  static const String createExamCodeQuestionsTable = '''
    CREATE TABLE IF NOT EXISTS $tableExamCodeQuestions (
      id TEXT PRIMARY KEY,
      exam_code_id TEXT NOT NULL,
      question_id TEXT NOT NULL,
      order_index INTEGER NOT NULL DEFAULT 0,
      score REAL NOT NULL DEFAULT 0.0,
      correct_display_answer TEXT NOT NULL,
      choice_order_json TEXT,
      snapshot_json TEXT NOT NULL,
      FOREIGN KEY (exam_code_id) REFERENCES $tableExamCodes (id) ON DELETE CASCADE
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
    'CREATE INDEX IF NOT EXISTS idx_workspace_projects_type ON workspace_projects(type);',
    'CREATE INDEX IF NOT EXISTS idx_workspace_projects_updated ON workspace_projects(updated_at);',
    'CREATE INDEX IF NOT EXISTS idx_project_artifacts_project ON project_artifacts(project_id);',
    'CREATE INDEX IF NOT EXISTS idx_project_artifacts_type ON project_artifacts(artifact_type);',
    'CREATE INDEX IF NOT EXISTS idx_module_usage_last_opened ON module_usage(last_opened_at);',
    'CREATE INDEX IF NOT EXISTS idx_module_usage_is_favorite ON module_usage(is_favorite);',
    'CREATE INDEX IF NOT EXISTS idx_question_sets_project ON question_sets(project_id);',
    'CREATE INDEX IF NOT EXISTS idx_question_items_set ON question_items(set_id);',
    'CREATE INDEX IF NOT EXISTS idx_question_items_type ON question_items(type);',
    'CREATE INDEX IF NOT EXISTS idx_question_items_difficulty ON question_items(difficulty);',
    'CREATE INDEX IF NOT EXISTS idx_rubrics_project ON rubrics(project_id);',
    'CREATE INDEX IF NOT EXISTS idx_lesson_plan_drafts_project ON lesson_plan_drafts(project_id);',
    'CREATE INDEX IF NOT EXISTS idx_worksheets_project ON worksheets(project_id);',
    'CREATE INDEX IF NOT EXISTS idx_worksheet_tasks_worksheet ON worksheet_tasks(worksheet_id);',
    'CREATE INDEX IF NOT EXISTS idx_mini_assessments_project ON mini_assessments(project_id);',
    'CREATE INDEX IF NOT EXISTS idx_mini_assessment_items_assessment ON mini_assessment_items(mini_assessment_id);',
    'CREATE INDEX IF NOT EXISTS idx_learning_objectives_project ON learning_objectives(project_id);',
    'CREATE INDEX IF NOT EXISTS idx_exam_specs_project ON exam_specifications(project_id);',
    'CREATE INDEX IF NOT EXISTS idx_exam_matrix_spec ON exam_matrix_cells(specification_id);',
    'CREATE INDEX IF NOT EXISTS idx_exam_papers_project ON exam_papers(project_id);',
    'CREATE INDEX IF NOT EXISTS idx_exam_paper_questions_paper ON exam_paper_questions(exam_paper_id);',
    'CREATE INDEX IF NOT EXISTS idx_exam_codes_paper ON exam_codes(exam_paper_id);',
    'CREATE INDEX IF NOT EXISTS idx_exam_code_questions_code ON exam_code_questions(exam_code_id);',
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
    createWorkspaceProjectsTable,
    createProjectArtifactsTable,
    createModuleUsageTable,
    createQuestionSetsTable,
    createQuestionItemsTable,
    createRubricsTable,
    createLessonPlanDraftsTable,
    createWorksheetsTable,
    createWorksheetTasksTable,
    createMiniAssessmentsTable,
    createMiniAssessmentItemsTable,
    createLearningObjectivesTable,
    createExamSpecificationsTable,
    createExamMatrixCellsTable,
    createExamPapersTable,
    createExamPaperQuestionsTable,
    createExamCodesTable,
    createExamCodeQuestionsTable,
    ...indexStatements,
  ];
}
