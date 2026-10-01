import 'dart:io';
import 'package:path/path.dart' as p;
import '../errors/app_exceptions.dart';
import '../logging/app_logger.dart';

/// Manages local workspace directories, subfolders, validation, and system actions.
class WorkspaceManager {
  static const String defaultWorkspaceFolderName = 'NguyenDu Tool';
  static const String legacyWorkspaceFolderName = 'iSchool Tools';

  static const String dirProjects = 'projects';
  static const String dirImports = 'imports';
  static const String dirExports = 'exports';
  static const String dirLibrary = 'library';
  static const String dirCache = 'cache';
  static const String dirTemp = 'temp';
  static const String dirLogs = 'logs';

  late String _rootPath;
  bool _initialized = false;

  WorkspaceManager([String? customRootPath]) {
    if (customRootPath != null && customRootPath.trim().isNotEmpty) {
      _rootPath = p.normalize(customRootPath.trim());
    } else {
      _rootPath = getDefaultWorkspacePath();
    }
  }

  /// Calculates the default workspace path on Windows or other OS.
  static String getDefaultWorkspacePath() {
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        final docs = p.join(userProfile, 'Documents');
        if (Directory(docs).existsSync()) {
          return p.join(docs, defaultWorkspaceFolderName);
        }
        return p.join(userProfile, defaultWorkspaceFolderName);
      }
    }
    // Fallback for testing / cross-platform
    final home = Platform.environment['HOME'] ?? Directory.current.path;
    return p.join(home, defaultWorkspaceFolderName);
  }

  /// Calculates the legacy workspace path if it existed.
  static String? getLegacyWorkspacePath() {
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        final docs = p.join(userProfile, 'Documents');
        final legacyDocs = p.join(docs, legacyWorkspaceFolderName);
        if (Directory(legacyDocs).existsSync()) {
          return legacyDocs;
        }
        final legacyProfile = p.join(userProfile, legacyWorkspaceFolderName);
        if (Directory(legacyProfile).existsSync()) {
          return legacyProfile;
        }
      }
    }
    return null;
  }

  /// Initializes the workspace root and all mandatory subdirectories.
  Future<void> init() async {
    try {
      final rootDir = Directory(_rootPath);
      final isNewWorkspace = !rootDir.existsSync();
      if (isNewWorkspace) {
        rootDir.createSync(recursive: true);
      }

      for (final subDir in [
        dirProjects,
        dirImports,
        dirExports,
        dirLibrary,
        dirCache,
        dirTemp,
        dirLogs,
      ]) {
        final path = p.join(_rootPath, subDir);
        final d = Directory(path);
        if (!d.existsSync()) {
          d.createSync(recursive: true);
        }
      }

      // Check and migrate legacy workspace data non-destructively
      if (isNewWorkspace) {
        await _checkAndMigrateLegacyWorkspace();
      }

      _initialized = true;
      AppLogger.info('WorkspaceManager initialized at: $_rootPath');
    } catch (e, st) {
      final msg = 'Không thể khởi tạo thư mục workspace: $_rootPath';
      AppLogger.error(msg, e, st);
      throw FileException(msg, path: _rootPath, technicalDetails: e.toString(), stackTrace: st);
    }
  }

  /// Non-destructively copies documents and exports from legacy workspace if present.
  Future<void> _checkAndMigrateLegacyWorkspace() async {
    try {
      final legacyPath = getLegacyWorkspacePath();
      if (legacyPath == null || legacyPath == _rootPath) return;

      final legacyDir = Directory(legacyPath);
      if (!legacyDir.existsSync()) return;

      AppLogger.info('Found legacy workspace at $legacyPath. Initiating non-destructive data migration to $_rootPath...');

      // Folders to migrate: exports, imports, projects, library
      for (final subFolder in [dirExports, dirImports, dirProjects, dirLibrary]) {
        final legacySub = Directory(p.join(legacyPath, subFolder));
        final newSub = Directory(p.join(_rootPath, subFolder));
        if (legacySub.existsSync()) {
          for (final entity in legacySub.listSync(recursive: true)) {
            if (entity is File) {
              final relative = p.relative(entity.path, from: legacySub.path);
              final destPath = p.join(newSub.path, relative);
              final destFile = File(destPath);
              if (!destFile.existsSync()) {
                destFile.parent.createSync(recursive: true);
                entity.copySync(destPath);
              }
            }
          }
        }
      }
      AppLogger.info('Completed legacy workspace migration successfully.');
    } catch (e) {
      AppLogger.warning('Failed migrating some legacy workspace files (non-fatal)', e);
    }
  }

  bool get isInitialized => _initialized;
  String get rootPath => _rootPath;

  Directory get rootDir => Directory(_rootPath);
  Directory get workspaceRoot => rootDir;
  Directory get projectsDir => Directory(p.join(_rootPath, dirProjects));
  Directory get importsDir => Directory(p.join(_rootPath, dirImports));
  Directory get exportsDir => Directory(p.join(_rootPath, dirExports));
  Directory get libraryDir => Directory(p.join(_rootPath, dirLibrary));
  Directory get cacheDir => Directory(p.join(_rootPath, dirCache));
  Directory get tempDir => Directory(p.join(_rootPath, dirTemp));
  Directory get logsDir => Directory(p.join(_rootPath, dirLogs));

  /// Validates if a custom path is usable as a workspace.
  static bool validatePath(String targetPath) {
    if (targetPath.trim().isEmpty) return false;
    try {
      final norm = p.normalize(targetPath.trim());
      final dir = Directory(norm);
      return dir.isAbsolute;
    } catch (_) {
      return false;
    }
  }

  /// Sets and re-initializes a new workspace root path.
  Future<void> setWorkspaceRoot(String newPath) async {
    if (!validatePath(newPath)) {
      throw FileException('Đường dẫn workspace không hợp lệ.', path: newPath);
    }
    _rootPath = p.normalize(newPath.trim());
    await init();
  }

  /// Clears temporary cache and temp files to free disk space.
  Future<int> clearTempFiles() async {
    int deletedCount = 0;
    try {
      final tDir = tempDir;
      if (tDir.existsSync()) {
        for (final entity in tDir.listSync(recursive: false)) {
          try {
            entity.deleteSync(recursive: true);
            deletedCount++;
          } catch (e) {
            AppLogger.warning('Failed to delete temp entity: ${entity.path}', e);
          }
        }
      }
      AppLogger.info('Cleared $deletedCount temporary files from: ${tDir.path}');
      return deletedCount;
    } catch (e, st) {
      AppLogger.error('Lỗi khi xóa tệp tạm thời', e, st);
      throw FileException('Không thể xóa tệp tạm thời.', path: tempDir.path, technicalDetails: e.toString());
    }
  }

  /// Opens a folder in Windows File Explorer (or default platform file manager).
  static Future<void> openFolder(String folderPath) async {
    try {
      final dir = Directory(folderPath);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      if (Platform.isWindows) {
        await Process.run('explorer.exe', [p.normalize(folderPath)]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [folderPath]);
      } else {
        await Process.run('xdg-open', [folderPath]);
      }
    } catch (e, st) {
      AppLogger.error('Không thể mở thư mục: $folderPath', e, st);
      throw FileException('Không thể mở thư mục.', path: folderPath, technicalDetails: e.toString());
    }
  }

  /// Opens the containing folder of a file and selects/highlights it.
  static Future<void> openContainingFolder(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        // If file doesn't exist, open the parent directory
        final parent = p.dirname(filePath);
        await openFolder(parent);
        return;
      }

      if (Platform.isWindows) {
        await Process.run('explorer.exe', ['/select,', p.normalize(filePath)]);
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', filePath]);
      } else {
        await openFolder(p.dirname(filePath));
      }
    } catch (e, st) {
      AppLogger.error('Không thể mở tệp trong thư mục: $filePath', e, st);
      throw FileException('Không thể mở vị trí tệp trong Explorer.', path: filePath, technicalDetails: e.toString());
    }
  }

  /// Opens a file directly with its default system program (e.g., Microsoft Word for .docx).
  static Future<void> openFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        throw FileException('Tệp không tồn tại.', path: filePath);
      }
      if (Platform.isWindows) {
        await Process.run('cmd.exe', ['/c', 'start', '""', p.normalize(filePath)]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [filePath]);
      } else {
        await Process.run('xdg-open', [filePath]);
      }
    } catch (e, st) {
      AppLogger.error('Không thể mở tệp: $filePath', e, st);
      throw FileException('Không thể mở tệp với ứng dụng mặc định.', path: filePath, technicalDetails: e.toString());
    }
  }
}
