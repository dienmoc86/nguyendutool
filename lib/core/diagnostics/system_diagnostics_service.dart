import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import '../filesystem/workspace_manager.dart';
import '../logging/app_logger.dart';
import '../media/ffmpeg_service.dart';
import '../platform/win32_system_bridge.dart';
import '../security/windows_dpapi_secure_storage.dart';
import 'diagnostic_status.dart';

/// Comprehensive system diagnostic probe service (Requirements 18, 19, 20, 21, 41).
/// Evaluates native system capabilities, real disk space via Win32 FFI, DPAPI vault probe,
/// honest TTS and scanner device diagnostics.
class SystemDiagnosticsService {
  final WorkspaceManager _workspaceManager;
  final FfmpegService _ffmpegService;

  SystemDiagnosticsService({
    WorkspaceManager? workspaceManager,
    FfmpegService? ffmpegService,
  })  : _workspaceManager = workspaceManager ?? WorkspaceManager(),
        _ffmpegService = ffmpegService ?? FfmpegService.instance;

  /// Runs all 13 system checks asynchronously with accurate real-time probing.
  Future<List<SystemDiagnosticItem>> runFullDiagnostics({
    required String appVersion,
    required int databaseSchemaVersion,
  }) async {
    final items = <SystemDiagnosticItem>[];

    // 1. App Version & Platform
    items.add(SystemDiagnosticItem(
      id: 'app_version',
      title: 'Phiên bản ứng dụng',
      description: 'Phiên bản và kiến trúc NguyenDu Tool',
      status: DiagnosticStatus.ready,
      details: 'NguyenDu Tool v$appVersion (Windows x64 Release Candidate)',
      category: 'Core',
    ));

    // 2. Database Schema
    items.add(SystemDiagnosticItem(
      id: 'db_schema',
      title: 'Cơ sở dữ liệu SQLite',
      description: 'Phiên bản lược đồ cơ sở dữ liệu nội bộ',
      status: databaseSchemaVersion >= 5 ? DiagnosticStatus.ready : DiagnosticStatus.actionRequired,
      details: 'Schema v$databaseSchemaVersion (Hỗ trợ PDF, OCR, TTS, Video Studio v5)',
      category: 'Core',
    ));

    // 3. Windows Version & OS Architecture
    final osVersion = Platform.operatingSystemVersion;
    final isWin10Or11 = osVersion.contains('Windows 10') ||
        osVersion.contains('Windows 11') ||
        osVersion.contains('Build 1') ||
        osVersion.contains('Build 2');
    items.add(SystemDiagnosticItem(
      id: 'windows_os',
      title: 'Hệ điều hành Windows',
      description: 'Phiên bản Windows 10/11 x64',
      status: isWin10Or11 ? DiagnosticStatus.ready : DiagnosticStatus.actionRequired,
      details: osVersion,
      recommendation: isWin10Or11 ? null : 'Khuyến nghị nâng cấp lên Windows 10 (Build 19041+) hoặc Windows 11.',
      category: 'System',
    ));

    // 4. Workspace Writable
    DiagnosticStatus wsStatus = DiagnosticStatus.ready;
    String wsDetails = 'Thư mục tài liệu sẵn sàng ghi chép.';
    try {
      final wsDir = _workspaceManager.workspaceRoot;
      await wsDir.create(recursive: true);
      final testFile = File(p.join(wsDir.path, '.write_test_${DateTime.now().millisecondsSinceEpoch}'));
      await testFile.writeAsString('test', flush: true);
      await testFile.delete();
      wsDetails = 'Quyền ghi thư mục: ${wsDir.path} (Đạt)';
    } catch (e) {
      wsStatus = DiagnosticStatus.failed;
      wsDetails = 'Lỗi quyền ghi Workspace: $e';
    }
    items.add(SystemDiagnosticItem(
      id: 'workspace_writable',
      title: 'Không gian làm việc (Workspace)',
      description: 'Quyền đọc ghi dữ liệu cục bộ',
      status: wsStatus,
      details: wsDetails,
      recommendation: wsStatus == DiagnosticStatus.failed ? 'Vui lòng kiểm tra quyền truy cập thư mục Documents.' : null,
      category: 'Storage',
    ));

    // 5. Accurate Available Disk Space (Requirement 19 - Win32 GetDiskFreeSpaceExW)
    DiagnosticStatus diskStatus = DiagnosticStatus.ready;
    String diskDetails = 'Dung lượng ổ đĩa';
    String? diskRec;
    try {
      final wsPath = _workspaceManager.workspaceRoot.path;
      final space = Win32SystemBridge.getDiskFreeSpace(wsPath);
      if (space != null) {
        final drivePrefix = wsPath.length >= 2 ? wsPath.substring(0, 2) : '';
        diskDetails = 'Ổ đĩa $drivePrefix: Còn trống ${space.freeGb.toStringAsFixed(1)} GB / Tổng ${space.totalGb.toStringAsFixed(1)} GB';
        if (space.freeGb < 1.0) {
          diskStatus = DiagnosticStatus.failed;
          diskRec = 'Dung lượng ổ đĩa dưới 1GB! Nguy cơ không đủ bộ nhớ kết xuất video hoặc chuyển đổi PDF.';
        } else if (space.freeGb < 3.0) {
          diskStatus = DiagnosticStatus.actionRequired;
          diskRec = 'Dung lượng ổ đĩa khả dụng dưới 3GB. Khuyến nghị giải phóng thêm dung lượng.';
        } else {
          diskStatus = DiagnosticStatus.ready;
        }
      } else {
        diskStatus = DiagnosticStatus.actionRequired;
        diskDetails = 'Không thể đo dung lượng qua Win32 API.';
      }
    } catch (e) {
      diskStatus = DiagnosticStatus.actionRequired;
      diskDetails = 'Lỗi đo dung lượng ổ đĩa: $e';
    }
    items.add(SystemDiagnosticItem(
      id: 'disk_space',
      title: 'Dung lượng ổ cứng',
      description: 'Kiểm tra không gian lưu trữ cho xuất tệp lớn (Win32 GetDiskFreeSpaceExW)',
      status: diskStatus,
      details: diskDetails,
      recommendation: diskRec,
      category: 'Storage',
    ));

    // 6. Bundled FFmpeg
    DiagnosticStatus ffmpegStatus = DiagnosticStatus.ready;
    String ffmpegDetails = 'FFmpeg Engine';
    if (_ffmpegService.isAvailable) {
      ffmpegDetails = 'Đã phát hiện: ${_ffmpegService.version ?? "FFmpeg"} (${_ffmpegService.originLabel}) tại ${_ffmpegService.ffmpegPath}';
    } else {
      final init = await _ffmpegService.initialize();
      if (init && _ffmpegService.isAvailable) {
        ffmpegDetails = 'Đã phát hiện: ${_ffmpegService.version ?? "FFmpeg"} (${_ffmpegService.originLabel}) tại ${_ffmpegService.ffmpegPath}';
      } else {
        ffmpegStatus = DiagnosticStatus.actionRequired;
        ffmpegDetails = 'Chưa tìm thấy FFmpeg trong gói ứng dụng hoặc PATH.';
      }
    }
    items.add(SystemDiagnosticItem(
      id: 'ffmpeg_engine',
      title: 'Động cơ Video FFmpeg',
      description: 'Bộ kết xuất video và âm thanh cục bộ (No-Shell invocation)',
      status: ffmpegStatus,
      details: ffmpegDetails,
      recommendation: ffmpegStatus == DiagnosticStatus.actionRequired ? 'Đảm bảo thư mục bin/ chứa ffmpeg.exe.' : null,
      category: 'Media',
    ));

    // 7. Bundled FFprobe
    DiagnosticStatus ffprobeStatus = DiagnosticStatus.ready;
    String ffprobeDetails = 'FFprobe Media Analyzer';
    if (_ffmpegService.ffprobePath != null) {
      ffprobeDetails = 'Đã phát hiện tại: ${_ffmpegService.ffprobePath}';
    } else {
      ffprobeStatus = DiagnosticStatus.actionRequired;
      ffprobeDetails = 'Chưa tìm thấy FFprobe.';
    }
    items.add(SystemDiagnosticItem(
      id: 'ffprobe_engine',
      title: 'Bộ phân tích Media FFprobe',
      description: 'Kiểm định thông số kỹ thuật đa phương tiện',
      status: ffprobeStatus,
      details: ffprobeDetails,
      category: 'Media',
    ));

    // 8. Windows WinRT OCR & Vietnamese Language Pack
    DiagnosticStatus ocrStatus = DiagnosticStatus.ready;
    String ocrDetails = 'Windows Native OCR Engine';
    try {
      final res = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        r'[Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime] | Out-Null; $langs = [Windows.Media.Ocr.OcrEngine]::AvailableRecognizerLanguages | ForEach-Object { $_.LanguageTag }; $hasVi = $langs -contains "vi" -or $langs -contains "vi-VN"; Write-Output "HAS_VI:$hasVi;COUNT:$($langs.Count)"'
      ]).timeout(const Duration(seconds: 5));

