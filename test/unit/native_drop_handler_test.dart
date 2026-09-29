import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/platform/native_drop_handler.dart';

void main() {
  late Directory tempDir;
  late File validPdf1;
  late File validPdf2;
  late File nonPdfFile;
  late Directory subFolder;
  late File corruptPdf;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('drop_test_');
    validPdf1 = File('${tempDir.path}/doc1.pdf')..writeAsStringSync('%PDF-1.4 mock content');
    validPdf2 = File('${tempDir.path}/doc2.pdf')..writeAsStringSync('%PDF-1.7 mock content');
    nonPdfFile = File('${tempDir.path}/notes.txt')..writeAsStringSync('Hello world text file');
    subFolder = Directory('${tempDir.path}/my_folder')..createSync();
    corruptPdf = File('${tempDir.path}/corrupted.pdf')..writeAsStringSync('Not really a pdf header');
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('NativeDropHandler File Drop Validation', () {
    test('Case 1: Single PDF dropped -> accepted', () {
      final result = NativeDropHandler.validateDroppedPaths([validPdf1.path]);
      expect(result.validPdfFiles.length, 1);
      expect(result.validPdfFiles.first, validPdf1.path);
      expect(result.rejectedFiles, isEmpty);
      expect(result.hasValidFiles, isTrue);
      expect(result.hasRejections, isFalse);
    });

    test('Case 2: Multiple PDFs dropped -> all accepted and queued', () {
      final result = NativeDropHandler.validateDroppedPaths([validPdf1.path, validPdf2.path]);
      expect(result.validPdfFiles.length, 2);
      expect(result.validPdfFiles, containsAll([validPdf1.path, validPdf2.path]));
      expect(result.rejectedFiles, isEmpty);
    });

    test('Case 3: Non-PDF dropped -> safely rejected', () {
      final result = NativeDropHandler.validateDroppedPaths([nonPdfFile.path]);
      expect(result.validPdfFiles, isEmpty);
      expect(result.rejectedFiles.length, 1);
      expect(result.hasRejections, isTrue);
      expect(result.errorMessages.first, contains('Định dạng không phải là PDF'));
    });

    test('Case 4: Folder dropped -> safely rejected', () {
      final result = NativeDropHandler.validateDroppedPaths([subFolder.path]);
      expect(result.validPdfFiles, isEmpty);
      expect(result.rejectedFiles.length, 1);
      expect(result.hasRejections, isTrue);
      expect(result.errorMessages.first, contains('Bỏ qua thư mục'));
    });

    test('Case 5: Mixed drop (PDF, Folder, TXT) -> accepts PDF, rejects others without crashing', () {
      final result = NativeDropHandler.validateDroppedPaths([
        validPdf1.path,
        subFolder.path,
        nonPdfFile.path,
        validPdf2.path,
      ]);
      expect(result.validPdfFiles.length, 2);
      expect(result.validPdfFiles, containsAll([validPdf1.path, validPdf2.path]));
      expect(result.rejectedFiles.length, 2);
      expect(result.errorMessages.length, 2);
    });

    test('Case 6: Corrupt PDF (damaged content with .pdf extension) -> accepted into pipeline queue safely', () {
      // The shell drag & drop accepts the .pdf file, and the converter service pipeline handles corruption gracefully
      final result = NativeDropHandler.validateDroppedPaths([corruptPdf.path]);
      expect(result.validPdfFiles.length, 1);
      expect(result.validPdfFiles.first, corruptPdf.path);
      expect(result.rejectedFiles, isEmpty);
    });

    test('Case 7: Non-existent path -> safely rejected', () {
      final result = NativeDropHandler.validateDroppedPaths(['${tempDir.path}/ghost_file.pdf']);
      expect(result.validPdfFiles, isEmpty);
      expect(result.rejectedFiles.length, 1);
      expect(result.errorMessages.first, contains('Không tìm thấy tệp'));
    });
  });
}
