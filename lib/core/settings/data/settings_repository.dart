import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide DatabaseException;
import '../../database/app_database.dart';
import '../../database/database_tables.dart';
import '../../errors/app_exceptions.dart';
import '../../logging/app_logger.dart';
import '../domain/app_settings_model.dart';

/// Repository for persistent AppSettings storage in SQLite table `app_settings`.
class SettingsRepository {
  final AppDatabase _database;

  SettingsRepository(this._database);

  Database get _db => _database.db;

  /// Loads current application settings from the database.
  Future<AppSettingsModel> loadSettings() async {
    try {
      final rows = await _db.query(DatabaseTables.tableAppSettings);
      final map = <String, String>{};
      for (final r in rows) {
        final key = r['key'] as String;
        final value = r['value'] as String;
        map[key] = value;
      }
      return AppSettingsModel.fromKeyValues(map);
    } catch (e, st) {
      AppLogger.error('Lỗi khi tải cài đặt ứng dụng', e, st);
      throw DatabaseException('Không thể tải cài đặt người dùng.', technicalDetails: e.toString());
    }
  }

  /// Saves a single setting key-value pair.
  Future<void> saveSetting(String key, String value) async {
    try {
      await _db.insert(
        DatabaseTables.tableAppSettings,
        {
          'key': key,
          'value': value,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, st) {
      AppLogger.error('Lỗi khi lưu cài đặt: $key', e, st);
      throw DatabaseException('Không thể cập nhật cấu hình: $key', technicalDetails: e.toString());
    }
  }

  /// Saves the complete AppSettingsModel in a batch.
  Future<void> saveAllSettings(AppSettingsModel settings) async {
    try {
      final batch = _db.batch();
      final now = DateTime.now().toIso8601String();
      final keyValues = settings.toKeyValues();

      for (final entry in keyValues.entries) {
        batch.insert(
          DatabaseTables.tableAppSettings,
          {
            'key': entry.key,
            'value': entry.value,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
      AppLogger.info('Saved all application settings successfully.');
    } catch (e, st) {
      AppLogger.error('Lỗi lưu toàn bộ cài đặt', e, st);
      throw DatabaseException('Không thể lưu cấu hình ứng dụng.', technicalDetails: e.toString());
    }
  }

  /// Resets all settings to factory defaults.
  Future<void> resetSettings() async {
    try {
      await _db.delete(DatabaseTables.tableAppSettings);
      await saveAllSettings(const AppSettingsModel());
      AppLogger.info('Reset settings to factory defaults.');
    } catch (e, st) {
      AppLogger.error('Lỗi khi khôi phục cài đặt gốc', e, st);
      throw DatabaseException('Không thể khôi phục cài đặt gốc.', technicalDetails: e.toString());
    }
  }
}
