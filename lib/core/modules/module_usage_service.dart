import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../database/app_database.dart';
import '../database/database_tables.dart';
import '../logging/app_logger.dart';
import 'module_definition.dart';
import 'module_registry.dart';

/// Local service tracking user module usage and favorite modules.
/// Strictly local, zero telemetry, zero remote network calls.
class ModuleUsageService {
  final AppDatabase _appDatabase;

  ModuleUsageService({AppDatabase? appDatabase})
      : _appDatabase = appDatabase ?? AppDatabase();

  Future<Database> get _db async => await _appDatabase.database;

  /// Records when a user opens a module.
  Future<void> recordModuleOpened(String moduleId) async {
    try {
      final db = await _db;
      final now = DateTime.now().toIso8601String();

      await db.rawInsert('''
        INSERT INTO ${DatabaseTables.tableModuleUsage} (module_id, open_count, last_opened_at, is_favorite)
        VALUES (?, 1, ?, 0)
        ON CONFLICT(module_id) DO UPDATE SET
          open_count = open_count + 1,
          last_opened_at = excluded.last_opened_at;
      ''', [moduleId, now]);
    } catch (e) {
      AppLogger.warning('Failed to record module usage for $moduleId: $e');
    }
  }

  /// Toggles favorite status for a module.
  Future<bool> toggleFavorite(String moduleId) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseTables.tableModuleUsage,
      columns: ['is_favorite'],
      where: 'module_id = ?',
      whereArgs: [moduleId],
    );

    int newFav = 1;
    if (rows.isNotEmpty) {
      final currentFav = (rows.first['is_favorite'] as int?) ?? 0;
      newFav = currentFav == 1 ? 0 : 1;
      await db.update(
        DatabaseTables.tableModuleUsage,
        {'is_favorite': newFav},
        where: 'module_id = ?',
        whereArgs: [moduleId],
      );
    } else {
      await db.insert(
        DatabaseTables.tableModuleUsage,
        {
          'module_id': moduleId,
          'open_count': 0,
          'last_opened_at': DateTime.now().toIso8601String(),
          'is_favorite': 1,
        },
      );
    }
    return newFav == 1;
  }

  /// Checks if a module is marked favorite.
  Future<bool> isFavorite(String moduleId) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseTables.tableModuleUsage,
      columns: ['is_favorite'],
      where: 'module_id = ?',
      whereArgs: [moduleId],
    );
    if (rows.isEmpty) return false;
    return (rows.first['is_favorite'] as int?) == 1;
  }

  /// Retrieves list of favorited modules.
  Future<List<ModuleDefinition>> getFavorites() async {
    final db = await _db;
    final rows = await db.query(
      DatabaseTables.tableModuleUsage,
      where: 'is_favorite = 1',
      orderBy: 'last_opened_at DESC',
    );

    final registry = ModuleRegistry.instance;
    final result = <ModuleDefinition>[];
    for (final r in rows) {
      final modId = r['module_id'] as String;
      final mod = registry.getModule(modId);
      if (mod != null && mod.isLaunchable) {
        result.add(mod);
      }
    }
    return result;
  }

  /// Retrieves up to [limit] most recently opened modules.
  Future<List<ModuleDefinition>> getRecentModules({int limit = 5}) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseTables.tableModuleUsage,
      where: "open_count > 0 AND module_id != 'dashboard'",
      orderBy: 'last_opened_at DESC',
      limit: limit,
    );

    final registry = ModuleRegistry.instance;
    final result = <ModuleDefinition>[];
    for (final r in rows) {
      final modId = r['module_id'] as String;
      final mod = registry.getModule(modId);
      if (mod != null && mod.isLaunchable) {
        result.add(mod);
      }
    }
    return result;
  }
}

final moduleUsageServiceProvider = Provider<ModuleUsageService>((ref) {
  return ModuleUsageService();
});
