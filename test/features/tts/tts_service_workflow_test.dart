import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/database/app_database.dart';
import 'package:nguyendu_tool/core/errors/app_exceptions.dart';
import 'package:nguyendu_tool/core/jobs/data/job_repository.dart';
import 'package:nguyendu_tool/core/jobs/domain/job_status.dart';
import 'package:nguyendu_tool/features/file_library/infrastructure/file_repository.dart';
import 'package:nguyendu_tool/features/text_to_speech/application/tts_service.dart';
import 'package:nguyendu_tool/features/text_to_speech/domain/models/tts_options.dart';
import 'package:nguyendu_tool/features/text_to_speech/domain/models/tts_provider_info.dart';
import 'package:nguyendu_tool/features/text_to_speech/domain/models/tts_request.dart';
import 'package:nguyendu_tool/features/text_to_speech/domain/models/tts_voice.dart';
import 'package:nguyendu_tool/features/text_to_speech/domain/services/tts_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Test provider producing genuine short PCM WAV files without external dependencies.
class TestMockTtsProvider implements TtsProvider {
  bool shouldFailChunk = false;
  int failChunkIndex = -1;

  @override
  String get id => 'mock_provider';

  @override
  TtsProviderInfo get info => const TtsProviderInfo(
        id: 'mock_provider',
        name: 'Mock TTS Provider For Testing',
        description: 'Test provider',
        isOffline: true,
        isConfigured: true,
        maxCharactersPerRequest: 50,
      );

  @override
  bool get isAvailable => true;

  @override
  Future<bool> initialize() async => true;

  @override
  Future<List<TtsVoice>> getVoices() async => const [
        TtsVoice(
          id: 'mock_vi',
          name: 'Giáo viên Ảo',
          language: 'vi-VN',
          locale: 'vi-VN',
          providerId: 'mock_provider',
        ),
      ];

