import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../core/database/app_database.dart';
import '../../../core/filesystem/workspace_manager.dart';
import '../../../core/logging/app_logger.dart';
import '../../pdf_converter/domain/models/ocr_models.dart';
import '../domain/models/document_quad.dart';
import '../domain/models/scan_options.dart';
import '../domain/models/scan_page.dart';
import '../domain/models/scan_session.dart';
import '../domain/repositories/scan_session_repository.dart';

/// SQLite and Manifest-backed implementation of [ScanSessionRepository].
/// Provides durable storage, crash recovery, and non-destructive session restoration.
class SqliteScanSessionRepository implements ScanSessionRepository {
  final AppDatabase appDatabase;

  SqliteScanSessionRepository({required this.appDatabase});

  Database get _db => appDatabase.db;

  @override
  Future<void> saveSession(ScanSession session) async {
    try {
      final now = DateTime.now().toIso8601String();

      // Wrap in atomic transaction with ConflictAlgorithm.replace to prevent concurrency races and UNIQUE constraint crashes
      await _db.transaction((txn) async {
        // 1. Safe insert or update scan_sessions table without replace
        final existing = await txn.query(
          'scan_sessions',
          where: 'id = ?',
          whereArgs: [session.id],
          limit: 1,
        );
        final sessionMap = {
          'id': session.id,
          'name': session.name,
          'source_type': session.sourceType.name,
          'status': session.status,
          'created_at': session.createdAt.toIso8601String(),
          'updated_at': now,
        };
        if (existing.isEmpty) {
          await txn.insert(
            'scan_sessions',
            sessionMap,
            conflictAlgorithm: ConflictAlgorithm.abort,
          );
        } else {
          await txn.update(
            'scan_sessions',
            sessionMap,
            where: 'id = ?',
            whereArgs: [session.id],
          );
        }

        // 2. Refresh scan_pages table
        await txn.delete('scan_pages', where: 'session_id = ?', whereArgs: [session.id]);

        final batch = txn.batch();
        for (final page in session.pages) {
          batch.insert(
            'scan_pages',
            {
              'id': page.id,
              'session_id': session.id,
              'page_index': page.pageIndex,
              'original_path': page.originalPath,
              'processed_path': page.processedPath,
              'rotation': page.rotation,
              'crop_json': page.detectedQuad != null ? jsonEncode(page.detectedQuad!.toJson()) : null,
              'quality_json': page.quality != null ? jsonEncode(page.quality!.toJson()) : null,
              'ocr_status': page.ocrStatus,
              'ocr_text': page.ocrResult?.fullText,
              'ocr_json': page.ocrResult != null ? jsonEncode(page.ocrResult!.toJson()) : null,
              'created_at': page.createdAt.toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.abort,
          );
        }
        await batch.commit(noResult: true);
      });

      // 3. Write manifest file to disk for crash recovery redundancy
      final sessionDir = Directory(p.join(WorkspaceManager.getDefaultWorkspacePath(), 'temp', 'scans', session.id));
      if (!sessionDir.existsSync()) {
        sessionDir.createSync(recursive: true);
      }
      final manifestFile = File(p.join(sessionDir.path, 'session_manifest.json'));
      await manifestFile.writeAsString(jsonEncode(session.toJson()));
    } catch (e, st) {
      AppLogger.error('Failed to save scan session ${session.id}: $e', e, st);
      rethrow;
    }
  }

  @override
  Future<ScanSession?> getSession(String id) async {
    try {
      final sessionRows = await _db.query(
        'scan_sessions',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (sessionRows.isEmpty) return null;
      final sRow = sessionRows.first;

      final pageRows = await _db.query(
        'scan_pages',
        where: 'session_id = ?',
        whereArgs: [id],
        orderBy: 'page_index ASC',
      );

      final pages = <ScanPage>[];
      for (final pRow in pageRows) {
        DocumentQuad? quad;
        if (pRow['crop_json'] != null) {
          try {
            final quadMap = jsonDecode(pRow['crop_json'] as String) as Map<String, dynamic>;
            quad = DocumentQuad.fromJson(quadMap);
          } catch (_) {}
        }

        PageQualityAssessment? quality;
        if (pRow['quality_json'] != null) {
          try {
            final qMap = jsonDecode(pRow['quality_json'] as String) as Map<String, dynamic>;
            quality = PageQualityAssessment.fromJson(qMap);
          } catch (_) {}
        }

        OcrPageResult? ocrRes;
        if (pRow['ocr_json'] != null) {
          try {
            final ocrMap = jsonDecode(pRow['ocr_json'] as String) as Map<String, dynamic>;
            ocrRes = OcrPageResult.fromJson(ocrMap);
          } catch (_) {}
        }

        pages.add(
          ScanPage(
            id: pRow['id'] as String,
            sessionId: id,
            pageIndex: pRow['page_index'] as int,
            originalPath: pRow['original_path'] as String,
            processedPath: pRow['processed_path'] as String,
            rotation: pRow['rotation'] as int? ?? 0,
            detectedQuad: quad,
            quality: quality,
            ocrResult: ocrRes,
            ocrStatus: pRow['ocr_status'] as String? ?? 'none',
            createdAt: DateTime.tryParse(pRow['created_at'] as String? ?? '') ?? DateTime.now(),
          ),
        );
      }

      final sourceTypeStr = sRow['source_type'] as String? ?? 'imageImport';
      final source = ScanSource.values.firstWhere(
        (e) => e.name == sourceTypeStr,
        orElse: () => ScanSource.imageImport,
      );

      return ScanSession(
        id: id,
        name: sRow['name'] as String? ?? 'Phiên quét',
        sourceType: source,
        pages: pages,
        status: sRow['status'] as String? ?? 'active',
        createdAt: DateTime.tryParse(sRow['created_at'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(sRow['updated_at'] as String? ?? '') ?? DateTime.now(),
      );
    } catch (e, st) {
      AppLogger.error('Failed to get session $id: $e', e, st);
      return null;
    }
  }

  @override
  Future<List<ScanSession>> getUnfinishedSessions() async {
    try {
      final rows = await _db.query(
        'scan_sessions',
        where: "status = 'active'",
        orderBy: 'updated_at DESC',
      );

      final result = <ScanSession>[];
      for (final r in rows) {
        final id = r['id'] as String;
        final s = await getSession(id);
        if (s != null && s.pages.isNotEmpty) {
          result.add(s);
        }
      }
      return result;
    } catch (e) {
      AppLogger.warning('Failed to query unfinished scan sessions: $e');
      return const [];
    }
  }

  @override
  Future<void> deleteSession(String id) async {
    try {
      await _db.delete('scan_pages', where: 'session_id = ?', whereArgs: [id]);
      await _db.delete('scan_sessions', where: 'id = ?', whereArgs: [id]);

      final sessionDir = Directory(p.join(Directory.current.path, 'temp', 'scans', id));
      if (sessionDir.existsSync()) {
        sessionDir.deleteSync(recursive: true);
      }
    } catch (e) {
      AppLogger.warning('Failed to delete session $id: $e');
    }
  }
}
