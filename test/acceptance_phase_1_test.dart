import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/database/app_database.dart';
import 'package:nguyendu_tool/core/filesystem/workspace_manager.dart';
import 'package:nguyendu_tool/features/pdf_converter/application/pdf_converter_service.dart';
import 'package:nguyendu_tool/features/pdf_converter/domain/models/conversion_options.dart';
import 'package:nguyendu_tool/features/pdf_converter/domain/models/pdf_document_analysis.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late WorkspaceManager workspaceManager;
  late AppDatabase database;
  late PdfConverterService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('acceptance_phase_1_');
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

  group('PHASE 1 ACCEPTANCE TESTS', () {
    test('Case 1: Text-based Vietnamese PDF -> Word (.docx)', () async {
      final res = await service.convert(
        pdfPath: 'test/fixtures/01_text_vietnamese.pdf',
        options: const ConversionOptions(format: OutputFormat.docx),
      );

      expect(res.isSuccess, isTrue);
      expect(res.analysis.overallClassification, PdfClassification.text);
      expect(res.docxPath, isNotNull);
      final docxFile = File(res.docxPath!);
      expect(docxFile.existsSync(), isTrue);

      final bytes = await docxFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      expect(archive.findFile('word/document.xml'), isNotNull);
    });

    test('Case 2: Scanned Vietnamese PDF -> Word (.docx)', () async {
      final res = await service.convert(
        pdfPath: 'test/fixtures/02_scan_vietnamese.pdf',
        options: const ConversionOptions(
          format: OutputFormat.docx,
          language: OcrLanguage.vietnamese,
        ),
      );

      expect(res.isSuccess, isTrue);
      expect(res.analysis.overallClassification, PdfClassification.scanned);
      expect(res.docxPath, isNotNull);
      expect(File(res.docxPath!).existsSync(), isTrue);
    });

    test('Case 3: Mixed Document PDF -> Word (.docx)', () async {
      final res = await service.convert(
        pdfPath: 'test/fixtures/03_mixed_document.pdf',
        options: const ConversionOptions(format: OutputFormat.docx),
      );

      expect(res.isSuccess, isTrue);
      expect(res.analysis.overallClassification, PdfClassification.mixed);
      expect(res.docxPath, isNotNull);
      expect(File(res.docxPath!).existsSync(), isTrue);
    });

    test('Case 4: PDF with Table -> Excel (.xlsx)', () async {
      final res = await service.convert(
        pdfPath: 'test/fixtures/04_table.pdf',
        options: const ConversionOptions(format: OutputFormat.xlsx, detectTables: true),
      );

      expect(res.isSuccess, isTrue);
      expect(res.analysis.containsTables, isTrue);
      expect(res.xlsxPath, isNotNull);
      final xlsxFile = File(res.xlsxPath!);
      expect(xlsxFile.existsSync(), isTrue);

      final bytes = await xlsxFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      expect(archive.findFile('xl/worksheets/sheet1.xml'), isNotNull);
    });

    test('Case 5: Multi-page PDF -> Word & Excel with page-by-page progress', () async {
      final reportedPages = <int>{};
      final res = await service.convert(
        pdfPath: 'test/fixtures/05_multi_page.pdf',
        options: const ConversionOptions(format: OutputFormat.both),
        onProgress: (current, total, progress, stage) {
          if (current > 0) reportedPages.add(current);
        },
      );

      expect(res.isSuccess, isTrue);
      expect(res.totalPages, 3);
      expect(reportedPages, containsAll([1, 2, 3]));
      expect(res.docxPath, isNotNull);
      expect(res.xlsxPath, isNotNull);
      expect(File(res.docxPath!).existsSync(), isTrue);
      expect(File(res.xlsxPath!).existsSync(), isTrue);
    });

    test('Case 6: Cancel during conversion cleans partial outputs', () async {
      bool cancel = false;
      final res = await service.convert(
        pdfPath: 'test/fixtures/05_multi_page.pdf',
        options: const ConversionOptions(format: OutputFormat.docx),
        onProgress: (current, total, progress, stage) {
          if (progress > 0.05) cancel = true;
        },
        isCancelled: () => cancel,
      );

      expect(res.isSuccess, isFalse);
      expect(res.errorMessage, contains('hủy'));
      expect(workspaceManager.exportsDir.listSync().isEmpty, isTrue);
    });

    test('Case 7: Rebranding and Migration verification', () async {
      expect(WorkspaceManager.defaultWorkspaceFolderName, 'NguyenDu Tool');
      expect(AppDatabase.databaseFileName, 'nguyendu_tool.db');
      expect(AppDatabase.databaseVersion, greaterThanOrEqualTo(2));

      // Verify executable was built as NguyenDuTool.exe
      final exe = File('build/windows/x64/runner/Release/NguyenDuTool.exe');
      expect(exe.existsSync(), isTrue);
    });
  });
}
