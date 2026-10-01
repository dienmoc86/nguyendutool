import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import '../logging/app_logger.dart';
import '../product/product_info.dart';

/// Top-level crash handler and sanitized local crash reporter.
/// Adheres to Section 38 & 39 of Phase 5 Release Specification:
/// - Hooks FlutterError.onError and PlatformDispatcher.onError
/// - Writes sanitized crash report locally to logs/
/// - Strictly local-only: NEVER transmits telemetry or crash dumps remotely.
class CrashHandler {
  static Directory? _logsDirectory;
  static bool _initialized = false;

  static void init({Directory? logsDirectory}) {
    if (_initialized) return;
    _logsDirectory = logsDirectory;

    // 1. Flutter framework UI errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      _handleCrash(
        module: 'FlutterFramework',
        error: details.exception,
        stackTrace: details.stack ?? StackTrace.current,
        context: details.context?.toString(),
      );
    };

    // 2. PlatformDispatcher asynchronous / platform isolate errors
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      _handleCrash(
        module: 'PlatformDispatcher',
        error: error,
        stackTrace: stack,
      );
      return true;
    };

    _initialized = true;
    AppLogger.info('CrashHandler initialized with local-only reporting.');
  }

  /// Wraps the root application startup in runZonedGuarded.
  static void runGuarded(void Function() appRunner) {
    runZonedGuarded(
      () => appRunner(),
      (error, stack) {
        _handleCrash(
          module: 'ZonedGuardedRoot',
          error: error,
          stackTrace: stack,
        );
      },
    );
  }

  static void _handleCrash({
    required String module,
    required Object error,
    required StackTrace stackTrace,
    String? context,
  }) {
    try {
      final sanitizedMessage = AppLogger.maskSensitive(error.toString());
      AppLogger.error('CRASH [$module]: $sanitizedMessage', error, stackTrace);

      if (_logsDirectory != null && _logsDirectory!.existsSync()) {
        final now = DateTime.now();
        final timestampStr = DateFormat('yyyyMMdd_HHmmss').format(now);
        final crashFile = File(p.join(_logsDirectory!.path, 'crash_$timestampStr.txt'));

        final report = StringBuffer();
        report.writeln('================================================================');
        report.writeln('NGUYENDU TOOL - SANITIZED CRASH REPORT');
        report.writeln('================================================================');
        report.writeln('Timestamp: ${now.toIso8601String()}');
        report.writeln('Version: ${ProductInfo.versionString}');
        report.writeln('Module: $module');
        report.writeln('Platform: ${Platform.operatingSystem} (${Platform.operatingSystemVersion})');
        report.writeln('Dart Version: ${Platform.version.split(' ').first}');
        if (context != null) {
          report.writeln('Context: ${AppLogger.maskSensitive(context)}');
        }
        report.writeln('Privacy Policy: LOCAL-ONLY. No documents or secrets recorded.');
        report.writeln('----------------------------------------------------------------');
        report.writeln('EXCEPTION:');
        report.writeln(sanitizedMessage);
        report.writeln('----------------------------------------------------------------');
        report.writeln('STACK TRACE:');
        report.writeln(stackTrace.toString());
        report.writeln('----------------------------------------------------------------');

        // Include recent sanitized log snippet if available
        final currentLog = AppLogger.currentLogFile;
        if (currentLog != null && currentLog.existsSync()) {
          report.writeln('RECENT LOG SNIPPET (Sanitized):');
          try {
            final lines = currentLog.readAsLinesSync();
            final tail = lines.length > 25 ? lines.sublist(lines.length - 25) : lines;
            for (final line in tail) {
              report.writeln(AppLogger.maskSensitive(line));
            }
          } catch (_) {
            report.writeln('<Unable to read log tail>');
          }
        }
        report.writeln('================================================================');

        crashFile.writeAsStringSync(report.toString(), flush: true);
        AppLogger.info('Sanitized crash report generated: ${crashFile.path}');
      }
    } catch (e) {
      // Emergency console fallback
      debugPrint('CRITICAL: CrashHandler encountered error writing report: $e');
    }
  }
}
