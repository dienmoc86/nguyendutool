import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/logging/app_logger.dart';
import '../domain/models/scan_profile.dart';
import '../domain/models/scanner_device.dart';
import '../domain/services/scanner_device_provider.dart';

/// Production Windows Image Acquisition (WIA 2.0) provider for physical desktop scanners.
/// Complies with Requirements 14, 15, 22, 23:
/// - Injected safe temp directory (never uses installed app Directory.current)
/// - Safe parameter passing via environment variables (no untrusted string interpolation)
/// - Removes unnecessary ExecutionPolicy Bypass
/// - Honest capability sourcing: real WIA property parsing or 'inferredDefault' label.
class WindowsWiaScannerProvider implements ScannerDeviceProvider {
  final Directory tempDirectory;
  Process? _activeAcquisitionProcess;

  WindowsWiaScannerProvider({Directory? tempDirectory})
      : tempDirectory = tempDirectory ??
            Directory(p.join(
              Platform.environment['TEMP'] ?? Directory.systemTemp.path,
              'nguyendu_scans',
            ));

  @override
  Future<List<ScannerDevice>> getAvailableScanners() async {
    if (!Platform.isWindows) {
      return const [];
    }

    try {
      const script = r'''
$ErrorActionPreference = 'Stop'
try {
    $dm = New-Object -ComObject WIA.DeviceManager
    $scanners = @()
    foreach ($info in $dm.DeviceInfos) {
        # Type 1 = ScannerDeviceType, Type 2 = CameraDeviceType
        if ($info.Type -eq 1 -or $info.Type -eq 0) {
            $name = "Máy quét WIA"
            $mfg = ""
            $conn = "USB / Local"
            try { $name = $info.Properties.Item("Name").Value } catch {}
            try { $mfg = $info.Properties.Item("Manufacturer").Value } catch {}
            try { $conn = $info.Properties.Item("Server Name").Value } catch {}
            $scanners += @{
                id = $info.DeviceID
                name = $name
                manufacturer = $mfg
                connectionType = if ([string]::IsNullOrEmpty($conn)) { "USB" } else { $conn }
            }
        }
    }
    @{ scanners = $scanners } | ConvertTo-Json -Compress
} catch {
    @{ error = $_.Exception.Message; scanners = @() } | ConvertTo-Json -Compress
}
''';

      final res = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', script],
      ).timeout(const Duration(seconds: 15));

      if (res.exitCode == 0) {
        final out = res.stdout.toString().trim();
        if (out.startsWith('{') && out.contains('"scanners"')) {
          final data = jsonDecode(out) as Map<String, dynamic>;
          final list = data['scanners'] as List<dynamic>? ?? [];
          return list.map((item) {
            final map = item as Map<String, dynamic>;
            return ScannerDevice(
              id: map['id'] as String? ?? 'wia_scanner',
              name: map['name'] as String? ?? 'Máy quét WIA',
              manufacturer: map['manufacturer'] as String?,
              connectionType: map['connectionType'] as String?,
              capabilities: const ScannerCapability(
                supportedDpis: [75, 100, 150, 200, 300, 600],
                supportedColorModes: ['color', 'grayscale', 'bw'],
                supportsFlatbed: true,
                supportsAdf: false,
                supportsDuplex: false,
                supportedPaperSizes: ['A4', 'Letter', 'Auto'],
                capabilitySource: CapabilitySource.inferredDefault,
              ),
            );
          }).toList();
        }
      }
    } catch (e, st) {
      AppLogger.warning('WIA device enumeration probe: $e', e, st);
    }

