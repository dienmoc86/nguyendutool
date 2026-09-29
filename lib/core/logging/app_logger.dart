import 'dart:io';
import 'package:logger/logger.dart';

/// Centralized logger for NguyenDu Tool desktop application.
class AppLogger {
  static late Logger _logger;
  static File? _logFile;
  static bool _initialized = false;

  static const List<String> _sensitiveKeys = [
    'password',
    'passwd',
    'token',
    'secret',
    'apikey',
    'api_key',
    'authorization',
    'bearer',
    'credentials',
    'private_key',
  ];

  static void init({Directory? logDirectory, Level level = Level.debug}) {
    if (logDirectory != null) {
      try {
        if (!logDirectory.existsSync()) {
          logDirectory.createSync(recursive: true);
        }
        final now = DateTime.now();
        final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
        _logFile = File('${logDirectory.path}${Platform.pathSeparator}nguyendu_tool_$dateStr.log');
      } catch (e) {
        // Fallback to console only if file creation fails
        _logFile = null;
      }
    }

    _logger = Logger(
      filter: ProductionFilter(),
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 100,
        colors: true,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.dateAndTime,
      ),
      output: _CompositeLogOutput(_logFile),
      level: level,
    );
    _initialized = true;
    info('AppLogger initialized. Log file: ${_logFile?.path ?? "console only"}');
  }

  static String maskSensitive(String message) {
    var sanitized = message;

    // Mask URL query parameters (e.g. ?key=XYZ, &api_key=XYZ, ?token=XYZ, &secret=XYZ)
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'([?&](?:key|api_key|apikey|token|secret|subscriptionKey)=)[^&\s]+', caseSensitive: false),
      (match) => '${match.group(1)}[PROTECTED]',
    );

    // Mask explicit key-value pairs (e.g. apikey: xyz, token=abc, password: 123)
    for (final key in _sensitiveKeys) {
      final regex = RegExp('$key[:=]\\s*([\\S]+)', caseSensitive: false);
      sanitized = sanitized.replaceAllMapped(regex, (match) {
        final prefix = match.group(0)?.split(RegExp('[:=]'))[0];
        return '$prefix: [PROTECTED]';
      });
    }

    // Mask Azure Cognitive Services headers / parameters
    sanitized = sanitized.replaceAll(
      RegExp(r'Ocp-Apim-Subscription-Key[:=]\s*[^\s]+', caseSensitive: false),
      'Ocp-Apim-Subscription-Key: [PROTECTED]',
    );

    // Mask Bearer tokens
    sanitized = sanitized.replaceAll(
      RegExp(r'Bearer\s+[A-Za-z0-9\-._~+/]+=*', caseSensitive: false),
      'Bearer [PROTECTED]',
    );

    // Mask standard Google API Keys (AIza...)
    sanitized = sanitized.replaceAll(
      RegExp(r'AIza[0-9A-Za-z_-]{20,}'),
      '[PROTECTED_API_KEY]',
    );

    // Mask OpenAI-style keys (sk-...)
    sanitized = sanitized.replaceAll(
      RegExp(r'sk-[A-Za-z0-9]{20,}'),
      '[PROTECTED_KEY]',
    );

    // Mask test secrets pattern (Section 45)
    sanitized = sanitized.replaceAll(
      RegExp(r'SECRET_TEST_[0-9A-Za-z_-]+'),
      '[PROTECTED_TEST_SECRET]',
    );

    // Mask Basic Auth in URLs (https://user:password@...)
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'(https?://)([^:\s]+):([^@\s]+)@'),
      (match) => '${match.group(1)}${match.group(2)}:[PROTECTED]@',
    );

    return sanitized;
  }

  /// Truncates long document text / OCR results to prevent private document leaks into logs.
  static String sanitizeDocumentSnippet(String? text, {int maxLen = 60}) {
    if (text == null || text.isEmpty) return '<empty>';
    final trimmed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (trimmed.length <= maxLen) return trimmed;
    return '${trimmed.substring(0, maxLen)}... [len=${text.length} chars redacted]';
  }

  static Object? _sanitizeError(Object? error) {
    if (error == null) return null;
    final masked = maskSensitive(error.toString());
    return Exception(masked);
  }

  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    if (!_initialized) init();
    _logger.d(maskSensitive(message), error: _sanitizeError(error), stackTrace: stackTrace);
  }

  static void info(String message, [Object? error, StackTrace? stackTrace]) {
    if (!_initialized) init();
    _logger.i(maskSensitive(message), error: _sanitizeError(error), stackTrace: stackTrace);
  }

  static void warning(String message, [Object? error, StackTrace? stackTrace]) {
    if (!_initialized) init();
    _logger.w(maskSensitive(message), error: _sanitizeError(error), stackTrace: stackTrace);
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (!_initialized) init();
    _logger.e(maskSensitive(message), error: _sanitizeError(error), stackTrace: stackTrace);
  }

  static File? get currentLogFile => _logFile;
}

class _CompositeLogOutput extends LogOutput {
  final File? logFile;
  final ConsoleOutput _consoleOutput = ConsoleOutput();

  _CompositeLogOutput(this.logFile);

  @override
  void output(OutputEvent event) {
    final sanitizedLines = event.lines.map((l) => AppLogger.maskSensitive(l)).toList();
    final sanitizedEvent = OutputEvent(event.origin, sanitizedLines);

    _consoleOutput.output(sanitizedEvent);

    if (logFile != null) {
      try {
        final buffer = StringBuffer();
        final timestamp = DateTime.now().toIso8601String();
        for (final line in sanitizedLines) {
          buffer.writeln('[$timestamp] [${event.level.name.toUpperCase()}] $line');
        }
        logFile!.writeAsStringSync(buffer.toString(), mode: FileMode.append, flush: true);
      } catch (_) {
        // Silently avoid logging recursion
      }
    }
  }
}