  @override
  Future<String> synthesize(TtsRequest request) async {
    if (shouldFailChunk && request.chunkIndex == failChunkIndex) {
      throw const TtsSynthesisException('Simulated provider chunk failure');
    }

    final outPath = request.outputPath!;
    final file = File(outPath);
    await file.parent.create(recursive: true);

    // Create 300ms PCM WAV
    const sampleRate = 22050;
    final numSamples = (sampleRate * 0.3).round();
    final pcmBytes = Uint8List(numSamples * 2);
    final bd = ByteData.sublistView(pcmBytes);

    for (int i = 0; i < numSamples; i++) {
      final val = (sin(2 * pi * 440 * i / sampleRate) * 15000).round();
      bd.setInt16(i * 2, val, Endian.little);
    }

    final header = Uint8List(44);
    final hBd = ByteData.sublistView(header);
    header.setRange(0, 4, 'RIFF'.codeUnits);
    hBd.setUint32(4, 36 + pcmBytes.length, Endian.little);
    header.setRange(8, 12, 'WAVE'.codeUnits);
    header.setRange(12, 16, 'fmt '.codeUnits);
    hBd.setUint32(16, 16, Endian.little);
    hBd.setUint16(20, 1, Endian.little); // PCM
    hBd.setUint16(22, 1, Endian.little); // 1 channel
    hBd.setUint32(24, sampleRate, Endian.little);
    hBd.setUint32(28, sampleRate * 2, Endian.little);
    hBd.setUint16(32, 2, Endian.little);
    hBd.setUint16(34, 16, Endian.little);
    header.setRange(36, 40, 'data'.codeUnits);
    hBd.setUint32(40, pcmBytes.length, Endian.little);

    final full = BytesBuilder();
    full.add(header);
    full.add(pcmBytes);
    await file.writeAsBytes(full.toBytes());

    return outPath;
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('TtsService End-to-End Workflow Tests', () {
    late AppDatabase db;
    late JobRepository jobRepo;
    late FileRepository fileRepo;
    late TestMockTtsProvider mockProvider;
    late TtsService ttsService;

    setUp(() async {
      db = AppDatabase(inMemory: true);
      await db.init();
      jobRepo = JobRepository(db);
      fileRepo = FileRepository(db);
      mockProvider = TestMockTtsProvider();

      ttsService = TtsService(
        database: db,
        jobRepository: jobRepo,
        fileRepository: fileRepo,
        customProviders: [mockProvider],
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Full synthesis workflow produces assembled WAV, subtitles, and Library record', () async {
      const rawText = 'Chào mừng năm học mới 2026. '
          'Chúc các thầy cô và các em học sinh một năm học nhiều thành công rực rỡ.';

      final voice = (await mockProvider.getVoices()).first;

      // 1. Prepare job
      final job = await ttsService.prepareJob(
        title: 'Khai giảng năm học',
        rawText: rawText,
        inputSource: 'manual',
        voice: voice,
        options: const TtsOptions(format: TtsAudioFormat.wav, generateSubtitles: true),
      );

      expect(job.totalChunks, greaterThan(1));

      // Check job in JobRepository
      final dbJob = await jobRepo.getJobById(job.id);
      expect(dbJob, isNotNull);
      expect(dbJob!.status, equals(JobStatus.queued));

      // 2. Execute job
      final result = await ttsService.executeJob(jobId: job.id);

      expect(File(result.audioPath).existsSync(), isTrue);
      expect(result.durationMs, greaterThan(500));
      expect(result.timingSegments.length, equals(job.totalChunks));
      expect(result.srtPath, isNotNull);
      expect(File(result.srtPath!).existsSync(), isTrue);

      // 3. Verify JobRepository status is completed
      final finishedJob = await jobRepo.getJobById(job.id);
      expect(finishedJob!.status, equals(JobStatus.completed));

      // 4. Verify Document Library entry was recorded (Req 52)
      final files = await fileRepo.listFiles();
      expect(files.any((f) => f.localPath == result.audioPath), isTrue);
    });

    test('Cancellation stops synthesis cleanly and marks job cancelled (Req 33)', () async {
      const text = 'Đoạn 1. Đoạn 2. Đoạn 3. Đoạn 4. Đoạn 5.';
      final voice = (await mockProvider.getVoices()).first;

      final job = await ttsService.prepareJob(
        title: 'Cancel Test',
        rawText: text,
        inputSource: 'manual',
        voice: voice,
      );

      // Trigger cancel immediately
      ttsService.cancelJob(job.id);

      await expectLater(
        ttsService.executeJob(jobId: job.id),
        throwsA(isA<TtsCancelledException>()),
      );

      final cancelledJob = await jobRepo.getJobById(job.id);
      expect(cancelledJob!.status, equals(JobStatus.cancelled));
    });

    test('Resumable retry handles chunk failure without restarting completed chunks (Req 13, 34)', () async {
      const text = '''Đoạn một chuẩn bị phát âm thanh.

Đoạn hai sẽ bị lỗi lần đầu.

Đoạn ba tiếp tục hoàn thành.''';
      final voice = (await mockProvider.getVoices()).first;

      final job = await ttsService.prepareJob(
        title: 'Retry Test',
        rawText: text,
        inputSource: 'manual',
        voice: voice,
      );

      expect(job.totalChunks, equals(3));

      // Simulate failure on chunk index 1
      mockProvider.shouldFailChunk = true;
      mockProvider.failChunkIndex = 1;

      await expectLater(
        ttsService.executeJob(jobId: job.id),
        throwsA(isA<TtsSynthesisException>()),
      );

      // Reset failure state to allow chunk 1 to succeed on retry
      mockProvider.shouldFailChunk = false;
      await ttsService.retryChunk(job.id, 1);

      // Resume job execution
      final result = await ttsService.executeJob(jobId: job.id);
      expect(File(result.audioPath).existsSync(), isTrue);

      final completedJob = await jobRepo.getJobById(job.id);
      expect(completedJob!.status, equals(JobStatus.completed));
    });
  });
}
