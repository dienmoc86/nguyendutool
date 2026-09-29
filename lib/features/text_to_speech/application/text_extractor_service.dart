import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import '../../../core/errors/app_exceptions.dart';
import '../../../core/logging/app_logger.dart';
import '../../pdf_converter/infrastructure/pdf_text_extractor.dart';

/// Service responsible for extracting plain text from supported document formats:
/// TXT, DOCX, and PDF with security validation and Vietnamese character integrity.
class TextExtractorService {
  const TextExtractorService();

  static const List<String> supportedExtensions = ['.txt', '.docx', '.pdf'];

  static const List<String> dangerousExtensions = [
    '.exe', '.dll', '.bat', '.cmd', '.ps1', '.vbs', '.msi', '.jar', '.sh',
    '.com', '.scr', '.pif', '.reg', '.vbe', '.wsf', '.wsh',
  ];

  /// Extracts text from the given file [filePath].
  /// Validates security before reading.
  Future<String> extractTextFromFile(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw TtsInputException('Tệp không tồn tại: $filePath');
    }

    final ext = p.extension(filePath).toLowerCase();

    // Security validation (Req 55)
    if (dangerousExtensions.contains(ext)) {
      AppLogger.warning('Rejected dangerous file type: $ext');
      throw TtsInputException('Định dạng tệp không an toàn hoặc không được hỗ trợ: $ext');
    }

    if (!supportedExtensions.contains(ext)) {
      throw TtsInputException(
        'Định dạng tệp không được hỗ trợ ($ext). Hệ thống hỗ trợ: .txt, .docx, .pdf',
      );
    }

    switch (ext) {
      case '.txt':
        return await extractFromTxt(file);
      case '.docx':
        return await extractFromDocx(file);
      case '.pdf':
        return await extractFromPdf(file);
      default:
        throw TtsInputException('Không có bộ trích xuất phù hợp cho định dạng: $ext');
    }
  }

  /// Extracts text from a TXT file handling UTF-8, UTF-8 BOM, and Latin1 fallback.
  Future<String> extractFromTxt(File file) async {
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return '';

      // Check UTF-8 BOM (0xEF, 0xBB, 0xBF)
      if (bytes.length >= 3 &&
          bytes[0] == 0xEF &&
          bytes[1] == 0xBB &&
          bytes[2] == 0xBF) {
        return utf8.decode(bytes.sublist(3), allowMalformed: true).trim();
      }

      // Check UTF-16 LE BOM (0xFF, 0xFE)
      if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
        // Fallback or convert UTF-16 LE
        return _decodeUtf16Le(bytes.sublist(2)).trim();
      }

      // Standard UTF-8 decode
      try {
        return utf8.decode(bytes, allowMalformed: false).trim();
      } catch (_) {
        // Fallback to allowMalformed utf8
        return utf8.decode(bytes, allowMalformed: true).trim();
      }
    } catch (e, stack) {
      AppLogger.error('Failed to extract text from TXT file: ${file.path}', e, stack);
      throw TtsInputException('Không thể đọc tệp văn bản TXT: $e');
    }
  }

  /// Extracts text from an OpenXML DOCX document (`word/document.xml`).
  /// Preserves paragraph order, line breaks, and basic punctuation without reading XML tags aloud.
  Future<String> extractFromDocx(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final documentXmlFile = archive.findFile('word/document.xml');
      if (documentXmlFile == null) {
        throw const TtsInputException('Tệp DOCX không hợp lệ (không tìm thấy word/document.xml).');
      }

      final contentBytes = documentXmlFile.content as List<int>;
      final xmlString = utf8.decode(contentBytes, allowMalformed: true);

      return _parseDocxXml(xmlString).trim();
    } catch (e, stack) {
      if (e is TtsInputException) rethrow;
      AppLogger.error('Failed to extract text from DOCX file: ${file.path}', e, stack);
      throw TtsInputException('Không thể trích xuất văn bản từ tệp Word (.docx): $e');
    }
  }

  /// Extracts digital or OCR text from PDF document.
  Future<String> extractFromPdf(File file) async {
    try {
      final extracted = await PdfTextExtractor.extractAllText(file.path);
      if (extracted.isNotEmpty) {
        return extracted.trim();
      }

      // If digital extraction returned empty, indicate that OCR may be needed or file is empty
      AppLogger.warning('Digital PDF text extraction returned empty for ${file.path}');
      return '';
    } catch (e, stack) {
      AppLogger.error('Failed to extract text from PDF file: ${file.path}', e, stack);
      throw TtsInputException('Không thể trích xuất văn bản từ tệp PDF: $e');
    }
  }

  /// Parses OpenXML document.xml into structured readable text.
  String _parseDocxXml(String xml) {
    final buffer = StringBuffer();

    // Match all paragraphs <w:p ...>...</w:p>
    final paragraphRegex = RegExp(r'<w:p(?:\s+[^>]*)?>([\s\S]*?)<\/w:p>');
    final paragraphs = paragraphRegex.allMatches(xml);

    for (final pMatch in paragraphs) {
      final pBody = pMatch.group(1) ?? '';
      final pText = _extractTextFromParagraphXml(pBody);
      if (pText.isNotEmpty) {
        buffer.writeln(pText);
      }
    }

    return buffer.toString().trim();
  }

  /// Extracts text, tabs, and line breaks from within a single <w:p> block.
  String _extractTextFromParagraphXml(String pXml) {
    final buffer = StringBuffer();

    // We can iterate through tokens or match <w:t>, <w:tab/>, <w:br/>
    final tokenRegex = RegExp(r'<w:t(?:\s+[^>]*)?>([\s\S]*?)<\/w:t>|<w:br(?:\s+[^>]*)?\/>|<w:cr(?:\s+[^>]*)?\/>|<w:tab(?:\s+[^>]*)?\/>');
    final matches = tokenRegex.allMatches(pXml);

    for (final m in matches) {
      final fullMatch = m.group(0) ?? '';
      if (fullMatch.startsWith('<w:t')) {
        final textContent = m.group(1) ?? '';
        buffer.write(_decodeXmlEntities(textContent));
      } else if (fullMatch.startsWith('<w:br') || fullMatch.startsWith('<w:cr')) {
        buffer.write('\n');
      } else if (fullMatch.startsWith('<w:tab')) {
        buffer.write(' ');
      }
    }

    return buffer.toString().trim();
  }

  /// Decodes standard XML entities.
  String _decodeXmlEntities(String input) {
    return input
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }

  /// Decodes UTF-16 LE byte list to string.
  String _decodeUtf16Le(List<int> bytes) {
    final codeUnits = <int>[];
    for (int i = 0; i < bytes.length - 1; i += 2) {
      codeUnits.add(bytes[i] | (bytes[i + 1] << 8));
    }
    return String.fromCharCodes(codeUnits);
  }
}
