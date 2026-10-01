import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../logging/app_logger.dart';

/// Database migration from Schema Version 5 (Video Studio) to Schema Version 6 (Product Expansion Foundation).
///
/// Adds:
/// - `workspace_projects`: Unified workspace project model for teaching suites & multimedia.
/// - `project_artifacts`: Relationships linking outputs (DOCX, PPTX, PDF, MP4, MP3) to projects.
/// - `module_usage`: Local persistence for module favorites and recent usage tracking.
class V5ToV6Migration {
  static const String createWorkspaceProjectsTable = '''
    CREATE TABLE IF NOT EXISTS workspace_projects (
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
    CREATE TABLE IF NOT EXISTS project_artifacts (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      artifact_type TEXT NOT NULL,
      file_id TEXT,
      file_path TEXT,
      created_at TEXT NOT NULL,
      metadata_json TEXT,
      FOREIGN KEY (project_id) REFERENCES workspace_projects (id) ON DELETE CASCADE
    );
  ''';

  static const String createModuleUsageTable = '''
    CREATE TABLE IF NOT EXISTS module_usage (
      module_id TEXT PRIMARY KEY,
      open_count INTEGER NOT NULL DEFAULT 0,
      last_opened_at TEXT NOT NULL,
      is_favorite INTEGER NOT NULL DEFAULT 0
    );
  ''';

  static const List<String> indexes = [
    'CREATE INDEX IF NOT EXISTS idx_workspace_projects_type ON workspace_projects(type);',
    'CREATE INDEX IF NOT EXISTS idx_workspace_projects_updated ON workspace_projects(updated_at);',
    'CREATE INDEX IF NOT EXISTS idx_project_artifacts_project ON project_artifacts(project_id);',
    'CREATE INDEX IF NOT EXISTS idx_project_artifacts_type ON project_artifacts(artifact_type);',
    'CREATE INDEX IF NOT EXISTS idx_module_usage_last_opened ON module_usage(last_opened_at);',
    'CREATE INDEX IF NOT EXISTS idx_module_usage_is_favorite ON module_usage(is_favorite);',
  ];

  static Future<void> migrate(Database db) async {
    AppLogger.info('Starting SQLite Schema v5 -> v6 migration (Phase 6A)...');

    await db.transaction((txn) async {
      await txn.execute(createWorkspaceProjectsTable);
      await txn.execute(createProjectArtifactsTable);
      await txn.execute(createModuleUsageTable);

      for (final sql in indexes) {
        await txn.execute(sql);
      }
    });

    AppLogger.info('Schema v5 -> v6 migration completed successfully.');
  }
}
