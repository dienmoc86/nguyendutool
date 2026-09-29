import 'dart:convert';
import 'dart:io';
import '../../../core/logging/app_logger.dart';
import '../domain/models/pdf_document_analysis.dart';
import 'pdf_text_extractor.dart';

/// Robust PDF Document Analyzer combining native Windows.Data.Pdf metadata inspections
/// with page-specific stream structure analysis and fail-safe classification.
class PdfDocumentAnalyzer {
  /// Analyzes a PDF file from disk.
  Future<PdfDocumentAnalysis> analyze(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw ArgumentError('Tệp không tồn tại: $filePath');
    }

    final bytes = await file.readAsBytes();
    final fileSize = bytes.length;

    if (fileSize < 5) {
      throw const FormatException('Tệp rỗng hoặc không đúng định dạng PDF hợp lệ.');
    }

    // Validate PDF magic header "%PDF-"
    if (bytes[0] != 0x25 ||
        bytes[1] != 0x50 ||
        bytes[2] != 0x44 ||
        bytes[3] != 0x46 ||
        bytes[4] != 0x2D) {
      throw const FormatException('Tệp không đúng định dạng PDF hợp lệ.');
    }

    final contentStr = latin1.decode(bytes, allowInvalid: true);
    if (contentStr.contains('/Encrypt')) {
      throw const FormatException(
        'Tệp PDF được bảo vệ bằng mật khẩu (Encrypted). Vui lòng mở khóa tệp trước khi chuyển đổi.',
      );
    }

    // Attempt native Windows.Data.Pdf probe for exact page count & rotations
    WinRtPdfMetadata? winRtMeta;
    if (Platform.isWindows) {
      winRtMeta = await _probeWithWinRt(filePath);
    }

    final pageCount = winRtMeta?.pageCount ?? _estimatePageCountFromPdf(contentStr);
    final rotations = winRtMeta?.rotations ?? List<int>.filled(pageCount, 0);

    int totalChars = 0;
    int scannedPages = 0;
    int textPages = 0;
    int mixedPages = 0;
    int needsRasterPages = 0;
    bool hasTables = false;

    final pageAnalyses = <PdfPageAnalysis>[];

    for (int i = 0; i < pageCount; i++) {
      final pageNum = i + 1;
      final rot = i < rotations.length ? rotations[i] : 0;

      // Extract page-specific text
      final extractedText = await PdfTextExtractor.extractPageText(filePath, pageNum);

      final textLength = extractedText.length;
      totalChars += textLength;

      final pageChunk = _extractPageChunk(contentStr, i, pageCount);
      final imageCount = _countImageXObjects(pageChunk);
      final hasEmbeddedFonts = pageChunk.contains('/Font') || pageChunk.contains('/BaseFont');
      final imageAreaRatio = _estimateImageAreaRatio(imageCount, textLength);

      PdfClassification pageClassification;
      if (extractedText.isEmpty && imageCount == 0) {
        pageClassification = PdfClassification.needsRasterAnalysis;
        needsRasterPages++;
      } else if (textLength > 60 && imageCount == 0) {
        pageClassification = PdfClassification.text;
        textPages++;
      } else if (textLength < 25 && imageCount > 0) {
        pageClassification = PdfClassification.scanned;
        scannedPages++;
      } else if (textLength >= 25 && imageCount > 0) {
        pageClassification = PdfClassification.mixed;
        mixedPages++;
      } else if (textLength > 0 && imageCount == 0) {
        pageClassification = PdfClassification.text;
        textPages++;
      } else {
        pageClassification = PdfClassification.needsRasterAnalysis;
        needsRasterPages++;
      }

      if (_detectTableIndicators(extractedText, pageChunk)) {
        hasTables = true;
      }

      pageAnalyses.add(
        PdfPageAnalysis(
          pageNumber: pageNum,
          textLength: textLength,
          imageCount: imageCount,
          imageAreaRatio: imageAreaRatio,
          hasEmbeddedFonts: hasEmbeddedFonts,
          classification: pageClassification,
          rotationDegrees: rot,
        ),
      );
    }

    final totalPages = pageAnalyses.isNotEmpty ? pageAnalyses.length : 1;

    PdfClassification overall;
    if (scannedPages == totalPages) {
      overall = PdfClassification.scanned;
    } else if (textPages == totalPages && mixedPages == 0 && needsRasterPages == 0) {
      overall = PdfClassification.text;
    } else if (needsRasterPages > 0 || mixedPages > 0 || scannedPages > 0) {
      overall = (scannedPages + needsRasterPages > textPages)
          ? PdfClassification.scanned
          : PdfClassification.mixed;
    } else {
      overall = PdfClassification.text;
    }