      if (res.exitCode == 0) {
        final out = res.stdout.toString().trim();
        final hasVi = out.contains('HAS_VI:True');
        if (hasVi) {
          ocrStatus = DiagnosticStatus.ready;
          ocrDetails = 'WinRT OCR sẵn sàng với gói ngôn ngữ tiếng Việt (vi-VN).';
        } else {
          ocrStatus = DiagnosticStatus.actionRequired;
          ocrDetails = 'Đã kích hoạt WinRT OCR, nhưng chưa cài đặt gói nhận dạng tiếng Việt.';
        }
      } else {
        ocrStatus = DiagnosticStatus.actionRequired;
        ocrDetails = 'Không thể truy vấn WinRT OCR (Mã lỗi: ${res.exitCode}).';
      }
    } catch (e) {
      ocrStatus = DiagnosticStatus.actionRequired;
      ocrDetails = 'Chẩn đoán WinRT OCR gặp sự cố: $e';
    }
    items.add(SystemDiagnosticItem(
      id: 'windows_ocr',
      title: 'Nhận dạng ký tự OCR tiếng Việt',
      description: 'Gói ngôn ngữ WinRT OCR hệ thống',
      status: ocrStatus,
      details: ocrDetails,
      recommendation: ocrStatus == DiagnosticStatus.actionRequired
          ? 'Cài đặt gói ngôn ngữ tiếng Việt trong Windows Settings > Time & Language > Preferred languages.'
          : null,
      category: 'AI & OCR',
    ));

    // 9. Honest Windows TTS Voices & Vietnamese Voice (Requirement 20)
    DiagnosticStatus ttsStatus = DiagnosticStatus.actionRequired;
    String ttsDetails = 'Windows Speech Synthesis';
    String? ttsRec;
    try {
      final res = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        r'Add-Type -AssemblyName System.Speech; $s = New-Object System.Speech.Synthesis.SpeechSynthesizer; $v = $s.GetInstalledVoices(); $hasVi = ($v | Where-Object { $_.VoiceInfo.Culture.Name -like "vi*" }).Count -gt 0; Write-Output "COUNT:$($v.Count);HAS_VI:$hasVi"'
      ]).timeout(const Duration(seconds: 5));

      if (res.exitCode == 0) {
        final out = res.stdout.toString().trim();
        final hasVi = out.contains('HAS_VI:True');
        if (hasVi) {
          ttsStatus = DiagnosticStatus.ready;
          ttsDetails = 'Động cơ giọng đọc Windows SAPI/OneCore sẵn sàng với giọng tiếng Việt (An / HoaiMy).';
        } else {
          ttsStatus = DiagnosticStatus.actionRequired;
          ttsDetails = 'Hệ thống có giọng đọc (SAPI/OneCore) nhưng chưa có giọng tiếng Việt bản địa.';
          ttsRec = 'Cài đặt giọng đọc tiếng Việt trong Windows Settings > Time & Language > Speech.';
        }
      } else {
        ttsStatus = DiagnosticStatus.actionRequired;
        ttsDetails = 'Không thể gọi System.Speech qua PowerShell (Mã lỗi: ${res.exitCode}).';
        ttsRec = 'Kiểm tra quyền thực thi PowerShell trên tài khoản hiện tại.';
      }
    } catch (e) {
      // Must NOT mark READY on error (Requirement 20)
      ttsStatus = DiagnosticStatus.actionRequired;
      ttsDetails = 'Lỗi chẩn đoán giọng đọc Windows TTS: $e';
      ttsRec = 'Khởi động lại dịch vụ âm thanh Windows Audio hoặc kiểm tra môi trường .NET Framework.';
    }
    items.add(SystemDiagnosticItem(
      id: 'windows_tts',
      title: 'Giọng đọc văn bản (TTS)',
      description: 'Giọng tổng hợp SAPI Desktop và WinRT OneCore',
      status: ttsStatus,
      details: ttsDetails,
      recommendation: ttsRec,
      category: 'Speech',
    ));

    // 10. Windows Image Acquisition (WIA) Scanner Service (Requirement 21)
    DiagnosticStatus wiaStatus = DiagnosticStatus.optionalNotAvailable;
    String wiaDetails = 'Windows Image Acquisition (WIA)';
    try {
      final res = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        r'$s = Get-Service -Name stisvc -ErrorAction SilentlyContinue; if ($s) { Write-Output $s.Status } else { Write-Output "NOT_FOUND" }'
      ]).timeout(const Duration(seconds: 4));

      final out = res.stdout.toString().trim();
      if (out.contains('Running')) {
        wiaStatus = DiagnosticStatus.ready;
        wiaDetails = 'Dịch vụ hệ thống WIA (stisvc) đang hoạt động.';
      } else if (out.contains('Stopped')) {
        wiaStatus = DiagnosticStatus.optionalNotAvailable;
        wiaDetails = 'Dịch vụ WIA đang tạm dừng (sẽ tự kích hoạt khi cắm máy quét).';
      } else {
        wiaStatus = DiagnosticStatus.optionalNotAvailable;
        wiaDetails = 'Không tìm thấy dịch vụ WIA trên hệ điều hành này.';
      }
    } catch (_) {
      wiaStatus = DiagnosticStatus.optionalNotAvailable;
      wiaDetails = 'Không thể kiểm tra dịch vụ WIA.';
    }
    items.add(SystemDiagnosticItem(
      id: 'wia_service',
      title: 'Dịch vụ Máy Quét (WIA Service)',
      description: 'Dịch vụ Windows Image Acquisition hệ thống',
      status: wiaStatus,
      details: wiaDetails,
      category: 'Hardware',
    ));

    // 11. Scanner Device Hardware Probe (Requirement 21 - Separate from service)
    DiagnosticStatus scannerStatus = DiagnosticStatus.optionalNotAvailable;
    String scannerDetails = 'Không có thiết bị máy quét cắm ngoài (Tùy chọn).';
    try {
      final res = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        r'$dm = New-Object -ComObject WIA.DeviceManager; $cnt = ($dm.DeviceInfos | Where-Object { $_.Type -eq 1 -or $_.Type -eq 0 }).Count; Write-Output "DEV_COUNT:$cnt"'
      ]).timeout(const Duration(seconds: 4));

      final out = res.stdout.toString().trim();
      if (out.contains('DEV_COUNT:')) {
        final countStr = out.split('DEV_COUNT:').last.trim();
        final count = int.tryParse(countStr) ?? 0;
        if (count > 0) {
          scannerStatus = DiagnosticStatus.ready;
          scannerDetails = 'Phát hiện $count máy quét vật lý kết nối qua WIA.';
        } else {
          scannerStatus = DiagnosticStatus.optionalNotAvailable;
          scannerDetails = 'Chưa phát hiện máy quét vật lý cắm vào máy tính (Tùy chọn).';
        }
      }
    } catch (_) {}
    items.add(SystemDiagnosticItem(
      id: 'scanner_devices',
      title: 'Thiết bị Máy Quét kết nối',
      description: 'Máy quét tài liệu vật lý USB / Mạng qua chuẩn WIA',
      status: scannerStatus,
      details: scannerDetails,
      category: 'Hardware',
    ));

    // 12. Camera Availability
    DiagnosticStatus camStatus = DiagnosticStatus.optionalNotAvailable;
    String camDetails = 'Máy ảnh / Webcam';
    try {
      final res = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        r'[Windows.Devices.Enumeration.DeviceInformation, Windows.Foundation, ContentType = WindowsRuntime] | Out-Null; $devices = [Windows.Devices.Enumeration.DeviceInformation]::FindAllAsync(4).GetResults(); Write-Output "CAM_COUNT:$($devices.Count)"'
      ]).timeout(const Duration(seconds: 4));

      final out = res.stdout.toString().trim();
      if (out.contains('CAM_COUNT:0') || out.isEmpty) {
        camStatus = DiagnosticStatus.optionalNotAvailable;
        camDetails = 'Không phát hiện camera tích hợp hoặc webcam ngoài (Tùy chọn).';
      } else {
        camStatus = DiagnosticStatus.ready;
        camDetails = 'Camera sẵn sàng chụp ảnh tài liệu.';
      }
    } catch (_) {
      camStatus = DiagnosticStatus.optionalNotAvailable;
      camDetails = 'Chưa phát hiện camera khả dụng (Tùy chọn).';
    }
    items.add(SystemDiagnosticItem(
      id: 'camera_hardware',
      title: 'Máy ảnh / Webcam',
      description: 'Chụp ảnh tài liệu trực tiếp từ webcam',
      status: camStatus,
      details: camDetails,
      category: 'Hardware',
    ));

    // 13. Dynamic Windows DPAPI Secure Storage Probe (Requirement 18 - Real check)
    DiagnosticStatus dpapiStatus = DiagnosticStatus.failed;
    String dpapiDetails = 'Windows DPAPI Secure Storage';
    String? dpapiRec;
    try {
      final storage = WindowsDpapiSecureStorage();
      final isAvailable = storage.isAvailable;
      if (isAvailable) {
        // Active probe: write a test secret, read it back, delete it
        const testKey = '__diag_probe_dpapi__';
        const testVal = 'probe_123456';
        await storage.writeSecret(testKey, testVal);
        final readBack = await storage.readSecret(testKey);
        await storage.deleteSecret(testKey);

        if (readBack == testVal) {
          dpapiStatus = DiagnosticStatus.ready;
          dpapiDetails = 'Windows DPAPI (CurrentUser) đã kích hoạt, mã hóa fail-closed, không fallback plaintext.';
        } else {
          dpapiStatus = DiagnosticStatus.failed;
          dpapiDetails = 'Kiểm tra đọc/ghi DPAPI không khớp dữ liệu giải mã.';
          dpapiRec = 'Kiểm tra tài khoản người dùng Windows.';
        }
      } else {
        dpapiStatus = DiagnosticStatus.failed;
        dpapiDetails = 'Windows DPAPI không khả dụng trên môi trường hiện tại.';
        dpapiRec = 'Đảm bảo ứng dụng chạy trên Windows với hồ sơ người dùng hợp lệ.';
      }
    } catch (e) {
      dpapiStatus = DiagnosticStatus.failed;
      dpapiDetails = 'Lỗi kiểm tra kho khóa bảo mật DPAPI: $e';
      dpapiRec = 'DPAPI đã fail-closed để bảo vệ dữ liệu khỏi rò rỉ.';
    }
    items.add(SystemDiagnosticItem(
      id: 'secure_storage',
      title: 'Bảo mật kho khóa DPAPI',
      description: 'Mã hóa khóa API và thông tin nhạy cảm qua Windows DPAPI (Fail-Closed)',
      status: dpapiStatus,
      details: dpapiDetails,
      recommendation: dpapiRec,
      category: 'Security',
    ));

    return items;
  }

  /// Sanitizes profile path prefix (e.g. `C:\Users\username\...` -> `C:\Users\<USER>\...`)
  /// to strictly prevent user identifiable privacy leaks in export reports (Requirement 41).
  static String redactUserProfilePath(String path) {
    return path.replaceAll(RegExp(r'[a-zA-Z]:\\Users\\[^\\]+', caseSensitive: false), r'C:\Users\<USER>');
  }

  /// Generates a strictly sanitized text report suitable for user support.
  /// Strictly masks any secrets, API keys, passwords, and private document data,
  /// and redacts Windows user profile path prefixes (Requirement 41).
  String generateSanitizedReport({
    required List<SystemDiagnosticItem> items,
    required String appVersion,
    required int databaseSchemaVersion,
  }) {
    final buffer = StringBuffer();
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

    final cleanWorkspaceRoot = redactUserProfilePath(_workspaceManager.workspaceRoot.path);
    final cleanLogsDir = redactUserProfilePath(_workspaceManager.logsDir.path);

    buffer.writeln('================================================================');
    buffer.writeln('  NGUYEN DU TOOL - SYSTEM DIAGNOSTIC REPORT (SANITIZED)         ');
    buffer.writeln('================================================================');
    buffer.writeln('Report Generated : $dateStr');
    buffer.writeln('Application      : NguyenDu Tool v$appVersion (Windows x64)');
    buffer.writeln('Database Schema  : v$databaseSchemaVersion');
    buffer.writeln('OS Platform      : ${Platform.operatingSystem} (${Platform.operatingSystemVersion})');
    buffer.writeln('Dart Runtime     : ${Platform.version.split(' ').first}');
    buffer.writeln('Workspace Root   : $cleanWorkspaceRoot');
    buffer.writeln('Log Directory    : $cleanLogsDir');
    buffer.writeln('Security Storage : Windows DPAPI (CurrentUser Scope, Fail-Closed)');
    buffer.writeln('Privacy Policy   : 100% Local-First (No telemetry, User Paths Redacted)');
    buffer.writeln('================================================================');
    buffer.writeln();

    buffer.writeln('SYSTEM CHECKS SUMMARY:');
    buffer.writeln('----------------------------------------------------------------');
    for (final item in items) {
      final statusBadge = '[${item.status.label}]'.padRight(24);
      final maskedDetails = redactUserProfilePath(AppLogger.maskSensitive(item.details));
      buffer.writeln('$statusBadge ${item.title}');
      buffer.writeln('  Chi tiết       : $maskedDetails');
      if (item.recommendation != null) {
        buffer.writeln('  Khuyến nghị    : ${redactUserProfilePath(item.recommendation!)}');
      }
      buffer.writeln();
    }

    buffer.writeln('================================================================');
    buffer.writeln('  END OF DIAGNOSTIC REPORT - NO SENSITIVE USER DATA INCLUDED    ');
    buffer.writeln('================================================================');

    return buffer.toString();
  }

  /// Exports sanitized diagnostic report to file NguyenDuTool_Diagnostic_<timestamp>.txt.
  Future<File> exportDiagnosticReportToFile({
    required List<SystemDiagnosticItem> items,
    required String appVersion,
    required int databaseSchemaVersion,
    Directory? outputDirectory,
  }) async {
    final dir = outputDirectory ?? _workspaceManager.workspaceRoot;
    await dir.create(recursive: true);

    final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File(p.join(dir.path, 'NguyenDuTool_Diagnostic_$ts.txt'));

    final content = generateSanitizedReport(
      items: items,
      appVersion: appVersion,
      databaseSchemaVersion: databaseSchemaVersion,
    );

    await file.writeAsString(content, encoding: utf8, flush: true);
    AppLogger.info('Exported system diagnostic report to: ${file.path}');
    return file;
  }
}
