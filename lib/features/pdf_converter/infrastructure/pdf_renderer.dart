import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../core/logging/app_logger.dart';
import '../domain/models/conversion_options.dart';

/// Base exception thrown when PDF rendering fails.
class PdfRenderException implements Exception {
  final String message;
  final Object? cause;

  const PdfRenderException(this.message, [this.cause]);

  @override
  String toString() => cause != null
      ? 'PdfRenderException: $message (Nguyên nhân: $cause)'
      : 'PdfRenderException: $message';
}

/// Thrown specifically when PDF rendering times out.
class PdfRenderTimeoutException extends PdfRenderException {
  const PdfRenderTimeoutException(super.message, [super.cause]);
}

/// Abstract contract for PDF page rasterization.
abstract class PdfPageRenderer {
  /// Renders a single page from a PDF file to a high-resolution PNG file.
  /// Throws [PdfRenderException] or [PdfRenderTimeoutException] on failure.
  Future<String> renderPage({
    required String pdfPath,
    required int pageNumber, // 1-indexed
    DpiPreset dpi = DpiPreset.high200,
    int? rotationDegrees,
  });

  /// Cleans up rendered temporary image files.
  Future<void> cleanup();
}

/// Production Windows WinRT PDF page renderer using Windows.Data.Pdf API.
/// Zero placeholder fallbacks: either produces genuine raster image or throws controlled PdfRenderException.
class WinRtPdfPageRenderer implements PdfPageRenderer {
  final Directory tempDir;
  final Duration timeout;

  WinRtPdfPageRenderer({
    required this.tempDir,
    this.timeout = const Duration(seconds: 30),
  });

  @override
  Future<String> renderPage({
    required String pdfPath,
    required int pageNumber, // 1-indexed
    DpiPreset dpi = DpiPreset.high200,
    int? rotationDegrees,
  }) async {
    final pdfFile = File(pdfPath);
    if (!pdfFile.existsSync()) {
      throw PdfRenderException('Tệp PDF nguồn không tồn tại: $pdfPath');
    }

    if (!tempDir.existsSync()) {
      tempDir.createSync(recursive: true);
    }

    final rotSuffix = rotationDegrees != null ? '_rot$rotationDegrees' : '';
    final outFilename =
        '${p.basenameWithoutExtension(pdfPath)}_page_${pageNumber}_${dpi.dpiValue}dpi$rotSuffix.png';
    final outPath = p.join(tempDir.path, outFilename);
    final outFile = File(outPath);

    if (outFile.existsSync() && outFile.lengthSync() > 0) {
      return outPath;
    }

    if (!Platform.isWindows) {
      throw const PdfRenderException(
        'Động cơ kết xuất Windows.Data.Pdf chỉ hỗ trợ môi trường hệ điều hành Windows.',
      );
    }

    final success = await _renderWithWindowsWinRt(
      pdfPath: pdfPath,
      pageIndex: pageNumber - 1,
      dpi: dpi.dpiValue,
      outPngPath: outPath,
      rotationDegrees: rotationDegrees,
    );

    if (success && outFile.existsSync() && outFile.lengthSync() > 0) {
      return outPath;
    }

    throw PdfRenderException(
      'Không thể kết xuất trang $pageNumber từ tệp PDF: ${p.basename(pdfPath)}. '
      'WinRT Render pipeline trả về lỗi hoặc tệp ảnh kết xuất không hợp lệ.',
    );
  }

