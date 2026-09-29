import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../logging/app_logger.dart';
import '../data/job_repository.dart';
import '../domain/job_model.dart';
import '../domain/job_status.dart';
import '../domain/job_type.dart';

/// StateNotifier that manages the list of recent jobs and allows triggering tasks.
class JobNotifier extends StateNotifier<AsyncValue<List<JobModel>>> {
  final JobRepository _repository;
  final _uuid = const Uuid();

  JobNotifier(this._repository) : super(const AsyncValue.data([])) {
    refreshJobs();
  }

  /// Refreshes the list of recent jobs from SQLite.
  Future<void> refreshJobs() async {
    try {
      final jobs = await _repository.getRecentJobs(limit: 50);
      if (!mounted) return;
      state = AsyncValue.data(jobs);
    } catch (e, st) {
      if (!mounted) return;
      AppLogger.error('Failed to load recent jobs in JobNotifier', e, st);
      state = AsyncValue.error(e, st);
    }
  }

  /// Creates a new job and enqueues it.
  Future<JobModel> createJob({
    required JobType jobType,
    required String moduleType,
    String? inputJson,
  }) async {
    final job = JobModel(
      id: _uuid.v4(),
      jobType: jobType,
      moduleType: moduleType,
      status: JobStatus.queued,
      progress: 0.0,
      inputJson: inputJson,
      createdAt: DateTime.now(),
    );

    await _repository.createJob(job);
    await refreshJobs();
    return job;
  }

  /// Updates job progress.
  Future<void> updateProgress(String jobId, double progress) async {
    await _repository.updateProgress(jobId, progress);
    await refreshJobs();
  }

  /// Completes a job.
  Future<void> completeJob(String jobId, {String? outputJson}) async {
    await _repository.completeJob(jobId, outputJson: outputJson);
    await refreshJobs();
  }

  /// Fails a job with error details.
  Future<void> failJob(String jobId, String error) async {
    await _repository.failJob(jobId, error);
    await refreshJobs();
  }

  /// Cancels a running job.
  Future<void> cancelJob(String jobId) async {
    await _repository.cancelJob(jobId);
    await refreshJobs();
  }

  /// Deletes a job record.
  Future<void> deleteJob(String jobId) async {
    await _repository.deleteJob(jobId);
    await refreshJobs();
  }

  /// Spawns a demo asynchronous simulated job (useful in Phase 0 to demonstrate
  /// the UI, progress indicator, and SQLite state changes).
  Future<void> runDemoJob({
    required JobType type,
    required String moduleName,
  }) async {
    final job = await createJob(
      jobType: type,
      moduleType: moduleName,
      inputJson: '{"demo": true, "title": "Tác vụ thử nghiệm Phase 0"}',
    );

    // Simulate async progression
    unawaited(() async {
      try {
        await Future.delayed(const Duration(milliseconds: 600));
        await updateProgress(job.id, 0.25);

        await Future.delayed(const Duration(milliseconds: 800));
        await updateProgress(job.id, 0.65);

        await Future.delayed(const Duration(milliseconds: 700));
        await updateProgress(job.id, 0.90);

        await Future.delayed(const Duration(milliseconds: 500));
        await completeJob(job.id, outputJson: '{"status": "success", "message": "Hoàn tất xử lý thử nghiệm"}');
      } catch (e) {
        await failJob(job.id, e.toString());
      }
    }());
  }
}