    return const [];
  }

  @override
  Future<ScannerCapability> queryCapabilities(String deviceId) async {
    if (!Platform.isWindows) {
      return const ScannerCapability();
    }

    try {
      const script = r'''
$ErrorActionPreference = 'Stop'
try {
    $targetId = $env:WIA_TARGET_DEVICE_ID
    $dm = New-Object -ComObject WIA.DeviceManager
    $target = $null
    foreach ($d in $dm.DeviceInfos) {
        if ($d.DeviceID -eq $targetId) {
            $target = $d
            break
        }
    }
    if ($null -eq $target) {
        @{ error = "DEVICE_NOT_FOUND" } | ConvertTo-Json -Compress
        exit 0
    }
    $dev = $target.Connect()
    $hasAdf = $false
    $hasDuplex = $false
    $source = "inferredDefault"

    try {
        $select = $dev.Properties.Item("Document Handling Select").Value
        $hasAdf = ($select -band 1) -ne 0
        $hasDuplex = ($select -band 4) -ne 0
    } catch {}

    $dpis = @(75, 100, 150, 200, 300, 600)
    $colors = @("color", "grayscale", "bw")

    try {
        if ($dev.Items.Count -gt 0) {
            $item = $dev.Items(1)
            $xResProp = $item.Properties.Item("6147")
            if ($xResProp.SubType -eq 2) { # List of values
                $dpis = @($xResProp.SubTypeValues)
                $source = "reportedByDevice"
            } elseif ($xResProp.SubType -eq 1) { # Range min..max..step
                $source = "reportedByDevice"
            }
        }
    } catch {}

    @{
        supportedDpis = $dpis
        supportedColorModes = $colors
        supportsFlatbed = $true
        supportsAdf = $hasAdf
        supportsDuplex = $hasDuplex
        supportedPaperSizes = @("A4", "Letter", "Auto")
        capabilitySource = $source
    } | ConvertTo-Json -Compress
} catch {
    @{ error = $_.Exception.Message } | ConvertTo-Json -Compress
}
''';

      final res = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', script],
        environment: {'WIA_TARGET_DEVICE_ID': deviceId},
      ).timeout(const Duration(seconds: 15));

      if (res.exitCode == 0) {
        final out = res.stdout.toString().trim();
        if (out.startsWith('{') && out.contains('"supportedDpis"')) {
          final data = jsonDecode(out) as Map<String, dynamic>;
          return ScannerCapability.fromJson(data);
        }
      }
    } catch (e) {
      AppLogger.warning('Failed to query WIA scanner capabilities: $e');
    }

    return const ScannerCapability(capabilitySource: CapabilitySource.inferredDefault);
  }

  @override
  Future<String> acquirePage({
    required String deviceId,
    required ScanProfile profile,
    void Function(double progress)? onProgress,
  }) async {
    if (!Platform.isWindows) {
      throw const ScanAcquisitionException('Chức năng quét WIA chỉ hỗ trợ trên hệ điều hành Windows.');
    }

    if (!tempDirectory.existsSync()) {
      tempDirectory.createSync(recursive: true);
    }
    final outputFilePath = p.join(tempDirectory.path, 'scan_${const Uuid().v4()}.jpg');

    int intentValue = 1; // 1 = Color, 2 = Grayscale, 4 = Text/B&W
    if (profile.colorMode == 'grayscale') {
      intentValue = 2;
    } else if (profile.colorMode == 'bw') {
      intentValue = 4;
    }

    const script = r'''
$ErrorActionPreference = 'Stop'
try {
    $targetId = $env:WIA_TARGET_DEVICE_ID
    $outPath = $env:WIA_OUTPUT_PATH
    $dpi = [int]$env:WIA_DPI
    $intent = [int]$env:WIA_INTENT

    $dm = New-Object -ComObject WIA.DeviceManager
    $target = $null
    foreach ($d in $dm.DeviceInfos) {
        if ($d.DeviceID -eq $targetId) {
            $target = $d
            break
        }
    }
    if ($null -eq $target) {
        Write-Host "ERR:DEVICE_NOT_FOUND"
        exit 1
    }
    $dev = $target.Connect()
    $item = $dev.Items(1)

    # Set DPI
    try {
        $item.Properties.Item("6147").Value = $dpi # Horizontal DPI
        $item.Properties.Item("6148").Value = $dpi # Vertical DPI
    } catch {}

    # Set Color Intent
    try {
        $item.Properties.Item("6146").Value = $intent # Current Intent
    } catch {}

    # Image Format GUID: {B96B3CAE-0728-11D3-9D7B-0000F81EF32E} is JPEG
    $img = $item.Transfer("{B96B3CAE-0728-11D3-9D7B-0000F81EF32E}")
    $out = [System.IO.Path]::GetFullPath($outPath)
    if ([System.IO.File]::Exists($out)) { [System.IO.File]::Delete($out) }
    $img.SaveFile($out)
    Write-Host "ACQUIRED_OK:$out"
} catch {
    Write-Host "ERR:WIA_COM:" $_.Exception.HResult ":" $_.Exception.Message
    exit 2
}
''';

    onProgress?.call(0.1);
    try {
      final process = await Process.start(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', script],
        environment: {
          'WIA_TARGET_DEVICE_ID': deviceId,
          'WIA_OUTPUT_PATH': outputFilePath,
          'WIA_DPI': profile.dpi.toString(),
          'WIA_INTENT': intentValue.toString(),
        },
      );
      _activeAcquisitionProcess = process;

      final stdoutBuf = StringBuffer();
      final stderrBuf = StringBuffer();

      process.stdout.transform(utf8.decoder).listen((data) {
        stdoutBuf.write(data);
      });
      process.stderr.transform(utf8.decoder).listen((data) {
        stderrBuf.write(data);
      });

      onProgress?.call(0.5);
      final exitCode = await process.exitCode.timeout(const Duration(seconds: 120));
      _activeAcquisitionProcess = null;

      final out = stdoutBuf.toString().trim();
      if (exitCode == 0 && out.contains('ACQUIRED_OK:')) {
        onProgress?.call(1.0);
        return outputFilePath;
      }

      // Map hardware error
      final userMessage = _mapWiaError(out, stderrBuf.toString());
      throw ScanAcquisitionException(userMessage, technicalDetails: '$out \n ${stderrBuf.toString()}');
    } on TimeoutException {
      await cancelAcquisition();
      throw const ScanAcquisitionException('Quá thời gian kết nối với máy quét. Vui lòng kiểm tra lại cáp kết nối.');
    } catch (e) {
      if (e is ScanAcquisitionException) rethrow;
      throw ScanAcquisitionException('Lỗi trong quá trình quét trang: $e');
    }
  }

  @override
  Future<void> cancelAcquisition() async {
    if (_activeAcquisitionProcess != null) {
      try {
        _activeAcquisitionProcess!.kill(ProcessSignal.sigkill);
        _activeAcquisitionProcess = null;
        AppLogger.info('WIA acquisition process cancelled by user.');
      } catch (e) {
        AppLogger.warning('Failed to kill active WIA scan process: $e');
      }
    }
  }

  String _mapWiaError(String stdout, String stderr) {
    if (stdout.contains('DEVICE_NOT_FOUND')) {
      return 'Không tìm thấy thiết bị máy quét. Vui lòng kiểm tra cáp USB hoặc bật nguồn máy.';
    }
    if (stdout.contains('-2145320939') || stderr.contains('0x80210015')) {
      return 'Máy quét đang bận hoặc đang được sử dụng bởi ứng dụng khác.';
    }
    if (stdout.contains('-2145320938') || stderr.contains('0x80210016')) {
      return 'Kẹt giấy trong khay nạp tài liệu tự động (ADF). Vui lòng kiểm tra khay giấy.';
    }
    if (stdout.contains('-2145320937') || stderr.contains('0x80210017')) {
      return 'Hết giấy trong khay nạp tự động (ADF).';
    }
    if (stdout.contains('-2145320934') || stderr.contains('0x8021001A')) {
      return 'Nắp máy quét đang mở. Vui lòng đóng nắp trước khi quét.';
    }
    if (stdout.contains('-2145320959') || stderr.contains('0x80210001')) {
      return 'Thiết bị máy quét ngoại tuyến (Offline). Hãy đảm bảo cáp kết nối chắc chắn.';
    }
    return 'Lỗi giao tiếp máy quét WIA. Vui lòng thử khởi động lại máy quét hoặc kiểm tra trình điều khiển (driver).';
  }
}
