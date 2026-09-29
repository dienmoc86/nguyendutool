import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:nguyendu_tool/core/diagnostics/diagnostic_status.dart';
import 'package:nguyendu_tool/core/diagnostics/system_diagnostics_service.dart';
import 'package:nguyendu_tool/core/filesystem/workspace_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late WorkspaceManager workspaceManager;
  late SystemDiagnosticsService service;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('diag_test_');
    workspaceManager = WorkspaceManager(tempDir.path);
    await workspaceManager.init();
    service = SystemDiagnosticsService(workspaceManager: workspaceManager);
  });

  tearDown(() {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('System Diagnostics Service Tests', () {
    test('Runs full diagnostic probes returning all 12 items with typed statuses', () async {
      final items = await service.runFullDiagnostics(
        appVersion: '1.5.0+7',
        databaseSchemaVersion: 5,
      );

      expect(items.length, greaterThanOrEqualTo(12));
      final ids = items.map((e) => e.id).toList();

      expect(ids, contains('app_version'));
      expect(ids, contains('db_schema'));
      expect(ids, contains('windows_os'));
      expect(ids, contains('workspace_writable'));
      expect(ids, contains('disk_space'));
      expect(ids, contains('ffmpeg_engine'));
      expect(ids, contains('ffprobe_engine'));
      expect(ids, contains('windows_ocr'));
      expect(ids, contains('windows_tts'));
      expect(ids, contains('wia_service'));
      expect(ids, contains('camera_hardware'));
      expect(ids, contains('secure_storage'));

      // Verify workspace is writable
      final wsItem = items.firstWhere((e) => e.id == 'workspace_writable');
      expect(wsItem.status, equals(DiagnosticStatus.ready));

      // Verify DB schema is ready
      final dbItem = items.firstWhere((e) => e.id == 'db_schema');
      expect(dbItem.status, equals(DiagnosticStatus.ready));
    });

    test('Generates and exports sanitized diagnostic report without private secrets', () async {
      final items = await service.runFullDiagnostics(
        appVersion: '1.5.0+7',
        databaseSchemaVersion: 5,
      );

      final reportText = service.generateSanitizedReport(
        items: items,
        appVersion: '1.5.0+7',
        databaseSchemaVersion: 5,
      );

      expect(reportText.contains('NGUYEN DU TOOL - SYSTEM DIAGNOSTIC REPORT'), isTrue);
      expect(reportText.contains('NguyenDu Tool v1.5.0+7'), isTrue);
      expect(reportText.contains('Schema  : v5'), isTrue);
      expect(reportText.contains('Windows DPAPI'), isTrue);

      // Verify export to file
      final exportedFile = await service.exportDiagnosticReportToFile(
        items: items,
        appVersion: '1.5.0+7',
        databaseSchemaVersion: 5,
        outputDirectory: tempDir,
      );

      expect(await exportedFile.exists(), isTrue);
      expect(p.basename(exportedFile.path).startsWith('NguyenDuTool_Diagnostic_'), isTrue);
      expect(exportedFile.lengthSync(), greaterThan(200));

      final fileContent = await exportedFile.readAsString();
      expect(fileContent, equals(reportText));

      // Assert no secret patterns
      expect(fileContent.contains('AIzaSy'), isFalse);
      expect(fileContent.contains('sk-'), isFalse);
      expect(fileContent.contains('password:'), isFalse);
    });
  });
}