  /// Renders page via Windows.Data.Pdf.PdfDocument API using a dedicated PowerShell helper.
  Future<bool> _renderWithWindowsWinRt({
    required String pdfPath,
    required int pageIndex,
    required int dpi,
    required String outPngPath,
    int? rotationDegrees,
  }) async {
    Process? process;
    try {
      final script = '''
Add-Type -AssemblyName System.Runtime.WindowsRuntime
[Windows.Data.Pdf.PdfDocument, Windows.Data.Pdf, ContentType = WindowsRuntime] | Out-Null
[Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime] | Out-Null
[Windows.Storage.StorageFolder, Windows.Storage, ContentType = WindowsRuntime] | Out-Null
[Windows.Storage.Streams.IRandomAccessStream, Windows.Storage.Streams, ContentType = WindowsRuntime] | Out-Null

\$asTaskOp = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    \$_.Name -eq "AsTask" -and \$_.GetParameters().Count -eq 1 -and \$_.GetParameters()[0].ParameterType.Name.StartsWith("IAsyncOperation")
} | Select-Object -First 1

\$asTaskAction = [System.WindowsRuntimeSystemExtensions].GetMethod("AsTask", [Type[]]@([Windows.Foundation.IAsyncAction]))

function Await-Op(\$op, [Type]\$targetType) {
    \$m = \$asTaskOp.MakeGenericMethod(\$targetType)
    return \$m.Invoke(\$null, @(\$op)).GetAwaiter().GetResult()
}

function Await-Action(\$action) {
    \$task = \$asTaskAction.Invoke(\$null, @(\$action))
    \$task.GetAwaiter().GetResult()
}

try {
    \$fullPdf = [System.IO.Path]::GetFullPath("$pdfPath")
    \$fullOut = [System.IO.Path]::GetFullPath("$outPngPath")
    \$file = Await-Op ([Windows.Storage.StorageFile]::GetFileFromPathAsync(\$fullPdf)) ([Windows.Storage.StorageFile])
    \$doc = Await-Op ([Windows.Data.Pdf.PdfDocument]::LoadFromFileAsync(\$file)) ([Windows.Data.Pdf.PdfDocument])

    if ($pageIndex -ge \$doc.PageCount) {
        Write-Host "OUT_OF_BOUNDS: pageIndex $pageIndex >= count \$(\$doc.PageCount)"
        exit 1
    }

    \$page = \$doc.GetPage($pageIndex)
    \$outDir = [System.IO.Path]::GetDirectoryName(\$fullOut)
    \$outName = [System.IO.Path]::GetFileName(\$fullOut)

    if (-not [System.IO.Directory]::Exists(\$outDir)) {
        [System.IO.Directory]::CreateDirectory(\$outDir) | Out-Null
    }

    \$folder = Await-Op ([Windows.Storage.StorageFolder]::GetFolderFromPathAsync(\$outDir)) ([Windows.Storage.StorageFolder])
    \$outFile = Await-Op (\$folder.CreateFileAsync(\$outName, [Windows.Storage.CreationCollisionOption]::ReplaceExisting)) ([Windows.Storage.StorageFile])
    \$stream = Await-Op (\$outFile.OpenAsync([Windows.Storage.FileAccessMode]::ReadWrite)) ([Windows.Storage.Streams.IRandomAccessStream])

    \$renderOptions = [Windows.Data.Pdf.PdfPageRenderOptions]::new()
    \$scale = $dpi / 96.0
    \$renderOptions.DestinationWidth = [uint32](\$page.Size.Width * \$scale)
    \$renderOptions.DestinationHeight = [uint32](\$page.Size.Height * \$scale)

    \$renderOp = \$page.RenderToStreamAsync(\$stream, \$renderOptions)
    Await-Action \$renderOp
    \$stream.Dispose()
    \$page.Dispose()
    Write-Host "SUCCESS"
} catch {
    Write-Host "ERROR: \$_"
    exit 2
}
''';

      process = await Process.start(
        'powershell',
        ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', script],
      );

      final stdoutBuf = StringBuffer();
      final stderrBuf = StringBuffer();

      process.stdout.listen((event) => stdoutBuf.write(String.fromCharCodes(event)));
      process.stderr.listen((event) => stderrBuf.write(String.fromCharCodes(event)));

      final exitCode = await process.exitCode.timeout(
        timeout,
        onTimeout: () {
          // Force terminate child process on timeout
          _killProcess(process!);
          throw PdfRenderTimeoutException(
            'Quá thời gian kết xuất PDF ($timeout) cho tệp ${p.basename(pdfPath)} trang ${pageIndex + 1}.',
          );
        },
      );

      final output = stdoutBuf.toString();
      if (exitCode == 0 && output.contains('SUCCESS')) {
        return true;
      }

      AppLogger.warning('WinRT PDF render returned non-success (code $exitCode): $output $stderrBuf');
      return false;
    } on PdfRenderTimeoutException {
      rethrow;
    } catch (e, st) {
      if (process != null) {
        _killProcess(process);
      }
      AppLogger.error('WinRT PDF rendering failed: $e', e, st);
      throw PdfRenderException('Lỗi kết xuất WinRT PDF: $e', e);
    }
  }

  void _killProcess(Process proc) {
    try {
      if (Platform.isWindows) {
        Process.runSync('taskkill', ['/F', '/T', '/PID', proc.pid.toString()]);
      } else {
        proc.kill(ProcessSignal.sigkill);
      }
    } catch (_) {}
  }

  @override
  Future<void> cleanup() async {
    try {
      if (tempDir.existsSync()) {
        for (final entity in tempDir.listSync()) {
          if (entity is File && entity.path.endsWith('.png')) {
            try {
              entity.deleteSync();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }
}

/// Backward compatibility alias
typedef PdfRenderer = WinRtPdfPageRenderer;
