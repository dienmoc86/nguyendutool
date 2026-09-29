import '../models/scan_session.dart';

/// Contract for persisting scan sessions and pages into SQLite database and local disk manifest.
abstract class ScanSessionRepository {
  Future<void> saveSession(ScanSession session);
  Future<ScanSession?> getSession(String id);
  Future<List<ScanSession>> getUnfinishedSessions();
  Future<void> deleteSession(String id);
}
