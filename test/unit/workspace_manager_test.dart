import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/filesystem/workspace_manager.dart';

void main() {
  late Directory tempDir;
  late WorkspaceManager workspaceManager;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ischool_ws_test_');
    workspaceManager = WorkspaceManager(tempDir.path);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('WorkspaceManager Tests', () {
    test('Default workspace path is valid and not empty', () {
      final defaultPath = WorkspaceManager.getDefaultWorkspacePath();
      expect(defaultPath, isNotEmpty);
      expect(WorkspaceManager.validatePath(defaultPath), isTrue);
    });

    test('Initializes workspace and creates all required subdirectories', () async {
      await workspaceManager.init();

      expect(workspaceManager.isInitialized, isTrue);
      expect(workspaceManager.rootDir.existsSync(), isTrue);
      expect(workspaceManager.projectsDir.existsSync(), isTrue);
      expect(workspaceManager.importsDir.existsSync(), isTrue);
      expect(workspaceManager.exportsDir.existsSync(), isTrue);
      expect(workspaceManager.cacheDir.existsSync(), isTrue);
      expect(workspaceManager.tempDir.existsSync(), isTrue);
      expect(workspaceManager.logsDir.existsSync(), isTrue);
    });

    test('Clears temporary files correctly', () async {
      await workspaceManager.init();

      // Create dummy temp files
      final dummy1 = File('${workspaceManager.tempDir.path}${Platform.pathSeparator}test1.tmp');
      final dummy2 = File('${workspaceManager.tempDir.path}${Platform.pathSeparator}test2.tmp');
      dummy1.writeAsStringSync('temp data 1');
      dummy2.writeAsStringSync('temp data 2');

      expect(dummy1.existsSync(), isTrue);
      expect(dummy2.existsSync(), isTrue);

      final deleted = await workspaceManager.clearTempFiles();
      expect(deleted, 2);
      expect(dummy1.existsSync(), isFalse);
      expect(dummy2.existsSync(), isFalse);
    });

    test('Validates absolute and empty paths properly', () {
      expect(WorkspaceManager.validatePath(''), isFalse);
      expect(WorkspaceManager.validatePath('   '), isFalse);
      expect(WorkspaceManager.validatePath(tempDir.path), isTrue);
    });
  });
}
