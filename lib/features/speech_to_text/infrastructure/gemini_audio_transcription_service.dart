import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../core/ai/gemini_service.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/media/ffmpeg_service.dart';
import '../../../core/security/credential_service.dart';
import '../domain/models/transcription_item.dart';

/// Infrastructure service that handles media audio extraction and multimodal transcription
/// via Google Gemini REST API.
class GeminiAudioTranscriptionService {
  final CredentialService _credentialService;
  final FfmpegService _ffmpegService;

  GeminiAudioTranscriptionService({
    CredentialService? credentialService,
    FfmpegService? ffmpegService,
  })  : _credentialService = credentialService ?? CredentialService(),
        _ffmpegService = ffmpegService ?? FfmpegService.instance;

  /// Checks if Google Gemini API key is configured.
  Future<bool> hasApiKey() async {
    final key = await _credentialService.getGeminiApiKey();
    return key != null && key.trim().isNotEmpty;
  }

  /// Gets the currently configured Google Gemini API key.
  Future<String?> getApiKey() async {
    return await _credentialService.getGeminiApiKey();
  }

  /// Transcribes an audio or video file into structured Vietnamese text.
  Future<TranscriptionResult> transcribeFile({
    required String filePath,
    required TranscribeOptions options,
    required Function(TranscribeStatus status, String message) onProgress,
  }) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw FileSystemException('Không tìm thấy tệp phương tiện tại: $filePath');
    }

    final apiKey = await _credentialService.getGeminiApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const FormatException(
        'Chưa cấu hình Google Gemini API Key. '
        'Vui lòng dán khóa API vào phần Cài đặt để sử dụng tính năng gỡ băng giọng nói.',
      );
    }

    final ext = p.extension(filePath).toLowerCase();
    final sourceFileSize = file.lengthSync();
    final fileName = p.basename(filePath);

    // Audio/Video preprocessing
    File audioFileToSend;
    File? tempAudioFile;
    String mimeType = 'audio/mp3';

    final isVideo = ['.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm'].contains(ext);
    final isLargeAudio = sourceFileSize > 15 * 1024 * 1024 || ext == '.wav';

    if (isVideo || isLargeAudio) {
      onProgress(TranscribeStatus.extractingAudio, 'Đang trích xuất và tối ưu tệp âm thanh qua FFmpeg...');
      tempAudioFile = await _extractAndOptimizeAudio(filePath);
      audioFileToSend = tempAudioFile;
      mimeType = 'audio/mp3';
    } else {
      audioFileToSend = file;
      mimeType = _detectMimeType(ext);
    }

    try {
      final audioBytes = await audioFileToSend.readAsBytes();
      if (audioBytes.isEmpty) {
        throw const FormatException('Tệp âm thanh trống hoặc không đọc được dữ liệu.');
      }

      onProgress(TranscribeStatus.uploading, 'Đang chuẩn bị dữ liệu và gửi yêu cầu tới Google Gemini AI...');

      final prompt = _buildTranscriptionPrompt(options);

      onProgress(TranscribeStatus.transcribing, 'Google Gemini AI đang nhận dạng và gỡ băng tiếng Việt...');

      final gemini = GeminiService(apiKey: apiKey.trim(), model: options.model);
      final rawResponse = await gemini.transcribeMedia(
        mediaBytes: audioBytes,
        mimeType: mimeType,
        prompt: prompt,
        temperature: 0.2,
      );

      onProgress(TranscribeStatus.completed, 'Đã hoàn tất gỡ băng thành công!');

      final parsed = _parseResponse(
        rawResponse: rawResponse,
        sourceFilePath: filePath,
        sourceFileName: fileName,
        sourceFileSize: sourceFileSize,
        modelUsed: options.model,
      );

      return parsed;
    } finally {
      // Clean up temporary extracted audio file
      if (tempAudioFile != null && tempAudioFile.existsSync()) {
        try {
          tempAudioFile.deleteSync();
        } catch (_) {}
      }
    }
  }

  /// Extracts audio and compresses to 16kHz mono MP3 (high speech clarity, tiny file size).
  Future<File> _extractAndOptimizeAudio(String inputFilePath) async {
    await _ffmpegService.initialize();
    final ffmpegPath = _ffmpegService.binaryPath ?? 'ffmpeg';

    final tempDir = Directory.systemTemp.createTempSync('nguyendu_stt_');
    final outPath = p.join(tempDir.path, 'speech_optimized.mp3');

    final args = [
      '-y',
      '-i', inputFilePath,
      '-vn',
      '-ac', '1',
      '-ar', '16000',
      '-b:a', '48k',
      '-f', 'mp3',
      outPath,
    ];

    AppLogger.info('FFmpeg STT extraction command: $ffmpegPath ${args.join(' ')}');

    final result = await Process.run(ffmpegPath, args, runInShell: false)
        .timeout(const Duration(minutes: 5));

    if (result.exitCode != 0) {
      final err = result.stderr.toString();
      AppLogger.error('FFmpeg extraction error: $err');
      throw ProcessException(
        ffmpegPath,
        args,
        'Không thể trích xuất âm thanh từ tệp media: $err',
        result.exitCode,
      );
    }

    final outFile = File(outPath);
    if (!outFile.existsSync() || outFile.lengthSync() == 0) {
      throw const FormatException('Quá trình trích xuất âm thanh không tạo ra tệp kết quả hợp lệ.');
    }

    return outFile;
  }

  String _detectMimeType(String extension) {
    switch (extension) {
      case '.mp3':
        return 'audio/mp3';
      case '.wav':
        return 'audio/wav';
      case '.m4a':
      case '.aac':
        return 'audio/aac';
      case '.ogg':
        return 'audio/ogg';
      case '.flac':
        return 'audio/flac';
      case '.mp4':
        return 'video/mp4';
      case '.webm':
        return 'video/webm';
      default:
        return 'audio/mp3';
    }
  }

  String _buildTranscriptionPrompt(TranscribeOptions options) {
    final buffer = StringBuffer();
    buffer.writeln('Bạn là trợ lý AI chuyên môn cao dành cho giáo viên và nhà trường Việt Nam.');
    buffer.writeln('Hãy gỡ băng (speech-to-text) toàn bộ nội dung trong tệp âm thanh này thành văn bản tiếng Việt chuẩn mực.');
    buffer.writeln('');
    buffer.writeln('CÁC YÊU CẦU BẮT BUỘC:');
    buffer.writeln('1. GỠ BĂNG CHÍNH XÁC (TRANSCRIPTION):');
    buffer.writeln('- Gỡ băng toàn bộ lời nói một cách chính xác 100%, đúng chính tả tiếng Việt có dấu, chấm phẩy ngắt câu tự nhiên theo ngữ cảnh sư phạm.');

    if (options.includeTimestamps) {
      buffer.writeln('- Đặt mốc thời gian dạng [mm:ss] ở đầu mỗi câu hoặc đoạn phát biểu.');
    }

    if (options.identifySpeakers) {
      buffer.writeln('- Phân tách và ghi rõ vai trò người nói (ví dụ: [Thầy giáo], [Cô giáo], [Học sinh], [Người nói 1], [Người nói 2]...) nếu phân biệt được giọng.');
    }

    if (options.generateSummary) {
      buffer.writeln('');
      buffer.writeln('2. TÓM TẮT & TRỌNG TÂM SƯ PHẠM (EDUCATIONAL SUMMARY):');
      buffer.writeln('Ở phần cuối văn bản, hãy thêm một dòng phân cách "---" và đề mục:');
      buffer.writeln('### TÓM TẮT NỘI DUNG & Ý CHÍNH BÀI HỌC / CUỘC HỌP');
      buffer.writeln('- Chủ đề chính: ...');
      buffer.writeln('- Các ý chính / kiến thức cốt lõi:');
      buffer.writeln('  + ...');
      buffer.writeln('- Nhiệm vụ học tập / Kết luận:');
      buffer.writeln('  + ...');
      buffer.writeln('- Từ khóa quan trọng: ...');
    }

    return buffer.toString();
  }

  TranscriptionResult _parseResponse({
    required String rawResponse,
    required String sourceFilePath,
    required String sourceFileName,
    required int sourceFileSize,
    required String modelUsed,
  }) {
    String fullTranscript = rawResponse;
    String? summary;

    const summaryMarker = '### TÓM TẮT';
    final splitIndex = rawResponse.indexOf(summaryMarker);

    if (splitIndex != -1) {
      fullTranscript = rawResponse.substring(0, splitIndex).trim();
      // Remove trailing separator dashes if any
      if (fullTranscript.endsWith('---')) {
        fullTranscript = fullTranscript.substring(0, fullTranscript.length - 3).trim();
      }
      summary = rawResponse.substring(splitIndex).trim();
    }

    // Parse segments with regex
    final segments = <TranscriptionSegment>[];
    final lines = fullTranscript.split('\n');
    final segmentRegex = RegExp(r'(\[\d{1,2}:\d{2}(?::\d{2})?\])\s*(?:\[([^\]]+)\])?\s*:?\s*(.*)');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final match = segmentRegex.firstMatch(trimmed);
      if (match != null) {
        final time = match.group(1) ?? '';
        final speaker = match.group(2) ?? 'Người nói';
        final text = match.group(3) ?? '';
        segments.add(TranscriptionSegment(
          timestamp: time,
          speaker: speaker,
          text: text,
        ));
      }
    }

    return TranscriptionResult(
      rawResponse: rawResponse,
      fullTranscript: fullTranscript,
      summary: summary,
      segments: segments,
      sourceFilePath: sourceFilePath,
      sourceFileName: sourceFileName,
      sourceFileSize: sourceFileSize,
      modelUsed: modelUsed,
      createdAt: DateTime.now(),
    );
  }
}
