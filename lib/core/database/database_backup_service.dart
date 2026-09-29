import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide DatabaseException;
import '../errors/app_exceptions.dart';
import '../logging/app_logger.dart';

/// Supported user/system recovery decisions when database corruption is detected.
enum DatabaseRecoveryAction {
  /// Retry opening the database.
  retry,

  /// Restore the database from the most recent valid backup.
  restoreBackup,

  /// Reinitialize a brand new clean database (preserves corrupt DB as diagnostic artifact).
  createNewDatabase,
}

/// Manages automated database snapshots, rolling retention (last 5 backups),
/// and corruption recovery pathways (Requirements 26, 27, 28, 29).
/// Uses SQLite transactional VACUUM INTO and explicit PRAGMA integrity_check validation.
class DatabaseBackupService {
  final File databaseFile;
  final Directory backupsDirectory;
  final Database? activeDb;
  final int maxRetention;

  DatabaseBackupService({
    required this.databaseFile,
    required this.backupsDirectory,
    this.activeDb,
    this.maxRetention = 5,
  });

  /// Verifies SQLite database file health using PRAGMA integrity_check.
  static Future<bool> verifyIntegrity(File dbFile) async {
    if (!dbFile.existsSync()) return false;
    Database? db;
    try {
      sqfliteFfiInit();
      db = await databaseFactoryFfi.openDatabase(
        dbFile.path,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      final result = await db.rawQuery('PRAGMA integrity_check;');
      final status = result.isNotEmpty ? result.first.values.first.toString().toLowerCase() : '';
      return status == 'ok';
    } catch (e) {
      AppLogger.warning('Integrity verification failed for ${dbFile.path}: $e');
      return false;
    } finally {
      if (db != null && db.isOpen) {
        await db.close();
      }
    }
  }

  /// Creates a consistent, transactional SQLite backup snapshot using VACUUM INTO
  /// and validates it with PRAGMA integrity_check.
  /// Enforces maximum retention limit by pruning older backup copies.
  Future<File?> createBackup({String reason = 'auto'}) async {
    try {
      if (!databaseFile.existsSync()) {
        AppLogger.warning('DatabaseBackupService: Cannot backup non-existent database: ${databaseFile.path}');
        return null;
      }

      await backupsDirectory.create(recursive: true);

      final ts = DateFormat('yyyyMMdd_HHmmss_SSS').format(DateTime.now());
      final sanitizedReason = reason.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final backupFileName = 'nguyendu_tool_backup_${ts}_$sanitizedReason.db';
      final backupFile = File(p.join(backupsDirectory.path, backupFileName));

      sqfliteFfiInit();

      // If an active DB connection is provided, use transactional VACUUM INTO
      if (activeDb != null && activeDb!.isOpen) {
        try {
          await activeDb!.execute('PRAGMA wal_checkpoint(TRUNCATE);');
        } catch (_) {}

        final escapedPath = backupFile.path.replaceAll("'", "''");
        await activeDb!.execute("VACUUM INTO '$escapedPath';");
      } else {
        // Cold backup via standalone connection
        Database? tempDb;
        try {
          tempDb = await databaseFactoryFfi.openDatabase(
            databaseFile.path,
            options: OpenDatabaseOptions(singleInstance: false),
          );
          try {
            await tempDb.execute('PRAGMA wal_checkpoint(TRUNCATE);');
          } catch (_) {}
          final escapedPath = backupFile.path.replaceAll("'", "''");
          await tempDb.execute("VACUUM INTO '$escapedPath';");
        } finally {
          if (tempDb != null && tempDb.isOpen) {
            await tempDb.close();
          }
        }
      }

      // Mandatory Requirement 26: Validate backup with PRAGMA integrity_check
      final isHealthy = await verifyIntegrity(backupFile);
      if (!isHealthy) {
        if (backupFile.existsSync()) await backupFile.delete();
        throw AppDatabaseException(
          'Tệp sao lưu vừa tạo không vượt qua kiểm tra toàn vẹn PRAGMA integrity_check: ${backupFile.path}',
        );
      }

      AppLogger.info('SQLite consistent backup created & verified: ${backupFile.path} (Size: ${backupFile.lengthSync()} bytes, Reason: $reason)');

      // Prune old backups exceeding maxRetention
      await _pruneOldBackups();

      return backupFile;
    } catch (e, st) {
      AppLogger.error('Failed creating consistent database backup: $e', e, st);
      return null;
    }
  }

  /// Lists all available backups sorted from newest to oldest.
  List<File> listBackups() {
    if (!backupsDirectory.existsSync()) return [];
    final files = backupsDirectory
        .listSync(followLinks: false)
        .whereType<File>()
        .where((f) => f.path.endsWith('.db') && p.basename(f.path).startsWith('nguyendu_tool_backup_'))
        .toList();

    // Lexicographical filename sort (since yyyyMMdd_HHmmss_SSS is chronological)
    files.sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
    return files;
  }

  /// Prunes older backup snapshots to respect maximum retention limit (default: 5).
  Future<int> _pruneOldBackups() async {
    final backups = listBackups();
    if (backups.length <= maxRetention) return 0;

    int deletedCount = 0;
    for (int i = maxRetention; i < backups.length; i++) {
      try {
        final b = backups[i];
        if (b.existsSync()) await b.delete();
        deletedCount++;
      } catch (e) {
        AppLogger.warning('Failed pruning old backup: $e');
      }
    }
    if (deletedCount > 0) {
      AppLogger.info('Pruned $deletedCount older database backups (retaining newest $maxRetention).');
    }
    return deletedCount;
  }

  /// Restores the database from a designated backup snapshot (Requirement 29).
  /// Enforces integrity validation before restore, and preserves corrupt database for diagnostics.
  Future<bool> restoreFromBackup(File backupFile) async {
    try {
      if (!backupFile.existsSync()) {
        throw ArgumentError('Tệp sao lưu không tồn tại: ${backupFile.path}');
      }

      // Mandatory Requirement 29: Validate backup before restore!
      final isValid = await verifyIntegrity(backupFile);
      if (!isValid) {
        throw const AppDatabaseException('Tệp sao lưu bị hỏng cấu trúc (PRAGMA integrity_check != ok). Hủy khôi phục.');
      }

      // Preserve corrupt / current database for forensic diagnostics
      if (databaseFile.existsSync()) {
        final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final corruptArchive = File(p.join(
          backupsDirectory.path,
          'nguyendu_tool_corrupt_$ts.db',
        ));
        await databaseFile.copy(corruptArchive.path);
        AppLogger.warning('Preserved corrupted database before restore at: ${corruptArchive.path}');

        try {
          await databaseFile.delete();
          final wal = File('${databaseFile.path}-wal');
          if (wal.existsSync()) await wal.delete();
          final shm = File('${databaseFile.path}-shm');
          if (shm.existsSync()) await shm.delete();
        } catch (_) {}
      }

      // Copy backup file to primary database path
      await backupFile.copy(databaseFile.path);

      // Verify the restored database
      final restoredValid = await verifyIntegrity(databaseFile);
      if (!restoredValid) {
        throw const AppDatabaseException('Cơ sở dữ liệu sau khi khôi phục không vượt qua kiểm tra toàn vẹn.');
      }

      AppLogger.info('Database restored and verified successfully from: ${backupFile.path}');
      return true;
    } catch (e, st) {
      AppLogger.error('Failed restoring database from backup: $e', e, st);
      return false;
    }
  }

  /// Restores the most recent valid backup available.
  Future<bool> restoreLatestBackup() async {
    final backups = listBackups();
    if (backups.isEmpty) {
      AppLogger.warning('No database backups available to restore.');
      return false;
    }

    for (final backup in backups) {
      if (await verifyIntegrity(backup)) {
        return await restoreFromBackup(backup);
      }
    }

    AppLogger.error('No valid healthy database backups found to restore.');
    return false;
  }
}
