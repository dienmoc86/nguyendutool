import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide DatabaseException;
import '../../../core/database/app_database.dart';
import '../../../core/database/database_tables.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/logging/app_logger.dart';
import '../domain/file_entry.dart';

/// Repository managing file records in SQLite.
class FileRepository {
  final AppDatabase _database;

  FileRepository(this._database);

  Database get _db => _database.db;

  /// Inserts a new file metadata entry.
  Future<void> addFile(FileEntry file) async {
    try {
      await _db.insert(
        DatabaseTables.tableFiles,
        file.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      AppLogger.info('Recorded file: [${file.id}] ${file.originalName}');
    } catch (e, st) {
      AppLogger.error('Lỗi khi lưu file: ${file.originalName}', e, st);
      throw FileException('Không thể thêm tệp vào thư viện.', path: file.localPath, technicalDetails: e.toString());
    }
  }

  /// Lists all files optionally filtered by search query.
  Future<List<FileEntry>> listFiles({String? query}) async {
    if (!_database.isOpen) return [];
    try {
      List<Map<String, dynamic>> rows;
      if (query != null && query.trim().isNotEmpty) {
        final pattern = '%${query.trim()}%';
        rows = await _db.query(
          DatabaseTables.tableFiles,
          where: 'original_name LIKE ?',
          whereArgs: [pattern],
          orderBy: 'created_at DESC',
        );
      } else {
        rows = await _db.query(
          DatabaseTables.tableFiles,
          orderBy: 'created_at DESC',
        );
      }
      return rows.map((e) => FileEntry.fromMap(e)).toList();
    } catch (e, st) {
      if (!_database.isOpen) return [];
      AppLogger.error('Lỗi khi truy vấn danh sách file', e, st);
      throw DatabaseException('Không thể tải danh sách tệp từ cơ sở dữ liệu.', technicalDetails: e.toString());
    }
  }

  /// Deletes a file entry from database.
  Future<void> deleteFile(String id) async {
    try {
      await _db.delete(
        DatabaseTables.tableFiles,
        where: 'id = ?',
        whereArgs: [id],
      );
      AppLogger.info('Deleted file metadata: [$id]');
    } catch (e, st) {
      AppLogger.error('Lỗi khi xóa file: $id', e, st);
      throw DatabaseException('Không thể xóa tệp khỏi cơ sở dữ liệu.', technicalDetails: e.toString());
    }
  }
}
