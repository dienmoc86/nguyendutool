import 'dart:io';
import 'package:flutter/services.dart';
import '../logging/app_logger.dart';

/// Status of the native file selection operation.
enum FilePickerStatus {
  selected,
  cancelled,
  error,
}

/// Explicit typed result bundle for native file dialog interactions.
class FilePickerResult {
  final FilePickerStatus status;
  final List<String> paths;
  final String? errorMessage;

  const FilePickerResult({
    required this.status,
    this.paths = const [],
    this.errorMessage,
  });

  bool get isSelected => status == FilePickerStatus.selected;
  bool get isCancelled => status == FilePickerStatus.cancelled;
  bool get isError => status == FilePickerStatus.error;
}

/// Native Windows file dialog using compiled C++ COM [IFileOpenDialog] via MethodChannel
/// (Requirements 16 & 17).
/// Replaces all PowerShell and System.Windows.Forms dependencies with native, Unicode UTF-8 safe dialogs.
class NativeFileDialog {
  static const MethodChannel _channel = MethodChannel('nguyendu_tool/native_file_dialog');

  /// Internal invocation helper communicating with the native COM runner.
  static Future<FilePickerResult> _invokeNativeDialog({
    required String title,
    required bool multiSelect,
    required String filterType,
  }) async {
    if (!Platform.isWindows) {
      return const FilePickerResult(
        status: FilePickerStatus.error,
        errorMessage: 'Hộp thoại tệp chỉ hỗ trợ trên nền tảng Windows.',
      );
    }

    try {
      final dynamic raw = await _channel.invokeMethod('showOpenDialog', {
        'title': title,
        'multiSelect': multiSelect,
        'filterType': filterType,
      });

      if (raw is Map) {
        final statusStr = raw['status']?.toString();
        if (statusStr == 'selected') {
          final rawPaths = raw['paths'] as List<dynamic>? ?? [];
          final paths = rawPaths.map((e) => e.toString()).where((p) => p.isNotEmpty && File(p).existsSync()).toList();
          return FilePickerResult(status: FilePickerStatus.selected, paths: paths);
        } else if (statusStr == 'cancelled') {
          return const FilePickerResult(status: FilePickerStatus.cancelled);
        } else {
          final err = raw['errorMessage']?.toString() ?? 'Lỗi không xác định từ hộp thoại tệp.';
          AppLogger.error('NativeFileDialog error: $err');
          return FilePickerResult(status: FilePickerStatus.error, errorMessage: err);
        }
      }

      return const FilePickerResult(status: FilePickerStatus.cancelled);
    } on MissingPluginException {
      // Running under headless CLI test mode or without window runner
      AppLogger.warning('NativeFileDialog: COM MethodChannel not registered in this execution environment.');
      return const FilePickerResult(
        status: FilePickerStatus.error,
        errorMessage: 'Hộp thoại tệp không khả dụng ở chế độ dòng lệnh không có giao diện.',
      );
    } catch (e, st) {
      AppLogger.error('NativeFileDialog invocation error: $e', e, st);
      return FilePickerResult(
        status: FilePickerStatus.error,
        errorMessage: 'Lỗi mở hộp thoại tệp: $e',
      );
    }
  }

  /// Prompts user to select one or multiple PDF files.
  static Future<FilePickerResult> pickPdfFiles({bool multiSelect = true}) async {
    return _invokeNativeDialog(
      title: 'Chọn tệp PDF cần chuyển đổi - NguyenDu Tool',
      multiSelect: multiSelect,
      filterType: 'pdf',
    );
  }

  /// Convenience adapter returning a simple list of paths for PDFs.
  static Future<List<String>> pickPdfFilesList({bool multiSelect = true}) async {
    final result = await pickPdfFiles(multiSelect: multiSelect);
    return result.isSelected ? result.paths : [];
  }

  /// Prompts user to select documents for Text to Speech (.txt, .docx, .pdf).
  static Future<FilePickerResult> pickTtsDocumentFiles({bool multiSelect = false}) async {
    return _invokeNativeDialog(
      title: 'Chọn tệp tài liệu đọc giọng nói - NguyenDu Tool',
      multiSelect: multiSelect,
      filterType: 'tts',
    );
  }

  /// Prompts user to select one or more image files for Scanner or OCR.
  static Future<FilePickerResult> pickImageFiles({bool multiSelect = true}) async {
    return _invokeNativeDialog(
      title: 'Chọn hình ảnh tài liệu - NguyenDu Tool',
      multiSelect: multiSelect,
      filterType: 'image',
    );
  }

  /// Prompts user to select a single image file.
  static Future<FilePickerResult> pickSingleImageFile() async {
    return pickImageFiles(multiSelect: false);
  }

  /// Prompts user to select audio files for Video Studio or Audio Player.
  static Future<FilePickerResult> pickAudioFiles({bool multiSelect = false}) async {
    return _invokeNativeDialog(
      title: 'Chọn tệp âm thanh - NguyenDu Tool',
      multiSelect: multiSelect,
      filterType: 'audio',
    );
  }

  /// Prompts user to select media assets (images, videos, audio) for Video Studio.
  static Future<FilePickerResult> pickVideoStudioMediaFiles({bool multiSelect = true}) async {
    return _invokeNativeDialog(
      title: 'Chọn tài nguyên đa phương tiện cho Video Studio - NguyenDu Tool',
      multiSelect: multiSelect,
      filterType: 'media',
    );
  }
}
