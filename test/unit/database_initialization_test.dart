import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/database/app_database.dart';
import 'package:nguyendu_tool/core/database/database_tables.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;

  setUp(() async {
    database = AppDatabase(inMemory: true);
    await database.init();
  });

  tearDown(() async {
    await database.close();
  });

  group('Database Initialization Tests', () {
    test('Initializes in-memory database and opens connection', () {
      expect(database.isOpen, isTrue);
      expect(database.db, isNotNull);
    });

    test('Creates all 5 core tables upon initialization', () async {
      final db = database.db;
      final tables = await db.query(
        'sqlite_master',
        where: 'type = ?',
        whereArgs: ['table'],
      );

      final tableNames = tables.map((t) => t['name'] as String).toSet();

      expect(tableNames.contains(DatabaseTables.tableAppSettings), isTrue);
      expect(tableNames.contains(DatabaseTables.tableProjects), isTrue);
      expect(tableNames.contains(DatabaseTables.tableFiles), isTrue);
      expect(tableNames.contains(DatabaseTables.tableJobs), isTrue);
      expect(tableNames.contains(DatabaseTables.tableProviders), isTrue);
    });

    test('Closes database properly', () async {
      await database.close();
      expect(database.isOpen, isFalse);
    });
  });
}
