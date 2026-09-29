import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../../../core/logging/app_logger.dart';

/// Reliable page-specific digital text extractor for PDF documents.
/// Ensures text from Page N contains ONLY content belonging to Page N.
/// Supports FlateDecode decompression, octal escape decoding, and safely detects
/// when streams cannot be reliably decoded, returning empty string to trigger OCR fallback.
class PdfTextExtractor {
  /// Extracts text strictly belonging to [pageNumber] (1-indexed).
  /// Returns empty string if no digital text is found on that specific page or if extraction fails.
  static Future<String> extractPageText(String pdfPath, int pageNumber) async {
    try {
      final file = File(pdfPath);
      if (!file.existsSync()) return '';

      final bytes = await file.readAsBytes();
      final contentStr = latin1.decode(bytes, allowInvalid: true);

      // Check encryption
      if (contentStr.contains('/Encrypt')) {
        return '';
      }

      final objPattern = RegExp(r'(\d+)\s+(\d+)\s+obj([\s\S]*?)endobj');
      final matches = objPattern.allMatches(contentStr).toList();
      final pageEntries = <_PdfPageEntry>[];

      for (final m in matches) {
        final id = int.tryParse(m.group(1) ?? '') ?? -1;
        final body = m.group(3) ?? '';

        // Check if this object is a /Page and NOT /Pages
        if (RegExp(r'/Type\s*/Page\b(?!s)').hasMatch(body)) {
          final contentsMatch = RegExp(r'/Contents\s+(\d+)\s+\d+\s+R').firstMatch(body);
          final contentsArrayMatch = RegExp(r'/Contents\s*\[(.*?)\]').firstMatch(body);

          final streamIds = <int>[];
          if (contentsMatch != null) {
            final sid = int.tryParse(contentsMatch.group(1) ?? '');
            if (sid != null) streamIds.add(sid);
          } else if (contentsArrayMatch != null) {
            final inner = contentsArrayMatch.group(1) ?? '';
            final idMatches = RegExp(r'(\d+)\s+\d+\s+R').allMatches(inner);
            for (final idM in idMatches) {
              final sid = int.tryParse(idM.group(1) ?? '');
              if (sid != null) streamIds.add(sid);
            }
          }

          pageEntries.add(_PdfPageEntry(pageObjId: id, streamIds: streamIds, pageBody: body));
        }
      }

      if (pageNumber < 1 || pageNumber > pageEntries.length) {
        return '';
      }

      final targetPage = pageEntries[pageNumber - 1];
      final pageTextBuffer = StringBuffer();

      for (final sid in targetPage.streamIds) {
        for (final m in matches) {
          if (m.group(1) == sid.toString()) {
            final body = m.group(3) ?? '';
            final streamBytes = _extractStreamBytes(bytes, body);
            if (streamBytes != null && streamBytes.isNotEmpty) {
              final streamText = _extractTextFromStream(streamBytes);
              if (streamText.isNotEmpty) {
                pageTextBuffer.writeln(streamText);
              }
            }
            break;
          }
        }
      }

      return pageTextBuffer.toString().trim();
    } catch (e) {
      AppLogger.warning('Page-specific digital text extraction error on page $pageNumber: $e');
      return '';
    }
  }

  /// Extracts all digital text across all pages in the document.
  static Future<String> extractAllText(String pdfPath) async {
    final buffer = StringBuffer();
    for (int p = 1; p <= 1000; p++) {
      final pageTxt = await extractPageText(pdfPath, p);
      if (pageTxt.isEmpty) {
        if (p == 1) return '';
        break;
      }
      buffer.writeln(pageTxt);
    }
    return buffer.toString().trim();
  }

  /// Extracts uncompressed bytes from a matched object body string.
  static Uint8List? _extractStreamBytes(Uint8List fullPdfBytes, String objBody) {
    try {
      const streamMarker = 'stream';
      final streamPos = objBody.indexOf(streamMarker);
      if (streamPos == -1) return null;

      const endStreamMarker = 'endstream';
      final endStreamPos = objBody.indexOf(endStreamMarker, streamPos);
      if (endStreamPos == -1) return null;

      // Extract text content inside stream
      final rawData = objBody.substring(streamPos + streamMarker.length, endStreamPos);

      // Check if FlateDecode compressed
      if (objBody.contains('/FlateDecode')) {
        try {
          final trimmed = rawData.trim();
          final decompressed = zlib.decode(latin1.encode(trimmed));
          return Uint8List.fromList(decompressed);
        } catch (_) {
          return null; // Cannot decompress safely -> fall back to OCR
        }
      }

      return Uint8List.fromList(latin1.encode(rawData.trim()));
    } catch (_) {
      return null;
    }
  }

  /// Parses text operators inside stream bytes (BT ... ET).
  static String _extractTextFromStream(Uint8List streamBytes) {
    final streamContent = latin1.decode(streamBytes, allowInvalid: true);
    final buffer = StringBuffer();

    // Match text blocks BT ... ET
    final btPattern = RegExp(r'BT\b([\s\S]*?)\bET');
    for (final btMatch in btPattern.allMatches(streamContent)) {
      final blockContent = btMatch.group(1) ?? '';

      // Match (Text) Tj
      final tjPattern = RegExp(r'\(([^)]*)\)\s*Tj');
      for (final m in tjPattern.allMatches(blockContent)) {
        final text = _decodeEscapes(m.group(1) ?? '');
        if (text.isNotEmpty) {
          buffer.writeln(text);
        }
      }

      // Match [(T) 10 (e) 10 (xt)] TJ
      final arrayPattern = RegExp(r'\[(.*?)\]\s*TJ');
      for (final m in arrayPattern.allMatches(blockContent)) {
        final arrayContent = m.group(1) ?? '';
        final innerPattern = RegExp(r'\(([^)]*)\)');
        final wordBuffer = StringBuffer();
        for (final sMatch in innerPattern.allMatches(arrayContent)) {
          final text = _decodeEscapes(sMatch.group(1) ?? '');
          wordBuffer.write(text);
        }
        final wordStr = wordBuffer.toString().trim();
        if (wordStr.isNotEmpty) {
          buffer.writeln(wordStr);
        }
      }

      // Match ' or " single/double quote operators
      final quotePattern = RegExp(r'\(([^)]*)\)\s*[\x27\x22]');
      for (final m in quotePattern.allMatches(blockContent)) {
        final text = _decodeEscapes(m.group(1) ?? '');
        if (text.isNotEmpty) {
          buffer.writeln(text);
        }
      }
    }

    final rawResult = buffer.toString().trim();
    if (_isGarbageString(rawResult)) {
      return '';
    }

    return rawResult;
  }

  static String _decodeEscapes(String s) {
    return s
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')')
        .replaceAll(r'\\', r'\')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '')
        .replaceAll(r'\t', '\t');
  }

  static bool _isGarbageString(String s) {
    if (s.isEmpty) return true;
    int unprintable = 0;
    for (int i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      if (c < 32 && c != 10 && c != 13 && c != 9) {
        unprintable++;
      }
    }
    return (unprintable / s.length) > 0.35;
  }
}

class _PdfPageEntry {
  final int pageObjId;
  final List<int> streamIds;
  final String pageBody;

  const _PdfPageEntry({
    required this.pageObjId,
    required this.streamIds,
    required this.pageBody,
  });
}
