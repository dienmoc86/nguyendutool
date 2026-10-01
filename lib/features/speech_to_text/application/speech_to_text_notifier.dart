import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../core/security/credential_service.dart';
import '../domain/models/transcription_item.dart';
import '../infrastructure/gemini_audio_transcription_service.dart';
import '../infrastructure/transcription_docx_exporter.dart';

class SpeechToTextState {
  final String? selectedFilePath;
  final String? selectedFileName;
  final int selectedFileSize;
  final TranscribeStatus status;
  final String? statusMessage;
  final TranscribeOptions options;
  final TranscriptionResult? result;
  final String? errorMessage;
  final bool hasApiKey;

  const SpeechToTextState({
    this.selectedFilePath,
    this.selectedFileName,
    this.selectedFileSize = 0,
    this.status = TranscribeStatus.idle,
    this.statusMessage,
    this.options = const TranscribeOptions(),
    this.result,
    this.errorMessage,
    this.hasApiKey = false,
  });

  bool get isProcessing => status.isProcessing;

  String get formattedFileSize {
    if (selectedFileSize < 1024) return '$selectedFileSize B';
    if (selectedFileSize < 1024 * 1024) {
      return '${(selectedFileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(selectedFileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  SpeechToTextState copyWith({
    String? selectedFilePath,
    String? selectedFileName,
    int? selectedFileSize,
    TranscribeStatus? status,
    String? statusMessage,
    TranscribeOptions? options,
    TranscriptionResult? result,
    String? errorMessage,
    bool? hasApiKey,
    bool clearError = false,
    bool clearFile = false,
    bool clearResult = false,
  }) {
    return SpeechToTextState(
      selectedFilePath: clearFile ? null : (selectedFilePath ?? this.selectedFilePath),
      selectedFileName: clearFile ? null : (selectedFileName ?? this.selectedFileName),
      selectedFileSize: clearFile ? 0 : (selectedFileSize ?? this.selectedFileSize),
      status: status ?? this.status,
      statusMessage: statusMessage ?? this.statusMessage,
      options: options ?? this.options,
      result: clearResult ? null : (result ?? this.result),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      hasApiKey: hasApiKey ?? this.hasApiKey,
    );
  }
}

class SpeechToTextNotifier extends StateNotifier<SpeechToTextState> {
  final GeminiAudioTranscriptionService _service;
  final CredentialService _credentialService;

  SpeechToTextNotifier({
    GeminiAudioTranscriptionService? service,
    CredentialService? credentialService,
  })  : _service = service ?? GeminiAudioTranscriptionService(),
        _credentialService = credentialService ?? CredentialService(),
        super(const SpeechToTextState()) {
    checkApiKey();
  }

  Future<void> checkApiKey() async {
    final hasKey = await _credentialService.hasGeminiApiKey();
    state = state.copyWith(hasApiKey: hasKey);
  }

  void selectFile(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) {
      state = state.copyWith(errorMessage: 'Không tìm thấy tệp phương tiện.');
      return;
    }

    final size = file.lengthSync();
    final name = p.basename(filePath);

    state = state.copyWith(
      selectedFilePath: filePath,
      selectedFileName: name,
      selectedFileSize: size,
      clearError: true,
      clearResult: true,
      status: TranscribeStatus.idle,
      statusMessage: null,
    );
  }

  void clearSelectedFile() {
    state = state.copyWith(clearFile: true, clearResult: true, clearError: true);
  }

  void updateOptions(TranscribeOptions newOptions) {
    state = state.copyWith(options: newOptions);
  }

  Future<void> startTranscription() async {
    if (state.selectedFilePath == null) {
      state = state.copyWith(errorMessage: 'Vui lòng chọn tệp ghi âm hoặc video trước.');
      return;
    }

    await checkApiKey();
    if (!state.hasApiKey) {
      state = state.copyWith(
        errorMessage: 'Chưa cấu hình Google Gemini API Key. Vui lòng vào Cài đặt để thêm khóa.',
      );
      return;
    }

    state = state.copyWith(
      status: TranscribeStatus.uploading,
      statusMessage: 'Đang khởi động tiến trình nhận dạng Google Gemini AI...',
      clearError: true,
      clearResult: true,
    );

    try {
      final res = await _service.transcribeFile(
        filePath: state.selectedFilePath!,
        options: state.options,
        onProgress: (status, message) {
          state = state.copyWith(status: status, statusMessage: message);
        },
      );

      state = state.copyWith(
        status: TranscribeStatus.completed,
        statusMessage: 'Gỡ băng bài giảng hoàn tất!',
        result: res,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        status: TranscribeStatus.failed,
        statusMessage: null,
        errorMessage: e.toString().replaceAll('Exception:', '').replaceAll('HttpException:', '').trim(),
      );
    }
  }

  Future<File> exportToDocx(String outputPath) async {
    if (state.result == null) {
      throw StateError('Chưa có kết quả gỡ băng để xuất Word.');
    }
    return await TranscriptionDocxExporter.exportTranscription(
      result: state.result!,
      outputPath: outputPath,
      title: 'VĂN BẢN GỠ BĂNG BÀI GIẢNG / GHI ÂM',
    );
  }

  Future<File> exportToTxt(String outputPath) async {
    if (state.result == null) {
      throw StateError('Chưa có kết quả gỡ băng để xuất tệp Text.');
    }
    final file = File(outputPath);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }

    final sb = StringBuffer();
    sb.writeln('=== VĂN BẢN GỠ BĂNG BÀI GIẢNG & GHI ÂM ===');
    sb.writeln('Tệp nguồn: ${state.result!.sourceFileName}');
    sb.writeln('Thời gian: ${state.result!.createdAt}');
    sb.writeln('Động cơ AI: Google Gemini (${state.result!.modelUsed})');
    sb.writeln('==========================================');
    sb.writeln('');

    if (state.result!.summary != null && state.result!.summary!.isNotEmpty) {
      sb.writeln(state.result!.summary);
      sb.writeln('');
      sb.writeln('------------------------------------------');
      sb.writeln('');
    }

    sb.writeln(state.result!.fullTranscript);

    await file.writeAsString(sb.toString());
    return file;
  }
}

/// Provider for SpeechToText StateNotifier.
final speechToTextProvider = StateNotifierProvider<SpeechToTextNotifier, SpeechToTextState>((ref) {
  return SpeechToTextNotifier();
});
