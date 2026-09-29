import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../filesystem/workspace_manager.dart';
import '../logging/app_logger.dart';

/// Represents a session or project that can be recovered after an abrupt crash.
class RecoverableItem {
  final String id;
  final String title;
  final String filePath;
  final DateTime lastModified;
  final String itemType; // 'video_project', 'scanner_session', 'tts_batch'

  const RecoverableItem({
    required this.id,
    required this.title,
    required this.filePath,
    required this.lastModified,
    required this.itemType,
  });
}

/// Manages crash recovery and safe temp folder garbage collection.
/// Complies with Sections 37, 40, 41, and 47 of Phase 5 specification.
class CrashRecoveryService {
  final WorkspaceManager _workspaceManager;

  CrashRecoveryService({WorkspaceManager? workspaceManager})
      : _workspaceManager = workspaceManager ?? WorkspaceManager();

  /// Scans for autosaved or recoverable work in projects and temp directories.
  Future<List<RecoverableItem>> detectRecoverableItems() async {
    final results = <RecoverableItem>[];

    try {
      final projectsDir = _workspaceManager.projectsDir;
      if (await projectsDir.exists()) {
        await for (final entity in projectsDir.list(recursive: true, followLinks: false)) {
          if (entity is File && entity.path.endsWith('.autosave.json')) {
            try {
              final stat = await entity.stat();
              final content = await entity.readAsString();
              final decoded = jsonDecode(content);
              final title = decoded is Map && decoded.containsKey('name')
                  ? decoded['name'].toString()
                  : p.basenameWithoutExtension(entity.path);

              results.add(RecoverableItem(
                id: p.basenameWithoutExtension(entity.path),
                title: title,
                filePath: entity.path,
                lastModified: stat.modified,
                itemType: 'video_project',
              ));
            } catch (e) {
              AppLogger.warning('Error inspecting recoverable file: ${entity.path}', e);
            }
          }
        }
      }
    } catch (e, st) {
      AppLogger.warning('Error scanning for recoverable items', e, st);
    }

    return results;
  }

  /// Categorizes and performs safe stale temp cleanup.
  /// Does NOT delete recoverable projects or active session files.
  Future<int> cleanStaleTempFiles({Duration maxAge = const Duration(hours: 24)}) async {
    int deletedCount = 0;
    try {
      final tempDir = _workspaceManager.tempDir;
      if (!await tempDir.exists()) return 0;

      final now = DateTime.now();
      await for (final entity in tempDir.list(recursive: false, followLinks: false)) {
        try {
          final stat = await entity.stat();
          final age = now.difference(stat.modified);

          // Preserve recoverable projects or active autosave files
          final name = p.basename(entity.path);
          if (name.endsWith('.autosave.json') || name.startsWith('recovery_')) {
            AppLogger.info('Preserving recoverable temp asset: ${entity.path}');
            continue;
          }

          // Safe stale temp: older than maxAge
          if (age > maxAge) {
            await entity.delete(recursive: true);
            deletedCount++;
          }
        } catch (e) {
          AppLogger.warning('Failed to delete stale temp item: ${entity.path}', e);
        }
      }

      AppLogger.info('Cleaned $deletedCount stale temporary entities from temp directory.');
    } catch (e, st) {
      AppLogger.warning('Error during stale temp cleanup', e, st);
    }
    return deletedCount;
  }

  /// Generates a collision-safe file path (Section 47).
  /// E.g. `report.docx` -> `report (1).docx` if `report.docx` already exists.
  static String getCollisionFreePath(String targetPath) {
    var file = File(targetPath);
    if (!file.existsSync()) return targetPath;

    final dir = p.dirname(targetPath);
    final ext = p.extension(targetPath);
    final base = p.basenameWithoutExtension(targetPath);

    int counter = 1;
    while (file.existsSync()) {
      final candidate = p.join(dir, '$base ($counter)$ext');
      file = File(candidate);
      if (!file.existsSync()) return candidate;
      counter++;
    }
    return file.path;
  }

  /// Writes data atomically via a temp file swap to avoid corruption upon sudden power loss (Section 37).
  static Future<void> atomicWriteBytes(File targetFile, List<int> bytes) async {
    final tempFile = File('${targetFile.path}.tmp_${DateTime.now().millisecondsSinceEpoch}');
    await tempFile.parent.create(recursive: true);
    await tempFile.writeAsBytes(bytes, flush: true);

    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    await tempFile.rename(targetFile.path);
  }

  /// Writes string data atomically.
  static Future<void> atomicWriteString(File targetFile, String content) async {
    final tempFile = File('${targetFile.path}.tmp_${DateTime.now().millisecondsSinceEpoch}');
    await tempFile.parent.create(recursive: true);
    await tempFile.writeAsString(content, flush: true);

    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    await tempFile.rename(targetFile.path);
  }
}
