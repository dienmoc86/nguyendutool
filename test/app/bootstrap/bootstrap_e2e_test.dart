import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/app/bootstrap/bootstrap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppBootstrap.run completes successfully and keeps database open for settings loading', () async {
    final result = await AppBootstrap.run();
    expect(result, isNotNull);
    expect(result.database.isOpen, isTrue);
    expect(result.initialSettings, isNotNull);
    expect(Directory(result.workspaceManager.rootPath).existsSync(), isTrue);

    // Clean up
    await result.database.close();
  });
}
