import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/database/database_backup_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

int? firstIntValue(List<Map<String, Object?>> list) {
  if (list.isEmpty) return null;
  return list.first.values.first as int?;
}

void main() {
  sqfliteFfiInit();

  group('Real SQLite Safe Backup & Integrity Verification (Requirements 26 & 27)', () {
    late Directory tempDir;
    late File primaryDbFile;
    late Directory backupsDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('nguyendu_sqlite_backup_test_');
      primaryDbFile = File(p.join(tempDir.path, 'primary.db'));
      backupsDir = Directory(p.join(tempDir.path, 'backups'));
      await backupsDir.create();
    });

    tearDown(() async {
      try {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    test('Real SQLite database WAL active backup, integrity check and restore', () async {
      final db = await databaseFactoryFfi.openDatabase(primaryDbFile.path);

      // Enable WAL journal mode
      final walRes = await db.rawQuery('PRAGMA journal_mode = WAL;');
      expect(walRes.first.values.first.toString().toLowerCase(), 'wal');

      // Create table and insert rows
      await db.execute('CREATE TABLE documents (id TEXT PRIMARY KEY, title TEXT, size_bytes INTEGER);');
      for (int i = 1; i <= 50; i++) {
        await db.insert('documents', {
          'id': 'doc_$i',
          'title': 'Tài liệu bài giảng số $i',
          'size_bytes': 1024 * i,
        });
      }

      // Ensure WAL has uncheckpointed data
      final rowCountBefore = firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM documents;'));
      expect(rowCountBefore, 50);

      // Create safe backup while DB is ACTIVE
      final backupService = DatabaseBackupService(
        databaseFile: primaryDbFile,
        backupsDirectory: backupsDir,
        activeDb: db,
      );

      final backupFile = await backupService.createBackup(reason: 'unit_test_active_wal');
      expect(backupFile, isNotNull);
      expect(backupFile!.existsSync(), isTrue);

      // Keep writing more to primary DB after backup
      await db.insert('documents', {'id': 'doc_post_backup', 'title': 'Added after backup', 'size_bytes': 999});
      expect(firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM documents;')), 51);

      // Reopen backup file independently and verify
      final verifyDb = await databaseFactoryFfi.openDatabase(
        backupFile.path,
        options: OpenDatabaseOptions(readOnly: true),
      );

      // 1. Verify PRAGMA integrity_check == ok
      final integrityRes = await verifyDb.rawQuery('PRAGMA integrity_check;');
      expect(integrityRes.first.values.first.toString().toLowerCase(), 'ok');

      // 2. Verify all 50 original rows are present
      final backupRowCount = firstIntValue(await verifyDb.rawQuery('SELECT COUNT(*) FROM documents;'));
      expect(backupRowCount, 50);

      // 3. Verify data consistency
      final row25 = await verifyDb.query('documents', where: 'id = ?', whereArgs: ['doc_25']);
      expect(row25.first['title'], 'Tài liệu bài giảng số 25');

      await verifyDb.close();
      await db.close();

      // Test Restore
      final restoreService = DatabaseBackupService(
        databaseFile: primaryDbFile,
        backupsDirectory: backupsDir,
      );

      final restored = await restoreService.restoreFromBackup(backupFile);
      expect(restored, isTrue);

      // Open primary DB again and verify it has restored snapshot (50 rows, not 51)
      final restoredDb = await databaseFactoryFfi.openDatabase(primaryDbFile.path);
      final restoredCount = firstIntValue(await restoredDb.rawQuery('SELECT COUNT(*) FROM documents;'));
      expect(restoredCount, 50);
      await restoredDb.close();
    });

    test('Refuse to restore corrupted backup (Requirement 29)', () async {
      final corruptBackup = File(p.join(backupsDir.path, 'nguyendu_tool_backup_corrupted.db'));
      // Write random corrupted garbage bytes
      await corruptBackup.writeAsString('NOT A REAL SQLITE DATABASE HEADER GIBBERISH DATA');

      final backupService = DatabaseBackupService(
        databaseFile: primaryDbFile,
        backupsDirectory: backupsDir,
      );

      final isHealthy = await DatabaseBackupService.verifyIntegrity(corruptBackup);
      expect(isHealthy, isFalse);

      final restored = await backupService.restoreFromBackup(corruptBackup);
      expect(restored, isFalse, reason: 'Must refuse to restore corrupted backup!');
    });
  });
}
