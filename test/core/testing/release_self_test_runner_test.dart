import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/testing/release_self_test_runner.dart';

void main() {
  test('ReleaseSelfTestRunner executes in-process self-test with code 0', () async {
    if (!Platform.isWindows) return;

    final code = await ReleaseSelfTestRunner.runCli();
    expect(code, 0, reason: 'All critical checks in release self-test must pass!');

    final resultFile = File('SELF_TEST_RESULT.json');
    expect(resultFile.existsSync(), isTrue);
    final content = resultFile.readAsStringSync();
    expect(content.contains('"overallStatus": "PASSED"'), isTrue);
  });
}
