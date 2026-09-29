import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/logging/app_logger.dart';
import '../domain/models/pronunciation_rule.dart';

/// Service managing the local pronunciation dictionary stored in SQLite.
/// Allows teachers and administrators to map educational acronyms and domain terminology
/// into spoken phonetic phrases without altering original text documents.
class PronunciationDictionaryService {
  final AppDatabase _db;
  List<PronunciationRule>? _cachedRules;

  PronunciationDictionaryService({AppDatabase? database})
      : _db = database ?? AppDatabase();

  /// Loads all pronunciation rules from database ordered by source phrase length descending
  /// (to ensure longer phrases match before substrings).
  Future<List<PronunciationRule>> getAllRules({bool forceRefresh = false}) async {
    if (_cachedRules != null && !forceRefresh) {
      return _cachedRules!;
    }

    try {
      final db = await _db.database;
      final rows = await db.query(
        'pronunciation_dictionary',
        orderBy: 'LENGTH(source_phrase) DESC',
      );

      _cachedRules = rows.map((r) => PronunciationRule.fromJson(r)).toList();
      return _cachedRules!;
    } catch (e, stack) {
      AppLogger.error('Failed to load pronunciation dictionary', e, stack);
      return [];
    }
  }

  /// Adds a new pronunciation rule to SQLite.
  Future<PronunciationRule> addRule({
    required String sourcePhrase,
    required String replacementPhrase,
    bool isCaseSensitive = false,
    bool isRegex = false,
    String? notes,
  }) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    final rule = PronunciationRule(
      id: const Uuid().v4(),
      sourcePhrase: sourcePhrase.trim(),
      replacementPhrase: replacementPhrase.trim(),
      isCaseSensitive: isCaseSensitive,
      isRegex: isRegex,
      notes: notes,
    );

    await db.insert(
      'pronunciation_dictionary',
      {
        ...rule.toJson(),
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    _cachedRules = null; // Invalidate cache
    AppLogger.info('Added pronunciation rule: "${rule.sourcePhrase}" -> "${rule.replacementPhrase}"');
    return rule;
  }

  /// Updates an existing rule.
  Future<void> updateRule(PronunciationRule rule) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();

    await db.update(
      'pronunciation_dictionary',
      {
        ...rule.toJson(),
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [rule.id],
    );

    _cachedRules = null;
    AppLogger.info('Updated pronunciation rule: ${rule.id}');
  }

  /// Deletes a rule by ID.
  Future<void> deleteRule(String id) async {
    final db = await _db.database;
    await db.delete(
      'pronunciation_dictionary',
      where: 'id = ?',
      whereArgs: [id],
    );

    _cachedRules = null;
    AppLogger.info('Deleted pronunciation rule: $id');
  }

  /// Applies all dictionary rules sequentially to [text].
  Future<String> applyDictionary(String text) async {
    if (text.isEmpty) return text;
    final rules = await getAllRules();
    String result = text;
    for (final rule in rules) {
      result = rule.apply(result);
    }
    return result;
  }
}
