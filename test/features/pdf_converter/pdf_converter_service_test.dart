import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/database/app_database.dart';
import 'package:nguyendu_tool/core/filesystem/workspace_manager.dart';
import 'package:nguyendu_tool/features/pdf_converter/application/pdf_converter_service.dart';
import 'package:nguyendu_tool/features/pdf_converter/domain/models/conversion_options.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late WorkspaceManager workspaceManager;
  late AppDatabase database;
  late PdfConverterService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('converter_service_test_');
    workspaceManager = WorkspaceManager(tempDir.path);
    await workspaceManager.init();

    database = AppDatabase(inMemory: true);
    await database.init();

    service = PdfConverterService(
      workspaceManager: workspaceManager,
      database: database,
    );
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('PdfConverterService Tests', () {
    test('Converts 01_text_vietnamese.pdf to both DOCX and XLSX with progress reporting', () async {
      final progressUpdates = <double>[];
      final stageMessages = <String>[];

      final result = await service.convert(
        pdfPath: 'test/fixtures/01_text_vietnamese.pdf',
        options: const ConversionOptions(
          format: OutputFormat.both,
          language: OcrLanguage.vietnamese,
          dpi: DpiPreset.standard150,
        ),
        onProgress: (current, total, progress, stage) {
          progressUpdates.add(progress);
          stageMessages.add(stage);
        },
      );

      expect(result.isSuccess, isTrue);
      expect(result.docxPath, isNotNull);
      expect(result.xlsxPath, isNotNull);
      expect(File(result.docxPath!).existsSync(), isTrue);
      expect(File(result.xlsxPath!).existsSync(), isTrue);

      expect(progressUpdates.isNotEmpty, isTrue);
      expect(progressUpdates.last, 1.0);
      expect(stageMessages.last, contains('thành công'));

      // Check database files table
      final rows = await database.db.query('files');
      expect(rows.length, 2);
    });

    test('Cancellation stops execution and removes partial outputs', () async {
      bool cancelled = false;

      final result = await service.convert(
        pdfPath: 'test/fixtures/05_multi_page.pdf',
        options: const ConversionOptions(format: OutputFormat.docx),
        onProgress: (current, total, progress, stage) {
          // Trigger cancellation as soon as progress starts
          if (progress > 0.05) {
            cancelled = true;
          }
        },
        isCancelled: () => cancelled,
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('hủy'));

      // Ensure no dangling files were created in exports
      final exportFiles = workspaceManager.exportsDir.listSync();
      expect(exportFiles.isEmpty, isTrue);
    });
  });
}
