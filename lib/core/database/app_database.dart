import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide DatabaseException;
import '../errors/app_exceptions.dart';
import '../logging/app_logger.dart';
import 'database_tables.dart';

import 'migrations/v1_to_v2.dart';
import 'migrations/v2_to_v3.dart';
import 'migrations/v3_to_v4.dart';
import 'migrations/v4_to_v5.dart';

/// Local SQLite database manager for NguyenDu Tool.
class AppDatabase {
  static const int databaseVersion = 5;
  static const String databaseFileName = 'nguyendu_tool.db';
  static const String legacyDatabaseFileName = 'ischool_tools.db';

  Database? _db;
  final String? _customPath;
  final bool _inMemory;

  AppDatabase({String? customPath, bool inMemory = false})
      : _customPath = customPath,
        _inMemory = inMemory;

  Database get db {
    if (_db == null) {
      throw const AppDatabaseException('Cơ sở dữ liệu chưa được khởi tạo. Hãy gọi init() trước.');
    }
    return _db!;
  }

  /// Returns active Database instance, initializing automatically if not yet opened.
  Future<Database> get database async {
    if (_db == null || !_db!.isOpen) {
      await init();
    }
    return _db!;
  }

  bool get isOpen => _db != null && _db!.isOpen;

  Future<void> init() async {
    try {
      sqfliteFfiInit();
      final databaseFactory = databaseFactoryFfi;

      String dbPath;
      if (_inMemory) {
        dbPath = inMemoryDatabasePath;
      } else if (_customPath != null) {
        final parentDir = Directory(p.dirname(_customPath));
        if (!parentDir.existsSync()) {
          parentDir.createSync(recursive: true);
        }
        dbPath = _customPath;
      } else {
        // Default relative to working directory or user data
        dbPath = p.join(Directory.current.path, databaseFileName);
      }

      // If target file doesn't exist, check for legacy database file to migrate non-destructively
      if (!_inMemory && !File(dbPath).existsSync()) {
        final legacyPath = p.join(p.dirname(dbPath), legacyDatabaseFileName);
        final legacyFile = File(legacyPath);
        if (legacyFile.existsSync()) {
          AppLogger.info('Migrating legacy database from $legacyPath to $dbPath...');
          legacyFile.copySync(dbPath);
        }
      }

      _db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: databaseVersion,
          onCreate: (db, version) async {
            AppLogger.info('Creating SQLite database tables (version $version)...');
            for (final ddl in DatabaseTables.allCreationStatements) {
              await db.execute(ddl);
            }
          },
          onUpgrade: (db, oldVersion, newVersion) async {
            AppLogger.info('Upgrading SQLite database from $oldVersion to $newVersion');
            if (oldVersion < 2) {
              await V1ToV2Migration.migrate(db);
            }
            if (oldVersion < 3) {
              await V2ToV3Migration.migrate(db);
            }
            if (oldVersion < 4) {
              await V3ToV4Migration.migrate(db);
            }
            if (oldVersion < 5) {
              await V4ToV5Migration.migrate(db);
            }
          },
        ),
      );

      AppLogger.info('AppDatabase opened successfully at: $dbPath');
    } catch (e, st) {
      AppLogger.error('Lỗi khởi tạo cơ sở dữ liệu SQLite', e, st);
      throw AppDatabaseException('Không thể khởi tạo cơ sở dữ liệu.', technicalDetails: e.toString(), stackTrace: st);
    }
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
      AppLogger.info('AppDatabase closed.');
    }
  }
}
