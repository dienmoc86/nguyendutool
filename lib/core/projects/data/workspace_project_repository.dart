import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../database/app_database.dart';
import '../../database/database_tables.dart';
import '../../errors/app_exceptions.dart';
import '../domain/project_artifact.dart';
import '../domain/project_type.dart';
import '../domain/workspace_project.dart';

/// Repository managing cross-module WorkspaceProjects in SQLite.
class WorkspaceProjectRepository {
  final AppDatabase? _appDatabase;
  final Database? _rawDb;

  WorkspaceProjectRepository({AppDatabase? appDatabase})
      : _appDatabase = appDatabase ?? AppDatabase(),
        _rawDb = null;

  WorkspaceProjectRepository.withDb(Database db)
      : _appDatabase = null,
        _rawDb = db;

  Future<Database> get _db async => _rawDb ?? await _appDatabase!.database;

  /// Creates a new WorkspaceProject. Aborts on conflict to prevent cascade loss.
  Future<void> createProject(WorkspaceProject project) async {
    final db = await _db;
    await db.insert(
      DatabaseTables.tableWorkspaceProjects,
      project.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// Updates an existing WorkspaceProject.
  Future<void> updateProject(WorkspaceProject project) async {
    final db = await _db;
    await db.update(
      DatabaseTables.tableWorkspaceProjects,
      project.toMap(),
      where: 'id = ?',
      whereArgs: [project.id],
    );
  }

  /// Saves or updates a WorkspaceProject safely without triggering cascade deletes.
  Future<void> saveProject(WorkspaceProject project) async {
    final db = await _db;
    await db.transaction((txn) async {
      final existing = await txn.query(
        DatabaseTables.tableWorkspaceProjects,
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [project.id],
        limit: 1,
      );
      if (existing.isEmpty) {
        await txn.insert(
          DatabaseTables.tableWorkspaceProjects,
          project.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      } else {
        await txn.update(
          DatabaseTables.tableWorkspaceProjects,
          project.toMap(),
          where: 'id = ?',
          whereArgs: [project.id],
        );
      }
    });
  }

  /// Retrieves a WorkspaceProject by ID.
  Future<WorkspaceProject?> getProject(String id) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseTables.tableWorkspaceProjects,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return WorkspaceProject.fromMap(rows.first);
  }

  /// Lists all WorkspaceProjects, optionally filtered by ProjectType.
  Future<List<WorkspaceProject>> listProjects({ProjectType? type, String? status}) async {
    final db = await _db;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (type != null) {
      whereClauses.add('type = ?');
      whereArgs.add(type.id);
    }
    if (status != null) {
      whereClauses.add('status = ?');
      whereArgs.add(status);
    }

    final whereString = whereClauses.isEmpty ? null : whereClauses.join(' AND ');
    final rows = await db.query(
      DatabaseTables.tableWorkspaceProjects,
      where: whereString,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'updated_at DESC',
    );

    return rows.map((r) => WorkspaceProject.fromMap(r)).toList();
  }

  /// Checks if a project contains any finalized exams (Section 8).
  Future<bool> hasFinalizedExams(String projectId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseTables.tableExamPapers} WHERE project_id = ? AND is_finalized = 1',
      [projectId],
    );
    final count = rows.isNotEmpty ? (rows.first['count'] as int? ?? 0) : 0;
    return count > 0;
  }

  /// Soft-deletes / archives a project instead of physical deletion (Section 8).
  Future<void> archiveProject(String id) async {
    final db = await _db;
    await db.update(
      DatabaseTables.tableWorkspaceProjects,
      {'status': 'archived', 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Safely deletes project metadata without deleting external physical files.
  /// If the project contains finalized exams and [force] is false, throws [ProjectHasFinalizedExamsException].
  Future<void> deleteProject(String id, {bool force = false}) async {
    final db = await _db;
    if (!force && await hasFinalizedExams(id)) {
      throw ProjectHasFinalizedExamsException(
        'Cannot delete project $id containing finalized exams without explicit force confirmation.',
        projectId: id,
      );
    }
    await db.transaction((txn) async {
      await txn.delete(
        DatabaseTables.tableProjectArtifacts,
        where: 'project_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        DatabaseTables.tableWorkspaceProjects,
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  /// Attaches an artifact to a project without replacing parent rows.
  Future<void> attachArtifact(ProjectArtifact artifact) async {
    final db = await _db;
    await db.transaction((txn) async {
      final existing = await txn.query(
        DatabaseTables.tableProjectArtifacts,
        where: 'id = ?',
        whereArgs: [artifact.id],
        limit: 1,
      );
      if (existing.isEmpty) {
        await txn.insert(
          DatabaseTables.tableProjectArtifacts,
          artifact.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      } else {
        await txn.update(
          DatabaseTables.tableProjectArtifacts,
          artifact.toMap(),
          where: 'id = ?',
          whereArgs: [artifact.id],
        );
      }
    });
  }

  /// Lists all artifacts associated with a project.
  Future<List<ProjectArtifact>> listArtifacts(String projectId) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseTables.tableProjectArtifacts,
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'created_at ASC',
    );
    return rows.map((r) => ProjectArtifact.fromMap(r)).toList();
  }

  /// Removes an artifact relationship.
  Future<void> removeArtifact(String artifactId) async {
    final db = await _db;
    await db.delete(
      DatabaseTables.tableProjectArtifacts,
      where: 'id = ?',
      whereArgs: [artifactId],
    );
  }

  /// Alias for removeArtifact.
  Future<void> deleteArtifact(String artifactId) => removeArtifact(artifactId);
}