    return PdfDocumentAnalysis(
      filePath: filePath,
      totalPages: totalPages,
      pages: pageAnalyses,
      overallClassification: overall,
      totalCharacters: totalChars,
      containsTables: hasTables,
      fileSize: fileSize,
    );
  }

  /// Probes PDF metadata via native Windows.Data.Pdf for exact page count and per-page rotation metadata.
  Future<WinRtPdfMetadata?> _probeWithWinRt(String filePath) async {
    try {
      final script = '''
Add-Type -AssemblyName System.Runtime.WindowsRuntime
[Windows.Data.Pdf.PdfDocument, Windows.Data.Pdf, ContentType = WindowsRuntime] | Out-Null
[Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime] | Out-Null

\$asTaskOp = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    \$_.Name -eq "AsTask" -and \$_.GetParameters().Count -eq 1 -and \$_.GetParameters()[0].ParameterType.Name.StartsWith("IAsyncOperation")
} | Select-Object -First 1

function Await-Op(\$op, [Type]\$targetType) {
    \$m = \$asTaskOp.MakeGenericMethod(\$targetType)
    return \$m.Invoke(\$null, @(\$op)).GetAwaiter().GetResult()
}

try {
    \$fullPdf = [System.IO.Path]::GetFullPath("$filePath")
    \$file = Await-Op ([Windows.Storage.StorageFile]::GetFileFromPathAsync(\$fullPdf)) ([Windows.Storage.StorageFile])
    \$doc = Await-Op ([Windows.Data.Pdf.PdfDocument]::LoadFromFileAsync(\$file)) ([Windows.Data.Pdf.PdfDocument])

    \$rots = @()
    for (\$i = 0; \$i -lt \$doc.PageCount; \$i++) {
        \$p = \$doc.GetPage(\$i)
        switch (\$p.Rotation) {
            "Rotate90"  { \$rots += 90 }
            "Rotate180" { \$rots += 180 }
            "Rotate270" { \$rots += 270 }
            default     { \$rots += 0 }
        }
        \$p.Dispose()
    }

    Write-Host "PAGES:\$(\$doc.PageCount)"
    Write-Host "ROTS:\$(\$rots -join ',')"
} catch {
    Write-Host "ERROR: \$_"
}
''';

      final res = await Process.run(
        'powershell',
        ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', script],
      ).timeout(const Duration(seconds: 15));

      if (res.exitCode == 0) {
        final out = res.stdout.toString().trim();
        if (out.contains('PAGES:') && out.contains('ROTS:')) {
          final pagesMatch = RegExp(r'PAGES:(\d+)').firstMatch(out);
          final rotsMatch = RegExp(r'ROTS:([0-9,]*)').firstMatch(out);
          if (pagesMatch != null) {
            final count = int.parse(pagesMatch.group(1)!);
            final rotList = rotsMatch != null && rotsMatch.group(1)!.isNotEmpty
                ? rotsMatch.group(1)!.split(',').map((s) => int.tryParse(s.trim()) ?? 0).toList()
                : List<int>.filled(count, 0);
            return WinRtPdfMetadata(pageCount: count, rotations: rotList);
          }
        }
      }
    } catch (e) {
      AppLogger.warning('WinRT PDF metadata probe failed: $e. Falling back to local structure analysis.');
    }
    return null;
  }

  int _estimatePageCountFromPdf(String content) {
    // 1. Try /Type /Pages /Count N
    final countMatch = RegExp(r'/Type\s*/Pages\b[^>]*?/Count\s+(\d+)').firstMatch(content);
    if (countMatch != null) {
      return int.tryParse(countMatch.group(1)!) ?? 1;
    }

    // 2. Count /Type /Page
    final pagePattern = RegExp(r'/Type\s*/Page\b');
    final matches = pagePattern.allMatches(content).length;
    return matches > 0 ? matches : 1;
  }

  String _extractPageChunk(String content, int pageIndex, int totalPages) {
    final pagePattern = RegExp(r'/Type\s*/Page\b');
    final matches = pagePattern.allMatches(content).toList();
    if (matches.isEmpty || pageIndex >= matches.length) return content;

    final start = matches[pageIndex].start;
    final end = (pageIndex + 1 < matches.length) ? matches[pageIndex + 1].start : content.length;
    return content.substring(start, end);
  }

  int _countImageXObjects(String pageContent) {
    final imagePattern = RegExp(r'/Subtype\s*/Image\b');
    return imagePattern.allMatches(pageContent).length;
  }

  double _estimateImageAreaRatio(int imageCount, int textLength) {
    if (imageCount == 0) return 0.0;
    if (textLength < 20) return 0.95;
    return (imageCount * 0.35).clamp(0.0, 1.0);
  }

  bool _detectTableIndicators(String text, String pageContent) {
    if (text.contains('|') || text.contains('\t\t')) return true;
    final lineDrawingCount = RegExp(r'\b\d+\s+\d+\s+re\b').allMatches(pageContent).length;
    if (lineDrawingCount >= 4) return true;
    return false;
  }
}

class WinRtPdfMetadata {
  final int pageCount;
  final List<int> rotations;

  const WinRtPdfMetadata({
    required this.pageCount,
    required this.rotations,
  });
}
