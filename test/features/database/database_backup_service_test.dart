import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:nguyendu_tool/core/database/database_backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDir;
  late File dbFile;
  late Directory backupsDir;
  late DatabaseBackupService backupService;

  Future<void> createRealDatabase(File file, {String note = 'v5_seed'}) async {
    final db = await databaseFactoryFfi.openDatabase(file.path);
    await db.execute('CREATE TABLE IF NOT EXISTS sample_data (id INTEGER PRIMARY KEY, note TEXT);');
    await db.delete('sample_data');
    await db.insert('sample_data', {'note': note});
    await db.close();
  }

  Future<String> readSampleNote(File file) async {
    final db = await databaseFactoryFfi.openDatabase(file.path);
    final rows = await db.query('sample_data');
    final note = rows.first['note'] as String;
    await db.close();
    return note;
  }

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('db_backup_test_');
    dbFile = File(p.join(tempDir.path, 'nguyendu_tool.db'));
    await createRealDatabase(dbFile, note: 'SQLITE_REAL_DATABASE_DATA_V5');

    backupsDir = Directory(p.join(tempDir.path, 'backups'));
    backupService = DatabaseBackupService(
      databaseFile: dbFile,
      backupsDirectory: backupsDir,
      maxRetention: 5,
    );
  });

  tearDown(() {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('Database Backup and Recovery Service Tests', () {
    test('Creates backup snapshot with reason label and timestamps', () async {
      final backup = await backupService.createBackup(reason: 'pre_migration_v5');
      expect(backup, isNotNull);
      expect(await backup!.exists(), isTrue);
      expect(p.basename(backup.path).contains('pre_migration_v5'), isTrue);

      final integrity = await DatabaseBackupService.verifyIntegrity(backup);
      expect(integrity, isTrue);

      final note = await readSampleNote(backup);
      expect(note, equals('SQLITE_REAL_DATABASE_DATA_V5'));
    });

    test('Enforces rolling retention limit of 5 backups', () async {
      for (int i = 1; i <= 7; i++) {
        await createRealDatabase(dbFile, note: 'DATA_REVISION_$i');
        final b = await backupService.createBackup(reason: 'rev_$i');
        expect(b, isNotNull);
        await Future.delayed(const Duration(milliseconds: 10)); // Ensure distinct timestamp
      }

      final list = backupService.listBackups();
      expect(list.length, equals(5), reason: 'Must prune down to maxRetention = 5');

      // The newest backup should contain DATA_REVISION_7
      final newestNote = await readSampleNote(list.first);
      expect(newestNote, equals('DATA_REVISION_7'));
    });

    test('Restores database from backup while preserving corrupted database artifact', () async {
      // 1. Create a valid backup
      await createRealDatabase(dbFile, note: 'HEALTHY_DB_STATE_BEFORE_CRASH');
      final validBackup = await backupService.createBackup(reason: 'healthy');
      expect(validBackup, isNotNull);

      // 2. Simulate database corruption by writing raw garbage into primary DB
      dbFile.writeAsStringSync('CORRUPTED_MALFORMED_HEADER_DATA');

      // 3. Perform recovery restore
      final success = await backupService.restoreFromBackup(validBackup!);
      expect(success, isTrue);

      // 4. Verify primary DB is restored and valid SQLite
      final restoredNote = await readSampleNote(dbFile);
      expect(restoredNote, equals('HEALTHY_DB_STATE_BEFORE_CRASH'));

      // 5. Verify corrupted DB was preserved in backups directory for forensic audit
      final corruptArtifacts = backupsDir
          .listSync()
          .whereType<File>()
          .where((f) => p.basename(f.path).startsWith('nguyendu_tool_corrupt_'))
          .toList();

      expect(corruptArtifacts.length, equals(1));
      expect(corruptArtifacts.first.readAsStringSync(), equals('CORRUPTED_MALFORMED_HEADER_DATA'));
    });
  });
}
