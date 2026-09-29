import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/database/app_database.dart';
import 'package:nguyendu_tool/features/scanner/domain/models/document_quad.dart';
import 'package:nguyendu_tool/features/scanner/domain/models/scan_options.dart';
import 'package:nguyendu_tool/features/scanner/domain/models/scan_page.dart';
import 'package:nguyendu_tool/features/scanner/domain/models/scan_session.dart';
import 'package:nguyendu_tool/features/scanner/infrastructure/sqlite_scan_session_repository.dart';

void main() {
  group('ScanSession Domain Operations', () {
    test('Add, reorder, duplicate, delete maintains correct page indices', () {
      final now = DateTime.now();
      var session = ScanSession(
        id: 'sess_1',
        name: 'Phiên kiểm thử',
        sourceType: ScanSource.imageImport,
        createdAt: now,
        updatedAt: now,
      );

      final p1 = ScanPage(
        id: 'p1',
        sessionId: 'sess_1',
        pageIndex: 0,
        originalPath: 'C:/temp/p1_orig.png',
        processedPath: 'C:/temp/p1_proc.png',
        createdAt: now,
      );
      final p2 = ScanPage(
        id: 'p2',
        sessionId: 'sess_1',
        pageIndex: 1,
        originalPath: 'C:/temp/p2_orig.png',
        processedPath: 'C:/temp/p2_proc.png',
        createdAt: now,
      );
      final p3 = ScanPage(
        id: 'p3',
        sessionId: 'sess_1',
        pageIndex: 2,
        originalPath: 'C:/temp/p3_orig.png',
        processedPath: 'C:/temp/p3_proc.png',
        createdAt: now,
      );

      session = session.addPage(p1).addPage(p2).addPage(p3);
      expect(session.pageCount, equals(3));
      expect(session.pages[0].id, equals('p1'));
      expect(session.pages[1].id, equals('p2'));
      expect(session.pages[2].id, equals('p3'));

      // Reorder: move p3 to index 0
      session = session.reorderPage(2, 0);
      expect(session.pages[0].id, equals('p3'));
      expect(session.pages[0].pageIndex, equals(0));
      expect(session.pages[1].id, equals('p1'));
      expect(session.pages[1].pageIndex, equals(1));
      expect(session.pages[2].id, equals('p2'));
      expect(session.pages[2].pageIndex, equals(2));

      // Duplicate p1 (at index 1)
      session = session.duplicatePageAt(1, 'p1_dup');
      expect(session.pageCount, equals(4));
      expect(session.pages[2].id, equals('p1_dup'));
      expect(session.pages[2].pageIndex, equals(2));

      // Delete original p1 (at index 1)
      session = session.removePageAt(1);
      expect(session.pageCount, equals(3));
      expect(session.pages[0].id, equals('p3'));
      expect(session.pages[1].id, equals('p1_dup'));
      expect(session.pages[2].id, equals('p2'));
    });

    test('Rotation pipeline normalizes angles across 0°, 90°, 180°, 270°', () {
      final now = DateTime.now();
      var session = ScanSession(
        id: 'sess_rot',
        name: 'Phiên xoay',
        sourceType: ScanSource.physicalScanner,
        createdAt: now,
        updatedAt: now,
      );

      final p1 = ScanPage(
        id: 'p1',
        sessionId: 'sess_rot',
        pageIndex: 0,
        originalPath: 'C:/temp/p1_orig.png',
        processedPath: 'C:/temp/p1_proc.png',
        rotation: 0,
        createdAt: now,
      );
      session = session.addPage(p1);

      // +90 deg
      session = session.rotatePageAt(0, 90);
      expect(session.pages[0].rotation, equals(90));

      // +90 deg -> 180
      session = session.rotatePageAt(0, 90);
      expect(session.pages[0].rotation, equals(180));

      // +90 deg -> 270
      session = session.rotatePageAt(0, 90);
      expect(session.pages[0].rotation, equals(270));

      // +90 deg -> 0
      session = session.rotatePageAt(0, 90);
      expect(session.pages[0].rotation, equals(0));

      // -90 deg -> 270
      session = session.rotatePageAt(0, -90);
      expect(session.pages[0].rotation, equals(270));
    });
  });

  group('SqliteScanSessionRepository - Persistence & Recovery', () {
    late AppDatabase appDb;
    late SqliteScanSessionRepository repo;

    setUp(() async {
      appDb = AppDatabase(inMemory: true);
      await appDb.init();
      repo = SqliteScanSessionRepository(appDatabase: appDb);
    });

    tearDown(() async {
      await appDb.close();
    });

    test('Saves and restores scan session with pages and crop metadata', () async {
      final now = DateTime.now();
      final session = ScanSession(
        id: 'session_persisted',
        name: 'Tài liệu giáo án',
        sourceType: ScanSource.imageImport,
        pages: [
          ScanPage(
            id: 'page_db_1',
            sessionId: 'session_persisted',
            pageIndex: 0,
            originalPath: 'C:/temp/db_orig.png',
            processedPath: 'C:/temp/db_proc.png',
            rotation: 0,
            detectedQuad: const DocumentQuad(
              topLeft: Point2D(10, 10),
              topRight: Point2D(500, 10),
              bottomRight: Point2D(500, 700),
              bottomLeft: Point2D(10, 700),
            ),
            createdAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      await repo.saveSession(session);

      final restored = await repo.getSession('session_persisted');
      expect(restored, isNotNull);
      expect(restored!.name, equals('Tài liệu giáo án'));
      expect(restored.pageCount, equals(1));
      expect(restored.pages[0].detectedQuad?.bottomRight.x, equals(500.0));

      // Check unfinished sessions
      final unfinished = await repo.getUnfinishedSessions();
      expect(unfinished.any((s) => s.id == 'session_persisted'), isTrue);
    });
  });
}
