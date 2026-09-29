import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/database/app_database.dart';
import 'package:nguyendu_tool/core/jobs/data/job_repository.dart';
import 'package:nguyendu_tool/core/jobs/domain/job_model.dart';
import 'package:nguyendu_tool/core/jobs/domain/job_status.dart';
import 'package:nguyendu_tool/core/jobs/domain/job_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  late JobRepository jobRepository;

  setUp(() async {
    database = AppDatabase(inMemory: true);
    await database.init();
    jobRepository = JobRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('JobRepository Tests', () {
    test('Creates and retrieves a job', () async {
      final job = JobModel(
        id: 'job-123',
        jobType: JobType.pdfConvert,
        moduleType: 'PDF Converter',
        status: JobStatus.queued,
        progress: 0.0,
        createdAt: DateTime.now(),
      );

      await jobRepository.createJob(job);
      final retrieved = await jobRepository.getJobById('job-123');

      expect(retrieved, isNotNull);
      expect(retrieved!.id, 'job-123');
      expect(retrieved.jobType, JobType.pdfConvert);
      expect(retrieved.status, JobStatus.queued);
    });

    test('Updates job progress and status to running', () async {
      final job = JobModel(
        id: 'job-progress',
        jobType: JobType.ocr,
        moduleType: 'OCR Scanner',
        status: JobStatus.queued,
        createdAt: DateTime.now(),
      );

      await jobRepository.createJob(job);
      await jobRepository.updateProgress('job-progress', 0.5);

      final updated = await jobRepository.getJobById('job-progress');
      expect(updated, isNotNull);
      expect(updated!.progress, 0.5);
      expect(updated.status, JobStatus.running);
      expect(updated.startedAt, isNotNull);
    });

    test('Marks job as completed with output JSON', () async {
      final job = JobModel(
        id: 'job-complete',
        jobType: JobType.ttsGenerate,
        moduleType: 'TTS',
        createdAt: DateTime.now(),
      );

      await jobRepository.createJob(job);
      await jobRepository.completeJob('job-complete', outputJson: '{"file": "out.mp3"}');

      final completed = await jobRepository.getJobById('job-complete');
      expect(completed, isNotNull);
      expect(completed!.status, JobStatus.completed);
      expect(completed.progress, 1.0);
      expect(completed.outputJson, '{"file": "out.mp3"}');
      expect(completed.finishedAt, isNotNull);
    });

    test('Marks job as failed with error message', () async {
      final job = JobModel(
        id: 'job-fail',
        jobType: JobType.videoRender,
        moduleType: 'Video Studio',
        createdAt: DateTime.now(),
      );

      await jobRepository.createJob(job);
      await jobRepository.failJob('job-fail', 'Render timed out');

      final failed = await jobRepository.getJobById('job-fail');
      expect(failed, isNotNull);
      expect(failed!.status, JobStatus.failed);
      expect(failed.errorMessage, 'Render timed out');
    });

    test('Retrieves recent jobs ordered by date descending', () async {
      final now = DateTime.now();
      for (int i = 0; i < 5; i++) {
        await jobRepository.createJob(
          JobModel(
            id: 'batch-job-$i',
            jobType: JobType.pdfConvert,
            moduleType: 'Module $i',
            createdAt: now.add(Duration(minutes: i)),
          ),
        );
      }

      final recent = await jobRepository.getRecentJobs(limit: 3);
      expect(recent.length, 3);
      expect(recent.first.id, 'batch-job-4');
    });
  });
}
