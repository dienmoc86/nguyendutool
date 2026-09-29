import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../../core/filesystem/workspace_manager.dart';
import '../../../core/logging/app_logger.dart';
import '../domain/file_entry.dart';
import '../infrastructure/file_repository.dart';

/// StateNotifier that manages file library entries and actions.
class FileLibraryNotifier extends StateNotifier<AsyncValue<List<FileEntry>>> {
  final FileRepository _repository;
  final WorkspaceManager _workspaceManager;
  final _uuid = const Uuid();
  String _currentQuery = '';

  FileLibraryNotifier(this._repository, this._workspaceManager)
      : super(const AsyncValue.data([])) {
    refresh();
  }

  /// Refreshes the file list with optional search query.
  Future<void> refresh({String? query}) async {
    try {
      if (query != null) {
        _currentQuery = query;
      }
      final files = await _repository.listFiles(query: _currentQuery);
      if (!mounted) return;
      state = AsyncValue.data(files);
    } catch (e, st) {
      if (!mounted) return;
      AppLogger.error('Failed to load file list', e, st);
      state = AsyncValue.error(e, st);
    }
  }

  /// Adds a file entry into the library.
  Future<FileEntry> recordFile({
    required String originalName,
    required String localPath,
    String? mimeType,
    required int size,
    String? projectId,
  }) async {
    final entry = FileEntry(
      id: _uuid.v4(),
      projectId: projectId,
      originalName: originalName,
      localPath: localPath,
      mimeType: mimeType,
      size: size,
      createdAt: DateTime.now(),
    );

    await _repository.addFile(entry);
    await refresh();
    return entry;
  }

  /// Deletes file metadata from library.
  Future<void> deleteEntry(String id) async {
    await _repository.deleteFile(id);
    await refresh();
  }

  /// Creates a sample demo file inside the workspace imports folder for testing Phase 0.
  Future<void> createDemoSampleFile() async {
    try {
      final now = DateTime.now();
      final filename = 'Tai_lieu_mau_${now.millisecondsSinceEpoch}.pdf';
      final file = File(p.join(_workspaceManager.importsDir.path, filename));
      file.writeAsStringSync('NguyenDu Tool - Sample Document');

      await recordFile(
        originalName: filename,
        localPath: file.path,
        mimeType: 'application/pdf',
        size: file.lengthSync(),
      );
    } catch (e, st) {
      AppLogger.error('Failed to create demo sample file', e, st);
    }
  }

  /// Opens the containing folder in Windows Explorer and selects the file.
  Future<void> openFileLocation(String localPath) async {
    await WorkspaceManager.openContainingFolder(localPath);
  }
}
