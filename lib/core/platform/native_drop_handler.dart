import 'dart:io';
import 'package:flutter/services.dart';
import '../logging/app_logger.dart';

/// Result of processing dropped file paths.
class DropValidationResult {
  final List<String> validPdfFiles;
  final List<String> rejectedFiles;
  final List<String> errorMessages;

  const DropValidationResult({
    required this.validPdfFiles,
    required this.rejectedFiles,
    required this.errorMessages,
  });

  bool get hasValidFiles => validPdfFiles.isNotEmpty;
  bool get hasRejections => rejectedFiles.isNotEmpty;
}

/// Service that handles native Win32 WM_DROPFILES events delivered via MethodChannel.
class NativeDropHandler {
  static const MethodChannel _channel = MethodChannel('nguyendu_tool/native_drop');
  static bool _initialized = false;
  static final List<void Function(DropValidationResult result)> _listeners = [];

  /// Initialize listener for native Windows Explorer file drops.
  static void initialize() {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onFilesDropped') {
        final rawList = call.arguments;
        if (rawList is List) {
          final paths = rawList.map((e) => e.toString()).toList();
          final result = validateDroppedPaths(paths);
          _notifyListeners(result);
        }
      }
    });
    AppLogger.info('NativeDropHandler initialized for Win32 drop events.');
  }

  /// Validates a list of dropped paths according to product specifications:
  /// - Accepts single/multiple valid .pdf files
  /// - Rejects directories/folders safely
  /// - Rejects non-PDF files safely
  /// - Handles corrupt or empty paths without crashing
  static DropValidationResult validateDroppedPaths(List<String> rawPaths) {
    final validPdfs = <String>[];
    final rejected = <String>[];
    final errorMessages = <String>[];

    for (final rawPath in rawPaths) {
      final trimmed = rawPath.trim();
      if (trimmed.isEmpty) continue;

      try {
        final type = FileSystemEntity.typeSync(trimmed, followLinks: true);
        if (type == FileSystemEntityType.directory) {
          rejected.add(trimmed);
          errorMessages.add('Bỏ qua thư mục "$trimmed": Hệ thống chỉ xử lý tệp PDF trực tiếp.');
          continue;
        }

        if (type == FileSystemEntityType.notFound) {
          rejected.add(trimmed);
          errorMessages.add('Không tìm thấy tệp "$trimmed".');
          continue;
        }

        final lower = trimmed.toLowerCase();
        if (!lower.endsWith('.pdf')) {
          rejected.add(trimmed);
          errorMessages.add('Bỏ qua tệp "$trimmed": Định dạng không phải là PDF.');
          continue;
        }

        // File is a valid existing PDF file
        validPdfs.add(trimmed);
      } catch (e) {
        rejected.add(trimmed);
        errorMessages.add('Không thể truy cập tệp "$trimmed": $e');
      }
    }

    return DropValidationResult(
      validPdfFiles: validPdfs,
      rejectedFiles: rejected,
      errorMessages: errorMessages,
    );
  }

  /// Register a listener to receive drop events.
  static void addListener(void Function(DropValidationResult result) listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  /// Unregister a listener.
  static void removeListener(void Function(DropValidationResult result) listener) {
    _listeners.remove(listener);
  }

  static void _notifyListeners(DropValidationResult result) {
    for (final listener in List.of(_listeners)) {
      try {
        listener(result);
      } catch (e) {
        AppLogger.error('Error invoking drop listener: $e');
      }
    }
  }
}
