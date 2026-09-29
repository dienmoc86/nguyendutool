import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/errors/app_exceptions.dart';
import 'package:nguyendu_tool/features/text_to_speech/application/text_extractor_service.dart';

void main() {
  group('TextExtractorService Tests', () {
    late Directory tempDir;
    const extractor = TextExtractorService();

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('tts_extractor_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('Extracts Vietnamese text from UTF-8 plain TXT file', () async {
      final file = File('${tempDir.path}/test_utf8.txt');
      const content = 'Chào mừng năm học mới 2026 tại trường THCS Nguyễn Du.';
      await file.writeAsString(content, encoding: utf8);

      final extracted = await extractor.extractTextFromFile(file.path);
      expect(extracted, equals(content));
    });

    test('Extracts Vietnamese text from TXT with UTF-8 BOM (0xEF, 0xBB, 0xBF)', () async {
      final file = File('${tempDir.path}/test_bom.txt');
      const content = 'Văn bản có chứa Byte Order Mark (BOM).';
      final bytes = BytesBuilder();
      bytes.add([0xEF, 0xBB, 0xBF]); // UTF-8 BOM
      bytes.add(utf8.encode(content));
      await file.writeAsBytes(bytes.toBytes());

      final extracted = await extractor.extractTextFromFile(file.path);
      expect(extracted, equals(content));
    });

    test('Rejects dangerous or executable file extensions (Security Req 55)', () async {
      final exeFile = File('${tempDir.path}/malicious.exe');
      await exeFile.writeAsString('echo hack');

      expect(
        () => extractor.extractTextFromFile(exeFile.path),
        throwsA(isA<TtsInputException>()),
      );
    });

    test('Extracts structured text from OpenXML DOCX archive', () async {
      final docxFile = File('${tempDir.path}/test_document.docx');

      const documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:r><w:t>Kế hoạch giảng dạy môn Tin học</w:t></w:r>
    </w:p>
    <w:p>
      <w:r><w:t>Tiết 1: Giới thiệu phần mềm NguyenDu Tool &amp; AI.</w:t></w:r>
    </w:p>
  </w:body>
</w:document>''';

      final archive = Archive();
      archive.addFile(ArchiveFile('word/document.xml', documentXml.length, utf8.encode(documentXml)));
      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);
      await docxFile.writeAsBytes(zipBytes!);

      final extracted = await extractor.extractTextFromFile(docxFile.path);
      expect(extracted, contains('Kế hoạch giảng dạy môn Tin học'));
      expect(extracted, contains('Tiết 1: Giới thiệu phần mềm NguyenDu Tool & AI.'));
      // Verify XML tags are stripped and not read aloud
      expect(extracted, isNot(contains('<w:t>')));
      expect(extracted, isNot(contains('<w:p>')));
    });
  });
}
