import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/logging/app_logger.dart';

/// Descriptor for an attached webcam or USB document camera.
class CameraDeviceInfo {
  final String id;
  final String name;
  final String? manufacturer;

  const CameraDeviceInfo({
    required this.id,
    required this.name,
    this.manufacturer,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'manufacturer': manufacturer,
      };

  factory CameraDeviceInfo.fromJson(Map<String, dynamic> json) => CameraDeviceInfo(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Camera',
        manufacturer: json['manufacturer'] as String?,
      );
}

/// Windows Camera & Document Camera capture service.
/// Uses Windows MediaCapture / PnP enumeration cleanly.
class WindowsCameraService {
  /// Enumerates connected camera and webcam devices. Returns empty list if none found.
  Future<List<CameraDeviceInfo>> getAvailableCameras() async {
    if (!Platform.isWindows) return const [];

    try {
      const script = r'''
$ErrorActionPreference = 'Stop'
try {
    $cams = Get-PnpDevice -Class "Camera", "Image" -Status OK -ErrorAction SilentlyContinue
    if (-not $cams) {
        $cams = Get-CimInstance Win32_PnPEntity | Where-Object { $_.PNPClass -in @('Camera','Image') }
    }
    $list = @()
    if ($cams) {
        foreach ($c in $cams) {
            $list += @{
                id = $c.DeviceID
                name = $c.Name
                manufacturer = $c.Manufacturer
            }
        }
    }
    @{ cameras = $list } | ConvertTo-Json -Compress
} catch {
    @{ cameras = @() } | ConvertTo-Json -Compress
}
''';

      final res = await Process.run(
        'powershell',
        ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', script],
      ).timeout(const Duration(seconds: 10));

      if (res.exitCode == 0) {
        final out = res.stdout.toString().trim();
        if (out.startsWith('{') && out.contains('"cameras"')) {
          final data = jsonDecode(out) as Map<String, dynamic>;
          final list = data['cameras'] as List<dynamic>? ?? [];
          return list.map((item) {
            final map = item as Map<String, dynamic>;
            return CameraDeviceInfo(
              id: map['id'] as String? ?? '',
              name: map['name'] as String? ?? 'Camera',
              manufacturer: map['manufacturer'] as String?,
            );
          }).toList();
        }
      }
    } catch (e) {
      AppLogger.warning('Camera enumeration probe: $e');
    }

    return const [];
  }

  /// Captures a still photo from the selected camera device and returns saved file path.
  Future<String> captureStill({String? deviceId}) async {
    if (!Platform.isWindows) {
      throw const ScanAcquisitionException('Chức năng camera chỉ hỗ trợ trên hệ điều hành Windows.');
    }

    final cameras = await getAvailableCameras();
    if (cameras.isEmpty) {
      throw const ScanAcquisitionException('Không tìm thấy thiết bị camera hoặc webcam nào được kết nối.');
    }

    final tempDir = Directory(p.join(Directory.current.path, 'temp', 'camera_captures'));
    if (!tempDir.existsSync()) {
      tempDir.createSync(recursive: true);
    }
    final outPath = p.join(tempDir.path, 'capture_${const Uuid().v4()}.jpg');

    // PowerShell MediaCapture capture script
    final script = '''
\$ErrorActionPreference = 'Stop'
try {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    [Windows.Media.Capture.MediaCapture, Windows.Media.Capture, ContentType = WindowsRuntime] | Out-Null
    [Windows.Media.MediaProperties.ImageEncodingProperties, Windows.Media.MediaProperties, ContentType = WindowsRuntime] | Out-Null
    [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime] | Out-Null

    \$asTaskOp = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        \$_.Name -eq "AsTask" -and \$_.GetParameters().Count -eq 1 -and \$_.GetParameters()[0].ParameterType.Name.StartsWith("IAsyncOperation")
    } | Select-Object -First 1

    function Await-Op(\$op, [Type]\$targetType) {
        \$m = \$asTaskOp.MakeGenericMethod(\$targetType)
        return \$m.Invoke(\$null, @(\$op)).GetAwaiter().GetResult()
    }

    \$settings = [Windows.Media.Capture.MediaCaptureInitializationSettings]::new()
    \$capture = [Windows.Media.Capture.MediaCapture]::new()
    Await-Op (\$capture.InitializeAsync(\$settings)) ([System.Void])

    \$props = [Windows.Media.MediaProperties.ImageEncodingProperties]::CreateJpeg()
    \$out = [System.IO.Path]::GetFullPath("${outPath.replaceAll(r'\', r'\\')}")
    \$file = Await-Op ([Windows.Storage.StorageFile]::GetFileFromPathAsync(\$out)) ([Windows.Storage.StorageFile]) -ErrorAction SilentlyContinue
    if (\$null -eq \$file) {
        \$parentDir = [System.IO.Path]::GetDirectoryName(\$out)
        \$folder = Await-Op ([Windows.Storage.StorageFolder]::GetFolderFromPathAsync(\$parentDir)) ([Windows.Storage.StorageFolder])
        \$file = Await-Op (\$folder.CreateFileAsync([System.IO.Path]::GetFileName(\$out), [Windows.Storage.CreationCollisionOption]::ReplaceExisting)) ([Windows.Storage.StorageFile])
    }

    Await-Op (\$capture.CapturePhotoToStorageFileAsync(\$props, \$file)) ([System.Void])
    \$capture.Dispose()
    Write-Host "CAMERA_OK:\$out"
} catch {
    Write-Host "CAMERA_ERR:" \$_.Exception.Message
    exit 1
}
''';

    final res = await Process.run(
      'powershell',
      ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', script],
    ).timeout(const Duration(seconds: 25));

    final out = res.stdout.toString().trim();
    if (res.exitCode == 0 && out.contains('CAMERA_OK:')) {
      return outPath;
    }

    throw ScanAcquisitionException(
      'Không thể chụp ảnh từ Camera. Vui lòng kiểm tra quyền truy cập camera trong Windows Settings.',
      technicalDetails: '$out \n ${res.stderr}',
    );
  }
}
