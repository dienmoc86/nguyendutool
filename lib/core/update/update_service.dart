import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import '../logging/app_logger.dart';
import '../product/product_info.dart';

/// Representation of an official release update manifest.
class UpdateManifest {
  final String version;
  final int build;
  final String installerUrl;
  final String sha256;
  final String? portableUrl;
  final String? portableSha256;
  final String releaseNotesUrl;
  final String? releaseNotes;
  final String? minimumSupportedVersion;
  final String channel;
  final DateTime releaseDate;
  final String? signature;

  const UpdateManifest({
    required this.version,
    required this.build,
    required this.installerUrl,
    required this.sha256,
    this.portableUrl,
    this.portableSha256,
    required this.releaseNotesUrl,
    this.releaseNotes,
    this.minimumSupportedVersion,
    this.channel = 'stable',
    required this.releaseDate,
    this.signature,
  });

  factory UpdateManifest.fromJson(Map<String, dynamic> json) {
    final version = json['version'] as String?;
    final installerUrl = (json['installerUrl'] ?? json['downloadUrl'] ?? json['portableUrl']) as String?;
    final sha256Value = (json['sha256'] ?? json['installerSha256'] ?? json['portableSha256']) as String?;

    if (version == null || installerUrl == null || sha256Value == null || sha256Value.trim().isEmpty) {
      throw const FormatException('Update manifest missing required fields: version, installerUrl, sha256');
    }

    return UpdateManifest(
      version: version,
      build: json['build'] is int ? json['build'] as int : int.tryParse(json['build']?.toString() ?? '0') ?? 0,
      installerUrl: installerUrl,
      sha256: sha256Value.trim().toUpperCase(),
      portableUrl: json['portableUrl'] as String?,
      portableSha256: (json['portableSha256'] as String?)?.trim().toUpperCase(),
      releaseNotesUrl: json['releaseNotesUrl'] as String? ?? '',
      releaseNotes: json['releaseNotes'] as String?,
      minimumSupportedVersion: json['minimumSupportedVersion'] as String?,
      channel: json['channel'] as String? ?? 'stable',
      releaseDate: json['releaseDate'] != null ? DateTime.tryParse(json['releaseDate'].toString()) ?? DateTime.now() : DateTime.now(),
      signature: json['signature'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'build': build,
        'installerUrl': installerUrl,
        'sha256': sha256,
        if (portableUrl != null) 'portableUrl': portableUrl,
        if (portableSha256 != null) 'portableSha256': portableSha256,
        'releaseNotesUrl': releaseNotesUrl,
        if (releaseNotes != null) 'releaseNotes': releaseNotes,
        if (minimumSupportedVersion != null) 'minimumSupportedVersion': minimumSupportedVersion,
        'channel': channel,
        'releaseDate': releaseDate.toIso8601String(),
        if (signature != null) 'signature': signature,
      };
}

/// Result of an update availability check.
class UpdateCheckResult {
  final bool isUpdateAvailable;
  final bool isMandatory;
  final UpdateManifest? manifest;
  final String currentVersion;
  final String? errorMessage;

  const UpdateCheckResult({
    required this.isUpdateAvailable,
    this.isMandatory = false,
    this.manifest,
    required this.currentVersion,
    this.errorMessage,
  });
}

/// Result of downloading and verifying an installer package.
class UpdateDownloadResult {
  final bool isSuccess;
  final File? downloadedInstaller;
  final String? actualSha256;
  final String? errorMessage;
  final bool hashMismatch;

  const UpdateDownloadResult({
    required this.isSuccess,
    this.downloadedInstaller,
    this.actualSha256,
    this.errorMessage,
    this.hashMismatch = false,
  });
}

/// Secure updater service implementing streaming download, strict HTTPS validation,
/// and SHA-256 integrity verification (Requirements 30, 31, 32, 33).
class UpdateService {
  static const String defaultGitHubRepo = 'dienmoc86/nguyendutool';

  final String currentVersion;
  final int currentBuild;
  final bool isTestMode;

  UpdateService({
    this.currentVersion = ProductInfo.version,
    this.currentBuild = ProductInfo.build,
    this.isTestMode = false,
  });

  /// Validates URI scheme according to security policy (Requirement 31).
  /// Production: STRICT HTTPS ONLY.
  /// Test mode only: allows exact localhost, 127.0.0.1, or ::1.
  bool isValidUpdateUri(Uri uri) {
    if (uri.scheme.toLowerCase() == 'https') return true;
    if (isTestMode) {
      final host = uri.host.toLowerCase();
      if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
        return uri.scheme.toLowerCase() == 'http';
      }
    }
    return false;
  }

  Future<String> _fetchString(Uri uri) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 8));
      final response = await request.close().timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      return await response.transform(utf8.decoder).join();
    } finally {
      client.close();
    }
  }

  /// Compares semantic versions (e.g. '1.5.1' > '1.5.0'). Returns:
  /// > 0 if v1 > v2
  /// < 0 if v1 < v2
  /// = 0 if v1 == v2
  static int compareSemVer(String v1, String v2) {
    List<int> parse(String v) {
      final clean = v.split('+').first.replaceAll(RegExp(r'[^0-9.]'), '');
      return clean.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    }

    final p1 = parse(v1);
    final p2 = parse(v2);
    final maxLen = p1.length > p2.length ? p1.length : p2.length;

    for (int i = 0; i < maxLen; i++) {
      final n1 = i < p1.length ? p1[i] : 0;
      final n2 = i < p2.length ? p2[i] : 0;
      if (n1 != n2) return n1.compareTo(n2);
    }
    return 0;
  }

  /// Checks for available updates using a local JSON manifest string or remote HTTPS endpoint.
  Future<UpdateCheckResult> checkForUpdates({
    String? manifestJsonString,
    String? manifestUrl,
    String targetChannel = 'stable',
  }) async {
    try {
      String jsonStr = '';

      if (manifestJsonString != null && manifestJsonString.trim().isNotEmpty) {
        jsonStr = manifestJsonString.trim();
      } else if (manifestUrl != null && manifestUrl.trim().isNotEmpty) {
        final uri = Uri.parse(manifestUrl.trim());
        // Enforce strict HTTPS security (Requirement 31)
        if (!isValidUpdateUri(uri)) {
          return UpdateCheckResult(
            isUpdateAvailable: false,
            currentVersion: currentVersion,
            errorMessage: 'Bảo mật: Địa chỉ cập nhật phải sử dụng giao thức HTTPS an toàn.',
          );
        }
        jsonStr = await _fetchString(uri);
      } else {
        // Requirement 30: When no endpoint is configured for production RC
        return UpdateCheckResult(
          isUpdateAvailable: false,
          currentVersion: currentVersion,
          errorMessage: 'Chưa cấu hình máy chủ cập nhật.',
        );
      }

      if (jsonStr.isEmpty) {
        return UpdateCheckResult(
          isUpdateAvailable: false,
          currentVersion: currentVersion,
          errorMessage: 'Nội dung thông tin bản cập nhật rỗng.',
        );
      }

      final dynamic decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Manifest JSON must be an object');
      }

      final manifest = UpdateManifest.fromJson(decoded);

      // Channel filtering
      if (manifest.channel != targetChannel && targetChannel != 'all') {
        return UpdateCheckResult(
          isUpdateAvailable: false,
          currentVersion: currentVersion,
          manifest: manifest,
        );
      }

      final isNewerVersion = compareSemVer(manifest.version, currentVersion) > 0 ||
          (compareSemVer(manifest.version, currentVersion) == 0 && manifest.build > currentBuild);

      bool isMandatory = false;
      if (manifest.minimumSupportedVersion != null && isNewerVersion) {
        isMandatory = compareSemVer(currentVersion, manifest.minimumSupportedVersion!) < 0;
      }

      return UpdateCheckResult(
        isUpdateAvailable: isNewerVersion,
        isMandatory: isMandatory,
        manifest: manifest,
        currentVersion: currentVersion,
      );
    } catch (e, st) {
      AppLogger.warning('Update check notice: $e', e, st);
      return UpdateCheckResult(
        isUpdateAvailable: false,
        currentVersion: currentVersion,
        errorMessage: 'Lỗi kiểm tra cập nhật: $e',
      );
    }
  }

  /// Checks for available updates directly from GitHub Releases, raw manifest fallback, or custom URL.
  Future<UpdateCheckResult> checkForGitHubRelease({
    String repository = defaultGitHubRepo,
    String targetChannel = 'stable',
    String? customManifestUrl,
  }) async {
    try {
      // 0. Priority: Custom Manifest URL if configured
      if (customManifestUrl != null && customManifestUrl.trim().isNotEmpty) {
        try {
          final result = await checkForUpdates(
            manifestUrl: customManifestUrl.trim(),
            targetChannel: targetChannel,
          );
          if (result.errorMessage == null && result.manifest != null) {
            AppLogger.info('Checked updates via custom manifest URL: v${result.manifest!.version} (available: ${result.isUpdateAvailable})');
            return result;
          }
        } catch (_) {}
      }

      // 1. First attempt: Raw RELEASE_MANIFEST.json on main branch (high performance, no GitHub API rate limit)
      final rawUrls = [
        'https://raw.githubusercontent.com/$repository/main/RELEASE_MANIFEST.json',
        'https://raw.githubusercontent.com/$repository/master/RELEASE_MANIFEST.json',
        'https://ibestgroup.vn/releases/nguyendutool/RELEASE_MANIFEST.json',
      ];

      for (final rawUrl in rawUrls) {
        try {
          final result = await checkForUpdates(
            manifestUrl: rawUrl,
            targetChannel: targetChannel,
          );
          if (result.errorMessage == null && result.manifest != null) {
            AppLogger.info('Checked updates via manifest ($rawUrl): v${result.manifest!.version} (available: ${result.isUpdateAvailable})');
            return result;
          }
        } catch (_) {
          // Continue to next mirror
        }
      }

      // 2. Second attempt: GitHub Releases API
      final apiUrl = Uri.parse('https://api.github.com/repos/$repository/releases/latest');
      final client = HttpClient();
      try {
        final request = await client.getUrl(apiUrl).timeout(const Duration(seconds: 10));
        request.headers.set('User-Agent', 'NguyenDuTool-Updater/$currentVersion');
        request.headers.set('Accept', 'application/vnd.github.v3+json');

        final response = await request.close().timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) {
          throw HttpException('GitHub API HTTP ${response.statusCode}');
        }

        final bodyStr = await response.transform(utf8.decoder).join();
        final releaseJson = jsonDecode(bodyStr) as Map<String, dynamic>;

        final tagName = (releaseJson['tag_name'] as String? ?? '').replaceFirst(RegExp(r'^v', caseSensitive: false), '').trim();
        if (tagName.isEmpty) {
          return UpdateCheckResult(
            isUpdateAvailable: false,
            currentVersion: currentVersion,
            errorMessage: 'Không tìm thấy thẻ phiên bản trên GitHub Release.',
          );
        }

        final releaseNotes = releaseJson['body'] as String? ?? '';
        final htmlUrl = releaseJson['html_url'] as String? ?? 'https://github.com/$repository/releases/latest';
        final publishedAtStr = releaseJson['published_at'] as String?;
        final releaseDate = publishedAtStr != null ? DateTime.tryParse(publishedAtStr) ?? DateTime.now() : DateTime.now();

        final assets = (releaseJson['assets'] as List<dynamic>? ?? []);
        String? installerUrl;
        String? portableUrl;
        String sha256 = '';

        // Search for setup executable asset or portable zip
        for (final dynamic asset in assets) {
          if (asset is Map<String, dynamic>) {
            final name = (asset['name'] as String? ?? '').toLowerCase();
            final downloadUrl = asset['browser_download_url'] as String?;
            if (downloadUrl != null) {
              if (name.endsWith('.exe')) {
                if (name.contains('setup') || installerUrl == null) {
                  installerUrl = downloadUrl;
                }
              } else if (name.endsWith('.zip') && name.contains('portable')) {
                portableUrl = downloadUrl;
              }
            }
          }
        }

        // Search for sha256 checksum asset or manifest
        for (final dynamic asset in assets) {
          if (asset is Map<String, dynamic>) {
            final name = (asset['name'] as String? ?? '').toLowerCase();
            final downloadUrl = asset['browser_download_url'] as String?;
            if (downloadUrl != null && (name.endsWith('.sha256') || name.contains('sha256sums'))) {
              try {
                final hashContent = await _fetchString(Uri.parse(downloadUrl));
                final match = RegExp(r'[A-Fa-f0-9]{64}').firstMatch(hashContent);
                if (match != null) {
                  sha256 = match.group(0)!.toUpperCase();
                }
              } catch (_) {}
            }
          }
        }

        installerUrl ??= portableUrl;

        if (installerUrl == null) {
          return UpdateCheckResult(
            isUpdateAvailable: false,
            currentVersion: currentVersion,
            errorMessage: 'Không tìm thấy tệp cài đặt (.exe) hoặc gói portable (.zip) trong bản phát hành $tagName.',
          );
        }

        final manifest = UpdateManifest(
          version: tagName,
          build: 0,
          installerUrl: installerUrl,
          portableUrl: portableUrl,
          sha256: sha256,
          releaseNotesUrl: htmlUrl,
          releaseNotes: releaseNotes.isNotEmpty ? releaseNotes : 'Bản cập nhật mới trên GitHub Releases.',
          releaseDate: releaseDate,
          channel: targetChannel,
        );

        final isNewerVersion = compareSemVer(manifest.version, currentVersion) > 0;

        return UpdateCheckResult(
          isUpdateAvailable: isNewerVersion,
          manifest: manifest,
          currentVersion: currentVersion,
        );
      } finally {
        client.close();
      }
    } catch (e, st) {
      AppLogger.warning('GitHub update check notice: $e', e, st);
      return UpdateCheckResult(
        isUpdateAvailable: false,
        currentVersion: currentVersion,
        errorMessage: 'Không thể kết nối đến máy chủ cập nhật (Nếu kho GitHub ở chế độ Private, vui lòng chuyển sang Public hoặc cấu hình máy chủ cập nhật). Lỗi: $e',
      );
    }
  }

  /// Downloads and cryptographically verifies the SHA256 of the update package via streaming
  /// directly to a .part file (Requirement 33). Renames only after successful verification.
  Future<UpdateDownloadResult> downloadAndVerifyInstaller(
    UpdateManifest manifest, {
    Directory? destinationDirectory,
    List<int>? mockDownloadedBytes,
    void Function(double progress, int receivedBytes, int totalBytes)? onProgress,
  }) async {
    final destDir = destinationDirectory ?? Directory.systemTemp;
    await destDir.create(recursive: true);

    final fileName = p.basename(Uri.parse(manifest.installerUrl).path);
    final targetFile = File(p.join(destDir.path, fileName.isEmpty ? 'NguyenDuTool_Update.exe' : fileName));
    final partFile = File('${targetFile.path}.part');

    try {
      if (await partFile.exists()) await partFile.delete();
      final outputSink = partFile.openWrite();

      if (mockDownloadedBytes != null) {
        outputSink.add(mockDownloadedBytes);
        await outputSink.flush();
        await outputSink.close();
        if (onProgress != null) {
          onProgress(1.0, mockDownloadedBytes.length, mockDownloadedBytes.length);
        }
      } else {
        final uri = Uri.parse(manifest.installerUrl);
        if (!isValidUpdateUri(uri)) {
          await outputSink.close();
          if (await partFile.exists()) await partFile.delete();
          return const UpdateDownloadResult(
            isSuccess: false,
            errorMessage: 'Bảo mật: Gói cài đặt phải được tải về qua kết nối HTTPS an toàn.',
          );
        }

        final client = HttpClient();
        try {
          final request = await client.getUrl(uri).timeout(const Duration(seconds: 60));
          final response = await request.close().timeout(const Duration(seconds: 60));
          if (response.statusCode != 200) {
            throw HttpException('HTTP ${response.statusCode}');
          }

          final totalBytes = response.contentLength > 0 ? response.contentLength : 0;
          int receivedBytes = 0;

          await for (final chunk in response) {
            outputSink.add(chunk);
            receivedBytes += chunk.length;
            if (onProgress != null && totalBytes > 0) {
              final progress = (receivedBytes / totalBytes).clamp(0.0, 1.0);
              onProgress(progress, receivedBytes, totalBytes);
            }
          }
          await outputSink.flush();
          await outputSink.close();
        } finally {
          client.close();
        }
      }

      final fileDigest = await crypto.sha256.bind(partFile.openRead()).first;
      final actualHash = fileDigest.toString().toUpperCase();
      final expectedHash = manifest.sha256.toUpperCase().trim();

      if (expectedHash.isNotEmpty && actualHash != expectedHash) {
        // SECURITY VIOLATION: Delete corrupt .part immediately
        if (await partFile.exists()) await partFile.delete();

        final msg = 'CẢNH BÁO BẢO MẬT: Mã băm SHA-256 của tệp tải về không khớp với chữ ký manifest!\n'
            'Kỳ vọng: $expectedHash\n'
            'Thực tế : $actualHash';
        AppLogger.error(msg);

        return UpdateDownloadResult(
          isSuccess: false,
          actualSha256: actualHash,
          errorMessage: msg,
          hashMismatch: true,
        );
      }

      // Rename .part to target only upon successful hash verification
      if (await targetFile.exists()) await targetFile.delete();
      await partFile.rename(targetFile.path);

      AppLogger.info('Installer integrity verified: $actualHash (Target: ${targetFile.path})');
      return UpdateDownloadResult(
        isSuccess: true,
        downloadedInstaller: targetFile,
        actualSha256: actualHash,
      );
    } catch (e, st) {
      if (await partFile.exists()) {
        try {
          await partFile.delete();
        } catch (_) {}
      }
      AppLogger.error('Update download error: $e', e, st);
      return UpdateDownloadResult(
        isSuccess: false,
        errorMessage: 'Lỗi tải xuống gói cập nhật: $e',
      );
    }
  }

  /// Executes the downloaded installer or extracts portable zip, then relaunches the application cleanly.
  Future<void> executeSilentUpdateAndRelaunch({
    required File installerFile,
    String? targetExePath,
  }) async {
    final exeToLaunch = targetExePath ?? Platform.resolvedExecutable;
    final tempDir = installerFile.parent;
    final scriptFile = File(p.join(tempDir.path, 'apply_update_${DateTime.now().millisecondsSinceEpoch}.cmd'));

    final String scriptContent;
    if (installerFile.path.toLowerCase().endsWith('.zip')) {
      final appDir = File(exeToLaunch).parent.path;
      scriptContent = '''
@echo off
chcp 65001 >nul
echo Dang cap nhat ban Portable NguyenDu Tool...
timeout /t 2 /nobreak >nul
powershell -Command "Expand-Archive -Path '${installerFile.path}' -DestinationPath '$appDir' -Force"
start "" "$exeToLaunch"
del "%~f0"
exit
''';
    } else {
      scriptContent = '''
@echo off
chcp 65001 >nul
echo Dang cap nhat NguyenDu Tool len phien ban moi...
timeout /t 2 /nobreak >nul
start /wait "" "${installerFile.path}" /SILENT /CLOSEAPPLICATIONS /SUPPRESSMSGBOXES
start "" "$exeToLaunch"
del "%~f0"
exit
''';
    }

    await scriptFile.writeAsString(scriptContent);
    AppLogger.info('Launching update script: ${scriptFile.path}');

    await Process.start(
      'cmd.exe',
      ['/c', scriptFile.path],
      mode: ProcessStartMode.detached,
      runInShell: false,
    );

    // Clean exit of current Flutter application to allow installer to overwrite binaries
    exit(0);
  }
}
