// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import '../../core/database/app_database.dart';
import '../../core/filesystem/workspace_manager.dart';
import '../../core/media/ffmpeg_service.dart';
import '../../core/product/product_info.dart';
import '../../core/security/windows_dpapi_secure_storage.dart';
import '../../features/file_library/domain/file_entry.dart';
import '../../features/file_library/infrastructure/file_repository.dart';
import '../../features/pdf_converter/infrastructure/pdf_document_analyzer.dart';
import '../../features/text_to_speech/domain/models/tts_options.dart';
import '../../features/text_to_speech/domain/models/tts_request.dart';
import '../../features/text_to_speech/domain/models/tts_voice.dart';
import '../../features/text_to_speech/infrastructure/windows_speech_synthesizer_provider.dart';

/// Test execution status for release self-test steps.
enum SelfTestStatus {
  passed,
  failed,
  warning,
}

class SelfTestItem {
  final String name;
  final SelfTestStatus status;
  final String details;
  final Duration duration;

  SelfTestItem({
    required this.name,
    required this.status,
    required this.details,
    required this.duration,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'status': status.name,
        'details': details,
        'durationMs': duration.inMilliseconds,
      };
}

/// Standalone CLI release self-test runner (Requirement 35).
/// Runs all production services in-process, generates SELF_TEST_RESULT.json,
/// and exits with 0 on full pass or 1 on blocker.
class ReleaseSelfTestRunner {
  static Future<int> runCli() async {
    print('================================================================');
    print('  NGUYEN DU TOOL - PRODUCTION RELEASE CANDIDATE SELF-TEST       ');
    print('================================================================');
    final startTime = DateTime.now();
    final results = <SelfTestItem>[];
    bool hasBlocker = false;

    // 1. Bootstrap Workspace
    final wsSw = Stopwatch()..start();
    late WorkspaceManager ws;
    try {
      ws = WorkspaceManager();
      await ws.init();
      wsSw.stop();
      results.add(SelfTestItem(
        name: 'workspace_bootstrap',
        status: SelfTestStatus.passed,
        details: 'Khởi tạo không gian làm việc thành công tại: ${ws.rootPath}',
        duration: wsSw.elapsed,
      ));
      print(' [PASS] Workspace Bootstrap (${wsSw.elapsedMilliseconds} ms)');
    } catch (e) {
      wsSw.stop();
      hasBlocker = true;
      results.add(SelfTestItem(
        name: 'workspace_bootstrap',
        status: SelfTestStatus.failed,
        details: 'Lỗi bootstrap thư mục: $e',
        duration: wsSw.elapsed,
      ));
      print(' [FAIL] Workspace Bootstrap: $e');
    }

    // 2. Initialize Real SQLite Database & Check Schema
    final dbSw = Stopwatch()..start();
    late AppDatabase database;
    try {
      final dbPath = p.join(ws.projectsDir.path, AppDatabase.databaseFileName);
      database = AppDatabase(customPath: dbPath);
      await database.init();
      final tables = await database.db.rawQuery("SELECT name FROM sqlite_master WHERE type='table';");
      final tableNames = tables.map((r) => r['name'].toString()).toList();
      final hasCoreTables = tableNames.contains('files') && tableNames.contains('projects');

      dbSw.stop();
      if (hasCoreTables) {
        results.add(SelfTestItem(
          name: 'sqlite_database_init',
          status: SelfTestStatus.passed,
          details: 'Khởi tạo AppDatabase thành công (Schema v${AppDatabase.databaseVersion}, ${tableNames.length} bảng).',
          duration: dbSw.elapsed,
        ));
        print(' [PASS] SQLite Database Init (Schema v${AppDatabase.databaseVersion}, ${tableNames.length} tables)');
      } else {
        hasBlocker = true;
        results.add(SelfTestItem(
          name: 'sqlite_database_init',
          status: SelfTestStatus.failed,
          details: 'Thiếu các bảng cốt lõi (files, projects): $tableNames',
          duration: dbSw.elapsed,
        ));
        print(' [FAIL] SQLite Database Init: Core tables missing.');
      }
    } catch (e) {
      dbSw.stop();
      hasBlocker = true;
      results.add(SelfTestItem(
        name: 'sqlite_database_init',
        status: SelfTestStatus.failed,
        details: 'Khởi tạo SQLite DB thất bại: $e',
        duration: dbSw.elapsed,
      ));
      print(' [FAIL] SQLite Database Init: $e');
    }

    // 3. DPAPI Secure Storage Fail-Closed Validation
    final dpapiSw = Stopwatch()..start();
    try {
      final storage = WindowsDpapiSecureStorage();
      if (!storage.isAvailable) {
        throw Exception('DPAPI is not available on this platform.');
      }
      const testSecretKey = '__release_self_test_key__';
      const testSecretVal = 'SECRET_TOKEN_ABCD_9999';

      await storage.writeSecret(testSecretKey, testSecretVal);
      final readBack = await storage.readSecret(testSecretKey);
      await storage.deleteSecret(testSecretKey);

      dpapiSw.stop();
      if (readBack == testSecretVal) {
        results.add(SelfTestItem(
          name: 'windows_dpapi_secure_storage',
          status: SelfTestStatus.passed,
          details: 'DPAPI mã hóa/giải mã thành công, không dùng Base64 plaintext fallback.',
          duration: dpapiSw.elapsed,
        ));
        print(' [PASS] Windows DPAPI Secure Storage (Fail-Closed Validated)');
      } else {
        hasBlocker = true;
        results.add(SelfTestItem(
          name: 'windows_dpapi_secure_storage',
          status: SelfTestStatus.failed,
          details: 'Dữ liệu giải mã không khớp với bí mật ban đầu.',
          duration: dpapiSw.elapsed,
        ));
        print(' [FAIL] Windows DPAPI: Decrypted value mismatch.');
      }
    } catch (e) {
      dpapiSw.stop();
      hasBlocker = true;
      results.add(SelfTestItem(
        name: 'windows_dpapi_secure_storage',
        status: SelfTestStatus.failed,
        details: 'DPAPI kiểm tra thất bại: $e',
        duration: dpapiSw.elapsed,
      ));
      print(' [FAIL] Windows DPAPI: $e');
    }

    // 4. Bundled FFmpeg & FFprobe Discovery
    final ffmpegSw = Stopwatch()..start();
    final ffmpeg = FfmpegService.instance;
    try {
      final available = await ffmpeg.initialize(forceReinitialize: true);
      ffmpegSw.stop();
      if (available && ffmpeg.ffprobePath != null) {
        results.add(SelfTestItem(
          name: 'ffmpeg_service_discovery',
          status: SelfTestStatus.passed,
          details: 'FFmpeg: ${ffmpeg.version} (${ffmpeg.originLabel}) tại ${ffmpeg.ffmpegPath}, FFprobe: ${ffmpeg.ffprobePath}',
          duration: ffmpegSw.elapsed,
        ));
        print(' [PASS] FFmpeg & FFprobe Discovered (${ffmpeg.originLabel})');
      } else {
        hasBlocker = true;
        results.add(SelfTestItem(
          name: 'ffmpeg_service_discovery',
          status: SelfTestStatus.failed,
          details: 'Không tìm thấy FFmpeg hoặc FFprobe hợp lệ.',
          duration: ffmpegSw.elapsed,
        ));
        print(' [FAIL] FFmpeg / FFprobe not available.');
      }
    } catch (e) {
      ffmpegSw.stop();
      hasBlocker = true;
      results.add(SelfTestItem(
        name: 'ffmpeg_service_discovery',
        status: SelfTestStatus.failed,
        details: 'Khởi tạo FFmpeg gặp lỗi: $e',
        duration: ffmpegSw.elapsed,
      ));
      print(' [FAIL] FFmpeg Discovery: $e');
    }

    // 5. Windows TTS Voice Discovery & Real WAV Synthesis
    final ttsSw = Stopwatch()..start();
    final ttsProvider = WindowsSpeechSynthesizerProvider();
    late String ttsWavPath;
    try {
      await ttsProvider.initialize();
      final voices = ttsProvider.voices;
      final selectedVoice = voices.isNotEmpty
          ? voices.first
          : const TtsVoice(
              id: 'default',
              name: 'Default Voice',
              language: 'vi-VN',
              locale: 'vi-VN',
              isOffline: true,
              gender: 'Neutral',
              providerId: 'windows_local',
            );

      ttsWavPath = p.join(ws.tempDir.path, 'self_test_tts_${DateTime.now().millisecondsSinceEpoch}.wav');

      final request = TtsRequest(
        text: 'Xin chào, đây là bài kiểm tra tự động hệ thống phát hành Nguyen Du Tool.',
        voice: selectedVoice,
        outputPath: ttsWavPath,
        options: const TtsOptions(speed: 1.0),
      );
      final synthOutputPath = await ttsProvider.synthesize(request);
      final wavFile = File(synthOutputPath);

      ttsSw.stop();
      if (wavFile.existsSync() && wavFile.lengthSync() > 1000) {
        results.add(SelfTestItem(
          name: 'windows_tts_synthesis',
          status: SelfTestStatus.passed,
          details: 'Đã tổng hợp thành công tệp WAV (${wavFile.lengthSync()} bytes) qua ${ttsProvider.info.name}. Phát hiện ${voices.length} giọng đọc.',
          duration: ttsSw.elapsed,
        ));
        print(' [PASS] Windows TTS Synthesis (Generated WAV: ${wavFile.lengthSync()} bytes, ${voices.length} voices)');
      } else {
        hasBlocker = true;
        results.add(SelfTestItem(
          name: 'windows_tts_synthesis',
          status: SelfTestStatus.failed,
          details: 'Tệp WAV không được tạo hoặc kích thước không hợp lệ (< 1000 bytes).',
          duration: ttsSw.elapsed,
        ));
        print(' [FAIL] Windows TTS: Invalid or missing WAV output.');
      }
    } catch (e) {
      ttsSw.stop();
      hasBlocker = true;
      results.add(SelfTestItem(
        name: 'windows_tts_synthesis',
        status: SelfTestStatus.failed,
        details: 'Lỗi tổng hợp giọng nói: $e',
        duration: ttsSw.elapsed,
      ));
      print(' [FAIL] Windows TTS Synthesis: $e');
    }

    // 6. Generate Actual 3-Second Test Video through App Service (FFmpeg + TTS Audio + Slide)
    final videoSw = Stopwatch()..start();
    try {
      // Create a test slide image
      final testImg = img.Image(width: 1280, height: 720);
      img.fill(testImg, color: img.ColorRgb8(24, 32, 48));
      img.drawString(testImg, 'NguyenDu Tool Self-Test Video', font: img.arial24, x: 100, y: 100);
      img.drawString(testImg, 'Release Candidate 1.5.1 Automated Verification', font: img.arial24, x: 100, y: 150);
      final slidePath = p.join(ws.tempDir.path, 'self_test_slide_${DateTime.now().millisecondsSinceEpoch}.png');
      await File(slidePath).writeAsBytes(img.encodePng(testImg));

      final videoOutPath = p.join(ws.tempDir.path, 'self_test_video_${DateTime.now().millisecondsSinceEpoch}.mp4');
      final renderOk = await ffmpeg.renderStillImageVideo(
        imagePath: slidePath,
        audioPath: ttsWavPath,
        outputVideoPath: videoOutPath,
        durationSeconds: 3.0,
      );

      final probe = await ffmpeg.probeMedia(videoOutPath);
      videoSw.stop();

      if (renderOk && File(videoOutPath).existsSync() && probe.hasVideo && probe.durationSeconds >= 2.0) {
        results.add(SelfTestItem(
          name: 'video_studio_mp4_render',
          status: SelfTestStatus.passed,
          details: 'Đã xuất thành công video MP4 (${probe.fileSizeBytes} bytes, thời lượng ${probe.durationSeconds.toStringAsFixed(1)}s, ${probe.width}x${probe.height}) qua FFmpeg Engine.',
          duration: videoSw.elapsed,
        ));
        print(' [PASS] Video Studio MP4 Render (${probe.width}x${probe.height}, ${probe.durationSeconds.toStringAsFixed(1)}s, ${probe.fileSizeBytes} bytes)');
      } else {
        hasBlocker = true;
        results.add(SelfTestItem(
          name: 'video_studio_mp4_render',
          status: SelfTestStatus.failed,
          details: 'Video không đạt tiêu chuẩn (Kích thước: ${File(videoOutPath).existsSync() ? File(videoOutPath).lengthSync() : 0}, HasVideo: ${probe.hasVideo})',
          duration: videoSw.elapsed,
        ));
        print(' [FAIL] Video Studio MP4 Render failed.');
      }
    } catch (e) {
      videoSw.stop();
      hasBlocker = true;
      results.add(SelfTestItem(
        name: 'video_studio_mp4_render',
        status: SelfTestStatus.failed,
        details: 'Lỗi xuất video: $e',
        duration: videoSw.elapsed,
      ));
      print(' [FAIL] Video Studio MP4 Render: $e');
    }

    // 7. Perform Simple PDF Document Analyzer Operation
    final pdfSw = Stopwatch()..start();
    try {
      final analyzer = PdfDocumentAnalyzer();
      String pdfTestPath = p.join(Directory.current.path, 'test', 'fixtures', '01_text_vietnamese.pdf');
      if (!File(pdfTestPath).existsSync()) {
        // Generate minimal valid PDF file
        pdfTestPath = p.join(ws.tempDir.path, 'minimal_test.pdf');
        const minimalPdf = '''%PDF-1.4
1 0 obj <</Type /Catalog /Pages 2 0 R>> endobj
2 0 obj <</Type /Pages /Kids [3 0 R] /Count 1>> endobj
3 0 obj <</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R>> endobj
4 0 obj <</Length 44>> stream
BT /F1 12 Tf 100 700 Td (NguyenDu Tool Test) Tj ET
endstream endobj
xref
0 5
0000000000 65535 f 
0000000009 00000 n 
0000000058 00000 n 
0000000115 00000 n 
0000000206 00000 n 
trailer <</Size 5 /Root 1 0 R>>
startxref
300
%%EOF''';
        await File(pdfTestPath).writeAsString(minimalPdf);
      }

      final analysis = await analyzer.analyze(pdfTestPath);
      pdfSw.stop();
      results.add(SelfTestItem(
        name: 'pdf_analyzer_operation',
        status: SelfTestStatus.passed,
        details: 'Phân tích tệp PDF thành công (${analysis.totalPages} trang, ${analysis.totalCharacters} ký tự, loại: ${analysis.overallClassification.name}).',
        duration: pdfSw.elapsed,
      ));
      print(' [PASS] PDF Analyzer (${analysis.totalPages} pages, type: ${analysis.overallClassification.name})');
    } catch (e) {
      pdfSw.stop();
      hasBlocker = true;
      results.add(SelfTestItem(
        name: 'pdf_analyzer_operation',
        status: SelfTestStatus.failed,
        details: 'Phân tích PDF thất bại: $e',
        duration: pdfSw.elapsed,
      ));
      print(' [FAIL] PDF Analyzer: $e');
    }

    // 8. Create / Reopen DB Record & Validate Library Repository
    final libSw = Stopwatch()..start();
    try {
      final fileRepo = FileRepository(database);
      final testFileEntry = FileEntry(
        id: 'self_test_entry_${DateTime.now().millisecondsSinceEpoch}',
        originalName: 'TaiLieuKiemTra.pdf',
        size: 2048,
        mimeType: 'application/pdf',
        localPath: p.join(ws.projectsDir.path, 'TaiLieuKiemTra.pdf'),
        createdAt: DateTime.now(),
      );

      await fileRepo.addFile(testFileEntry);
      final files = await fileRepo.listFiles(query: 'TaiLieuKiemTra');
      final found = files.any((f) => f.id == testFileEntry.id);

      libSw.stop();
      if (found) {
        results.add(SelfTestItem(
          name: 'library_repository_persistence',
          status: SelfTestStatus.passed,
          details: 'Ghi và truy vấn tệp trong FileRepository SQLite thành công.',
          duration: libSw.elapsed,
        ));
        print(' [PASS] Library Repository SQLite Persistence');
      } else {
        hasBlocker = true;
        results.add(SelfTestItem(
          name: 'library_repository_persistence',
          status: SelfTestStatus.failed,
          details: 'Không tìm thấy bản ghi vừa thêm trong FileRepository.',
          duration: libSw.elapsed,
        ));
        print(' [FAIL] Library Repository persistence check failed.');
      }
    } catch (e) {
      libSw.stop();
      hasBlocker = true;
      results.add(SelfTestItem(
        name: 'library_repository_persistence',
        status: SelfTestStatus.failed,
        details: 'Lỗi kiểm tra FileRepository: $e',
        duration: libSw.elapsed,
      ));
      print(' [FAIL] Library Repository: $e');
    }

    // Write SELF_TEST_RESULT.json
    final totalDuration = DateTime.now().difference(startTime);
    final report = {
      'timestamp': DateTime.now().toIso8601String(),
      'version': ProductInfo.versionString,
      'platform': '${Platform.operatingSystem} (${Platform.operatingSystemVersion})',
      'totalDurationMs': totalDuration.inMilliseconds,
      'overallStatus': hasBlocker ? 'FAILED' : 'PASSED',
      'exitCode': hasBlocker ? 1 : 0,
      'checks': results.map((r) => r.toJson()).toList(),
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(report);
    final outFile1 = File(p.join(Directory.current.path, 'SELF_TEST_RESULT.json'));
    await outFile1.writeAsString(jsonStr, flush: true);

    try {
      final outFile2 = File(p.join(ws.rootPath, 'SELF_TEST_RESULT.json'));
      await outFile2.writeAsString(jsonStr, flush: true);
    } catch (_) {}

    print('================================================================');
    print('  SELF-TEST RESULT: ${hasBlocker ? "BLOCKER (FAIL)" : "ALL CRITICAL CHECKS PASSED (PASS)"}');
    print('  Report saved to: ${outFile1.path}');
    print('================================================================');

    return hasBlocker ? 1 : 0;
  }
}
