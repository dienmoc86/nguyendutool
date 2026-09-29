import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../database/app_database.dart';
import '../../database/database_tables.dart';
import '../../errors/app_exceptions.dart';
import '../../logging/app_logger.dart';
import '../domain/job_model.dart';
import '../domain/job_status.dart';

/// Repository for persistent Job storage and lifecycle transitions.
class JobRepository {
  final AppDatabase _database;

  JobRepository(this._database);

  Database get _db => _database.db;

  /// Inserts a newly created job.
  Future<void> createJob(JobModel job) async {
    try {
      await _db.insert(
        DatabaseTables.tableJobs,
        job.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      AppLogger.info('Job created: [${job.id}] ${job.jobType.label}');
    } catch (e, st) {
      AppLogger.error('Lỗi khi tạo job: ${job.id}', e, st);
      throw JobException('Không thể lưu tác vụ vào cơ sở dữ liệu.', jobId: job.id, technicalDetails: e.toString());
    }
  }

  /// Updates current execution progress (0.0 to 1.0).
  Future<void> updateProgress(String id, double progress) async {
    try {
      final clamped = progress.clamp(0.0, 1.0);
      await _db.update(
        DatabaseTables.tableJobs,
        {
          'progress': clamped,
          'status': JobStatus.running.value,
          'started_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e, st) {
      AppLogger.error('Lỗi cập nhật tiến độ job: $id', e, st);
      throw JobException('Không thể cập nhật tiến trình tác vụ.', jobId: id, technicalDetails: e.toString());
    }
  }

  /// Marks a job as completed with optional output JSON payload.
  Future<void> completeJob(String id, {String? outputJson}) async {
    try {
      await _db.update(
        DatabaseTables.tableJobs,
        {
          'status': JobStatus.completed.value,
          'progress': 1.0,
          'output_json': outputJson,
          'finished_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      AppLogger.info('Job completed successfully: [$id]');
    } catch (e, st) {
      AppLogger.error('Lỗi khi đánh dấu job hoàn tất: $id', e, st);
      throw JobException('Không thể hoàn tất tác vụ.', jobId: id, technicalDetails: e.toString());
    }
  }

  /// Marks a job as failed with an error message.
  Future<void> failJob(String id, String errorMessage) async {
    try {
      await _db.update(
        DatabaseTables.tableJobs,
        {
          'status': JobStatus.failed.value,
          'error_message': errorMessage,
          'finished_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      AppLogger.warning('Job failed: [$id] - $errorMessage');
    } catch (e, st) {
      AppLogger.error('Lỗi khi đánh dấu job thất bại: $id', e, st);
      throw JobException('Không thể cập nhật trạng thái lỗi của tác vụ.', jobId: id, technicalDetails: e.toString());
    }
  }

  /// Cancels an in-progress or queued job.
  Future<void> cancelJob(String id) async {
    try {
      await _db.update(
        DatabaseTables.tableJobs,
        {
          'status': JobStatus.cancelled.value,
          'finished_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      AppLogger.info('Job cancelled: [$id]');
    } catch (e, st) {
      AppLogger.error('Lỗi khi hủy job: $id', e, st);
      throw JobException('Không thể hủy tác vụ.', jobId: id, technicalDetails: e.toString());
    }
  }

  /// Updates the status of a job.
  Future<void> updateJobStatus(String id, JobStatus status, {String? errorMessage}) async {
    switch (status) {
      case JobStatus.completed:
        await completeJob(id);
        break;
      case JobStatus.failed:
        await failJob(id, errorMessage ?? 'Tác vụ thất bại');
        break;
      case JobStatus.cancelled:
        await cancelJob(id);
        break;
      default:
        await _db.update(
          DatabaseTables.tableJobs,
          {'status': status.value},
          where: 'id = ?',
          whereArgs: [id],
        );
        break;
    }
  }

  /// Retrieves a specific job by its ID.
  Future<JobModel?> getJobById(String id) async {
    try {
      final rows = await _db.query(
        DatabaseTables.tableJobs,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return JobModel.fromMap(rows.first);
    } catch (e, st) {
      AppLogger.error('Lỗi khi tìm job: $id', e, st);
      throw JobException('Không thể đọc thông tin tác vụ.', jobId: id, technicalDetails: e.toString());
    }
  }

  /// Retrieves recent jobs ordered by creation date descending.
  Future<List<JobModel>> getRecentJobs({int limit = 20}) async {
    if (!_database.isOpen) return [];
    try {
      final rows = await _db.query(
        DatabaseTables.tableJobs,
        orderBy: 'created_at DESC',
        limit: limit,
      );
      return rows.map((e) => JobModel.fromMap(e)).toList();
    } catch (e, st) {
      if (!_database.isOpen) return [];
      AppLogger.error('Lỗi khi tải danh sách job gần đây', e, st);
      throw JobException('Không thể tải danh sách tác vụ.', technicalDetails: e.toString());
    }
  }

  /// Deletes a job record.
  Future<void> deleteJob(String id) async {
    try {
      await _db.delete(
        DatabaseTables.tableJobs,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e, st) {
      AppLogger.error('Lỗi khi xóa job: $id', e, st);
      throw JobException('Không thể xóa tác vụ.', jobId: id, technicalDetails: e.toString());
    }
  }
}
