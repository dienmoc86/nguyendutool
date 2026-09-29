import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/logging/app_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempLogDir;

  setUp(() {
    tempLogDir = Directory.systemTemp.createTempSync('logger_test_');
    AppLogger.init(logDirectory: tempLogDir);
  });

  tearDown(() {
    try {
      if (tempLogDir.existsSync()) {
        tempLogDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  test('Sanitizes error object containing SECRET_TEST_12345 and URL query keys (Requirement 45)', () async {
    const rawSecret = 'SECRET_TEST_12345';
    const rawApiKey = 'AIzaSyA_Real_Looking_Key_999999999';

    // 1. Log error with secret inside message
    AppLogger.error('Request failed with token: SECRET_TEST_12345');

    // 2. Log error with Exception object containing secret in URL
    AppLogger.error(
      'Cloud request exception',
      Exception('https://api.example.com/v1/tts?key=SECRET_TEST_12345&other=1'),
    );

    // 3. Log warning with Google API key
    AppLogger.warning('API call to Google with key: $rawApiKey');

    // 4. Log info with Azure header
    AppLogger.info('Sending header Ocp-Apim-Subscription-Key: my_azure_secret_key_888');

    // Read generated log file
    final logFile = AppLogger.currentLogFile;
    expect(logFile, isNotNull);
    expect(logFile!.existsSync(), isTrue);

    final content = logFile.readAsStringSync();

    // Verify 0 occurrences of the raw secret
    final countSecret = rawSecret.allMatches(content).length;
    expect(countSecret, equals(0), reason: 'Log file must have 0 occurrences of SECRET_TEST_12345');

    final countApiKey = rawApiKey.allMatches(content).length;
    expect(countApiKey, equals(0), reason: 'Log file must have 0 occurrences of AIzaSy key');

    expect(content.contains('my_azure_secret_key_888'), isFalse);
    expect(content.contains('[PROTECTED]'), isTrue);
  });
}
