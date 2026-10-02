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
  String? _resolveFfmpegPath() {
    final candidates = [
      p.join(p.dirname(Platform.resolvedExecutable), 'bin', 'ffmpeg.exe'),
      p.join(Directory.current.path, 'bin', 'ffmpeg.exe'),
      p.join(p.dirname(Platform.resolvedExecutable), 'ffmpeg.exe'),
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }
    return null;
  }

  /// Enumerates connected camera and webcam devices. Returns empty list if none found.
  Future<List<CameraDeviceInfo>> getAvailableCameras() async {
    if (!Platform.isWindows) return const [];

    final cameras = <CameraDeviceInfo>[];
    final seen = <String>{};

    // 1. Probe PnP Camera & Image devices via PowerShell
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
          for (final item in list) {
            final map = item as Map<String, dynamic>;
            final id = map['id'] as String? ?? '';
            final name = map['name'] as String? ?? 'Camera';
            final key = name.toLowerCase();
            if (!seen.contains(key)) {
              seen.add(key);
              cameras.add(CameraDeviceInfo(
                id: id,
                name: name,
                manufacturer: map['manufacturer'] as String?,
              ));
            }
          }
        }
      }
    } catch (e) {
      AppLogger.warning('Camera PnP enumeration probe: $e');
    }

    // 2. Also probe DirectShow video capture devices (DroidCam, Iriun Webcam, USB capture)
    try {
      final ffmpegPath = _resolveFfmpegPath();
      if (ffmpegPath != null) {
        final res = await Process.run(
          ffmpegPath,
          ['-list_devices', 'true', '-f', 'dshow', '-i', 'dummy'],
        ).timeout(const Duration(seconds: 5));
        final combinedOutput = '${res.stdout}\n${res.stderr}';
        final dshowRegex = RegExp(r'\[dshow\s*@\s*[^\]]+\]\s*"([^"]+)"\s*\(video\)');
        for (final match in dshowRegex.allMatches(combinedOutput)) {
          final camName = match.group(1)?.trim();
          if (camName != null && camName.isNotEmpty) {
            final key = camName.toLowerCase();
            if (!seen.contains(key)) {
              seen.add(key);
              cameras.add(CameraDeviceInfo(
                id: camName,
                name: camName,
                manufacturer: 'DirectShow / Phone Camera',
              ));
            }
          }
        }
      }
    } catch (e) {
      AppLogger.warning('DirectShow camera enumeration: $e');
    }

    return cameras;
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

    final targetCamera = deviceId != null
        ? cameras.firstWhere(
            (c) => c.id == deviceId || c.name == deviceId,
            orElse: () => cameras.first,
          )
        : cameras.first;

    final tempDir = Directory(p.join(
      Platform.environment['TEMP'] ?? Directory.systemTemp.path,
      'nguyendu_captures',
    ));
    if (!tempDir.existsSync()) {
      tempDir.createSync(recursive: true);
    }
    final outPath = p.join(tempDir.path, 'capture_${const Uuid().v4()}.jpg');

    // Attempt 1: Try FFmpeg DirectShow capture for ultra-fast, robust capture (DroidCam, Iriun, webcams)
    try {
      final ffmpegPath = _resolveFfmpegPath();
      if (ffmpegPath != null) {
        final ffmpegRes = await Process.run(
          ffmpegPath,
          [
            '-f', 'dshow',
            '-i', 'video=${targetCamera.name}',
            '-frames:v', '1',
            '-q:v', '2',
            outPath,
            '-y',
          ],
        ).timeout(const Duration(seconds: 12));

        if (ffmpegRes.exitCode == 0 && File(outPath).existsSync() && File(outPath).lengthSync() > 0) {
          return outPath;
        }
      }
    } catch (e) {
      AppLogger.info('FFmpeg DirectShow capture fallback to WinRT: $e');
    }

    // Attempt 2: Fall back to PowerShell WinRT MediaCapture
    final devId = targetCamera.id;
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
    if ('$devId' -and '$devId' -ne '$targetCamera.name') {
        \$settings.VideoDeviceId = '$devId'
    }
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
      'Không thể chụp ảnh từ Camera (${targetCamera.name}). Vui lòng kiểm tra kết nối thiết bị hoặc quyền truy cập Camera trong Windows Settings.',
      technicalDetails: '$out \n ${res.stderr}',
    );
  }
}
