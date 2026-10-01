import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_tables.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/projects/domain/project_type.dart';
import '../../teaching_suite/domain/models/learning_objective.dart';
import '../../teaching_suite/domain/models/question_models.dart';
import '../domain/models/assessment_project_data.dart';
import '../domain/models/exam_code.dart';
import '../domain/models/exam_matrix.dart';
import '../domain/models/exam_paper.dart';
import '../domain/models/exam_question_snapshot.dart';
import '../domain/models/exam_specification.dart';

/// Result report of orphan exam code questions repair (Section 5).
class OrphanRepairReport {
  final int totalOrphans;
  final int repairedCount;
  final int ambiguousCount;
  final List<String> details;
  final bool isDryRun;

  const OrphanRepairReport({
    required this.totalOrphans,
    required this.repairedCount,
    required this.ambiguousCount,
    required this.details,
    required this.isDryRun,
  });

  @override
  String toString() =>
      'OrphanRepairReport(total: $totalOrphans, repaired: $repairedCount, ambiguous: $ambiguousCount, dryRun: $isDryRun)';
}

/// SQLite persistence repository for Assessment Studio (Section 58).
class AssessmentRepository {
  final AppDatabase? _appDatabase;
  final Database? _rawDb;

  AssessmentRepository(AppDatabase appDatabase)
      : _appDatabase = appDatabase,
        _rawDb = null;

  AssessmentRepository.withDb(Database db)
      : _appDatabase = null,
        _rawDb = db;

  Future<Database> get _db async {
    final db = _rawDb ?? await _appDatabase!.database;
    await db.execute('PRAGMA foreign_keys = ON;');
    return db;
  }

  /// Verifies foreign key integrity across the database.
  Future<List<Map<String, dynamic>>> checkForeignKeys() async {
    final db = await _db;
    return await db.rawQuery('PRAGMA foreign_key_check;');
  }

  /// Non-destructive, unambiguous repair strategy for historical orphan exam code questions (Section 5).
  Future<OrphanRepairReport> repairOrphanRecordsDetailed(
      {bool dryRun = false}) async {
    final db = await _db;
    int repaired = 0;
    int ambiguous = 0;
    final List<String> details = [];

    await db.transaction((txn) async {
      final orphans = await txn.rawQuery('''
        SELECT ecq.id, ecq.exam_code_id, ecq.question_id, ecq.snapshot_json
        FROM ${DatabaseTables.tableExamCodeQuestions} ecq
        LEFT JOIN ${DatabaseTables.tableExamCodes} ec ON ecq.exam_code_id = ec.id
        WHERE ec.id IS NULL;
      ''');

      for (final row in orphans) {
        final qRowId = row['id'] as String;
        final badCodeId = row['exam_code_id'] as String;
        final questionId = row['question_id'] as String;

        // Extract code label: if 'ec_101' -> '101', if 'ec_paperId_101' -> '101'
        String codeStr = badCodeId.replaceFirst(RegExp(r'^ec_'), '');
        if (codeStr.contains('_')) {
          codeStr = codeStr.split('_').last;
        }

        // Query all candidate parents matching codeStr
        final candidateParents = await txn.query(
          DatabaseTables.tableExamCodes,
          where: 'code = ?',
          whereArgs: [codeStr],
        );

        if (candidateParents.isEmpty) {
          ambiguous++;
          details.add(
            'AMBIGUOUS_PARENT: Không tìm thấy bất kỳ mã đề cha nào có nhãn "$codeStr" cho câu mồ côi $qRowId.',
          );
          continue;
        }

        if (candidateParents.length == 1) {
          // Exactly one candidate parent in the entire database!
          final candidate = candidateParents.first;
          final candidatePaperId = candidate['exam_paper_id'] as String;

          final paperQuestionRows = await txn.query(
            DatabaseTables.tableExamPaperQuestions,
            where: 'exam_paper_id = ?',
            whereArgs: [candidatePaperId],
            limit: 1,
          );

          // If master paper questions exist, verify that this question belongs to it
          final bool isUnambiguous;
          if (paperQuestionRows.isNotEmpty) {
            final matching = await txn.query(
              DatabaseTables.tableExamPaperQuestions,
              where: 'exam_paper_id = ? AND question_id = ?',
              whereArgs: [candidatePaperId, questionId],
            );
            isUnambiguous = matching.isNotEmpty;
          } else {
            // Paper has no question rows (e.g. historical minimal database / single parent candidate)
            isUnambiguous = true;
          }

          if (isUnambiguous) {
            // Unambiguously resolved!
            final realParentId = candidate['id'] as String;
            if (!dryRun) {
              await txn.update(
                DatabaseTables.tableExamCodeQuestions,
                {'exam_code_id': realParentId},
                where: 'id = ?',
                whereArgs: [qRowId],
              );
            }
            repaired++;
            details.add(
              'REPAIRED: Câu $qRowId ($questionId) được liên kết duy nhất với mã đề $realParentId (đề $candidatePaperId).',
            );
          } else {
            ambiguous++;
            details.add(
              'AMBIGUOUS_PARENT: Tìm thấy 1 mã đề $codeStr nhưng đề thi gốc $candidatePaperId không chứa câu $questionId.',
            );
          }
        } else {
          // Multiple candidate parents exist with the same student code (e.g. 101) across different exams!
          // Filter candidate parents whose master paper actually contains this question_id:
          final List<Map<String, dynamic>> verifiedCandidates = [];
          for (final cp in candidateParents) {
            final paperId = cp['exam_paper_id'] as String;
            final pq = await txn.query(
              DatabaseTables.tableExamPaperQuestions,
              where: 'exam_paper_id = ? AND question_id = ?',
              whereArgs: [paperId, questionId],
            );
            if (pq.isNotEmpty) {
              verifiedCandidates.add(cp);
            }
          }

          if (verifiedCandidates.length == 1) {
            // Unambiguously resolved through validated question snapshot relationship!
            final realParentId = verifiedCandidates.first['id'] as String;
            if (!dryRun) {
              await txn.update(
                DatabaseTables.tableExamCodeQuestions,
                {'exam_code_id': realParentId},
                where: 'id = ?',
                whereArgs: [qRowId],
              );
            }
            repaired++;
            details.add(
              'REPAIRED: Câu $qRowId ($questionId) giải quyết đơn trị thành công với mã đề $realParentId trong số ${candidateParents.length} ứng viên.',
            );
          } else {
            // Multiple or 0 verified candidates: DO NOT GUESS. DO NOT RELINK. Preserve original orphan.
            ambiguous++;
            details.add(
              'AMBIGUOUS_PARENT: Phát hiện ${candidateParents.length} mã đề tiềm năng có nhãn "$codeStr" cho câu $qRowId ($questionId) nhưng có ${verifiedCandidates.length} ứng viên thỏa mãn câu hỏi. Giữ nguyên không can thiệp.',
            );
          }
        }
      }
    });

    return OrphanRepairReport(
      totalOrphans: repaired + ambiguous,
      repairedCount: repaired,
      ambiguousCount: ambiguous,
      details: details,
      isDryRun: dryRun,
    );
  }

  /// Backward-compatible repairOrphanRecords returning count of repaired records.
  Future<int> repairOrphanRecords({bool dryRun = false}) async {
    final report = await repairOrphanRecordsDetailed(dryRun: dryRun);
    return report.repairedCount;
  }

  // ==========================================
  // PROJECT METADATA
  // ==========================================

  /// Saves or updates AssessmentProjectData inside workspace_projects table.
  Future<void> saveProjectData(AssessmentProjectData data) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      final existing = await txn.query(
        DatabaseTables.tableWorkspaceProjects,
        columns: ['id', 'created_at', 'type'],
        where: 'id = ?',
        whereArgs: [data.id],
        limit: 1,
      );

      if (existing.isEmpty) {
        // New project: INSERT with ConflictAlgorithm.abort
        await txn.insert(
          DatabaseTables.tableWorkspaceProjects,
          {
            'id': data.id,
            'type': ProjectType.assessment.id,
            'name': data.name,
            'status': 'active',
            'created_at': data.createdAt.toIso8601String(),
            'updated_at': now,
            'metadata_json': data.toJson(),
          },
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      } else {
        // Existing project: UPDATE allowed fields, NEVER replace parent to prevent cascade delete
        await txn.update(
          DatabaseTables.tableWorkspaceProjects,
          {
            'name': data.name,
            'updated_at': now,
            'metadata_json': data.toJson(),
          },
          where: 'id = ?',
          whereArgs: [data.id],
        );
      }
    });
    AppLogger.info('Saved AssessmentProjectData: ${data.id}');
  }

  /// Retrieves AssessmentProjectData by ID.
  Future<AssessmentProjectData?> getProjectData(String projectId) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseTables.tableWorkspaceProjects,
      where: 'id = ?',
      whereArgs: [projectId],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    final row = rows.first;
    final metaStr = row['metadata_json'] as String?;
    if (metaStr != null && metaStr.isNotEmpty) {
      try {
        return AssessmentProjectData.fromJson(metaStr);
      } catch (e) {
        AppLogger.warning('Failed to parse metadata_json for assessment project $projectId: $e');
      }
    }

    return AssessmentProjectData(
      id: projectId,
      name: row['name'] as String? ?? 'Đề kiểm tra',
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  // ==========================================
  // SPECIFICATION
  // ==========================================

  /// Saves or updates ExamSpecification without using ConflictAlgorithm.replace.
  /// If referenced by a finalized exam paper, protected blueprint fields cannot be mutated.
  Future<void> saveSpecification(ExamSpecification spec) async {
    final db = await _db;
    await db.transaction((txn) async {
      final existingRows = await txn.query(
        DatabaseTables.tableExamSpecifications,
        where: 'id = ?',
        whereArgs: [spec.id],
        limit: 1,
      );

      // Check if any finalized paper references this specification
      final finalizedPapers = await txn.query(
        DatabaseTables.tableExamPapers,
        where: 'specification_id = ? AND is_finalized = 1',
        whereArgs: [spec.id],
        limit: 1,
      );

      if (finalizedPapers.isNotEmpty && existingRows.isNotEmpty) {
        final existing = existingRows.first;
        final diffs = <String>[];
        if (existing['subject'] != spec.subject) diffs.add('subject');
        if (existing['grade'] != spec.grade) diffs.add('grade');
        if (existing['duration_minutes'] != spec.durationMinutes) diffs.add('durationMinutes');
        if (((existing['total_score'] as num?)?.toDouble() ?? 0.0) != spec.totalScore) diffs.add('totalScore');
        if (existing['question_count'] != spec.questionCount) diffs.add('questionCount');
        final newTypesJson = jsonEncode(spec.allowedQuestionTypes.map((t) => t.name).toList());
        if (existing['allowed_question_types_json'] != newTypesJson) diffs.add('allowedQuestionTypes');

        if (diffs.isNotEmpty) {
          throw FinalizedExamImmutableException(
            'Cannot modify specification ${spec.id} referenced by finalized exam paper. '
            'Protected blueprint fields are immutable: ${diffs.join(', ')}. Create a new specification revision instead.',
          );
        }
      }

      if (existingRows.isEmpty) {
        await txn.insert(
          DatabaseTables.tableExamSpecifications,
          spec.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      } else {
        await txn.update(
          DatabaseTables.tableExamSpecifications,
          spec.toMap(),
          where: 'id = ?',
          whereArgs: [spec.id],
        );
      }
    });
    AppLogger.info('Saved ExamSpecification: ${spec.id} for project ${spec.projectId}');
  }

  Future<ExamSpecification?> getSpecification(String projectId) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseTables.tableExamSpecifications,
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'updated_at DESC',
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return ExamSpecification.fromMap(rows.first);
  }

  // ==========================================
  // MATRIX
  // ==========================================

  /// Saves matrix cells. If referenced by a finalized exam, cells cannot be mutated.
  Future<void> saveMatrix(ExamMatrix matrix) async {
    final db = await _db;
    await db.transaction((txn) async {
      // Check if a finalized exam paper references this specification
      final finalizedPapers = await txn.query(
        DatabaseTables.tableExamPapers,
        where: 'specification_id = ? AND is_finalized = 1',
        whereArgs: [matrix.specificationId],
        limit: 1,
      );

      if (finalizedPapers.isNotEmpty) {
        final existingCells = await txn.query(
          DatabaseTables.tableExamMatrixCells,
          where: 'specification_id = ?',
          whereArgs: [matrix.specificationId],
        );
        final existingSigs = existingCells.map((r) =>
          '${r['id']}_${r['objective_id']}_${r['difficulty']}_${r['question_count']}_${r['score_per_question']}').toSet();
        final newSigs = matrix.cells.map((c) =>
          '${c.id}_${c.objectiveId}_${c.difficulty.name}_${c.questionCount}_${c.scorePerQuestion}').toSet();

        if (existingSigs.length == newSigs.length && existingSigs.containsAll(newSigs)) {
          // Idempotent re-save of identical matrix on finalized paper: safe no-op
          return;
        } else {
          throw FinalizedExamImmutableException(
            'Cannot modify matrix cells for specification ${matrix.specificationId} referenced by finalized exam paper.',
          );
        }
      }

      await txn.delete(
        DatabaseTables.tableExamMatrixCells,
        where: 'specification_id = ?',
        whereArgs: [matrix.specificationId],
      );

      for (final cell in matrix.cells) {
        await txn.insert(
          DatabaseTables.tableExamMatrixCells,
          cell.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    });
    AppLogger.info('Saved ExamMatrix for spec ${matrix.specificationId} with ${matrix.cells.length} cells');
  }

  Future<ExamMatrix?> getMatrix(String specificationId) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseTables.tableExamMatrixCells,
      where: 'specification_id = ?',
      whereArgs: [specificationId],
    );

    if (rows.isEmpty) return null;
    final cells = rows.map((r) => ExamMatrixCell.fromMap(r)).toList();
    return ExamMatrix(specificationId: specificationId, cells: cells);
  }

  // ==========================================
  // MASTER EXAM PAPER & SNAPSHOTS
  // ==========================================

  Future<void> saveExamPaper(ExamPaper paper) async {
    final db = await _db;
    await db.transaction((txn) async {
      // P0 Finding 1 & 2: Explicit INSERT/UPDATE semantics and Finalized Immutability
      final existingRows = await txn.query(
        DatabaseTables.tableExamPapers,
        where: 'id = ?',
        whereArgs: [paper.id],
        limit: 1,
      );

      if (existingRows.isNotEmpty) {
        final existing = existingRows.first;
        final isCurrentlyFinalized = (existing['is_finalized'] as int?) == 1;

        if (isCurrentlyFinalized) {
          // P0 Finding 2: Protect ALL metadata fields from being mutated
          final existingProjectId = existing['project_id'] as String;
          final existingSpecId = existing['specification_id'] as String;
          final existingTitle = existing['title'] as String;
          final existingExamCode = existing['exam_code'] as String;
          final existingDuration = existing['duration_minutes'] as int;
          final existingTotalScore =
              ((existing['total_score'] as num?)?.toDouble() ?? 0.0);
          final existingRandomSeed = existing['random_seed'] as int?;
          final existingRevisionNumber = existing['revision_number'] as int;
          final incomingIsFinalized = paper.isFinalized;

          if (existingProjectId != paper.assessmentProjectId ||
              existingSpecId != paper.specificationId ||
              existingTitle != paper.title ||
              existingExamCode != paper.examCode ||
              existingDuration != paper.durationMinutes ||
              (existingTotalScore - paper.totalScore).abs() > 0.001 ||
              existingRandomSeed != paper.randomSeed ||
              existingRevisionNumber != paper.revisionNumber ||
              !incomingIsFinalized) {
            throw FinalizedExamImmutableException(
              'Đề thi ${paper.id} đã được chốt duyệt (Finalized). '
              'Không thể sửa đổi bất kỳ thông tin đặc tả nào (dự án, tiêu đề, mã đề, thời gian, điểm, bản sửa đổi hoặc chuyển về bản nháp).',
              paperId: paper.id,
            );
          }

          final existingQRows = await txn.query(
            DatabaseTables.tableExamPaperQuestions,
            where: 'exam_paper_id = ?',
            whereArgs: [paper.id],
            orderBy: 'order_index ASC',
          );

          bool questionsMutated =
              existingQRows.length != paper.questions.length;
          if (!questionsMutated) {
            for (int i = 0; i < existingQRows.length; i++) {
              final eq = existingQRows[i];
              final pq = paper.questions[i];
              if (eq['question_id'] != pq.questionId ||
                  ((eq['score'] as num?)?.toDouble() ?? 0.0) != pq.score ||
                  eq['order_index'] != i ||
                  eq['snapshot_json'] != pq.toJson()) {
                questionsMutated = true;
                break;
              }
            }
          }

          if (questionsMutated) {
            throw FinalizedExamImmutableException(
              'Đề thi ${paper.id} đã được chốt duyệt (Finalized) và là bất biến. Không thể ghi đè, thay đổi câu hỏi, điểm số hoặc thứ tự.',
              paperId: paper.id,
            );
          }

          // Identical finalized paper: return without mutation to avoid any cascade or modification!
          AppLogger.info(
              'ExamPaper ${paper.id} is finalized and unchanged; skipped mutation.');
          return;
        } else {
          // Draft paper update: Explicit UPDATE
          await txn.update(
            DatabaseTables.tableExamPapers,
            {
              'project_id': paper.assessmentProjectId,
              'specification_id': paper.specificationId,
              'title': paper.title,
              'exam_code': paper.examCode,
              'duration_minutes': paper.durationMinutes,
              'total_score': paper.totalScore,
              'random_seed': paper.randomSeed,
              'revision_number': paper.revisionNumber,
              'is_finalized': paper.isFinalized ? 1 : 0,
              'created_at': paper.createdAt.toIso8601String(),
              'finalized_at': paper.finalizedAt?.toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [paper.id],
          );

          // Check if questions are unchanged:
          final existingQRows = await txn.query(
            DatabaseTables.tableExamPaperQuestions,
            where: 'exam_paper_id = ?',
            whereArgs: [paper.id],
            orderBy: 'order_index ASC',
          );

          bool questionsChanged =
              existingQRows.length != paper.questions.length;
          if (!questionsChanged) {
            for (int i = 0; i < existingQRows.length; i++) {
              final eq = existingQRows[i];
              final pq = paper.questions[i];
              if (eq['question_id'] != pq.questionId ||
                  ((eq['score'] as num?)?.toDouble() ?? 0.0) != pq.score ||
                  eq['order_index'] != i ||
                  eq['snapshot_json'] != pq.toJson()) {
                questionsChanged = true;
                break;
              }
            }
          }

          if (questionsChanged) {
            await txn.delete(
              DatabaseTables.tableExamPaperQuestions,
              where: 'exam_paper_id = ?',
              whereArgs: [paper.id],
            );

            for (int i = 0; i < paper.questions.length; i++) {
              final q = paper.questions[i];
              final qId = 'epq_${paper.id}_${q.questionId}_$i';
              await txn.insert(
                DatabaseTables.tableExamPaperQuestions,
                {
                  'id': qId,
                  'exam_paper_id': paper.id,
                  'question_id': q.questionId,
                  'order_index': i,
                  'score': q.score,
                  'section_index': q.sectionIndex,
                  'snapshot_json': q.toJson(),
                },
                conflictAlgorithm: ConflictAlgorithm.abort,
              );
            }
          }
          AppLogger.info(
              'Updated draft ExamPaper ${paper.id} with ${paper.questions.length} questions');
          return;
        }
      }

      // New paper: Explicit INSERT
      await txn.insert(
        DatabaseTables.tableExamPapers,
        {
          'id': paper.id,
          'project_id': paper.assessmentProjectId,
          'specification_id': paper.specificationId,
          'title': paper.title,
          'exam_code': paper.examCode,
          'duration_minutes': paper.durationMinutes,
          'total_score': paper.totalScore,
          'random_seed': paper.randomSeed,
          'revision_number': paper.revisionNumber,
          'is_finalized': paper.isFinalized ? 1 : 0,
          'created_at': paper.createdAt.toIso8601String(),
          'finalized_at': paper.finalizedAt?.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      for (int i = 0; i < paper.questions.length; i++) {
        final q = paper.questions[i];
        final qId = 'epq_${paper.id}_${q.questionId}_$i';
        await txn.insert(
          DatabaseTables.tableExamPaperQuestions,
          {
            'id': qId,
            'exam_paper_id': paper.id,
            'question_id': q.questionId,
            'order_index': i,
            'score': q.score,
            'section_index': q.sectionIndex,
            'snapshot_json': q.toJson(),
          },
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    });
    AppLogger.info(
        'Saved ExamPaper ${paper.id} with ${paper.questions.length} questions');
  }

  /// Lists all exam papers/revisions for a project.
  Future<List<ExamPaper>> listExamPapers(String projectId) async {
    final db = await _db;
    final paperRows = await db.query(
      DatabaseTables.tableExamPapers,
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'revision_number ASC, created_at DESC',
    );

    final List<ExamPaper> results = [];
    for (final paperRow in paperRows) {
      final paperId = paperRow['id'] as String;
      final qRows = await db.query(
        DatabaseTables.tableExamPaperQuestions,
        where: 'exam_paper_id = ?',
        whereArgs: [paperId],
        orderBy: 'order_index ASC',
      );

      final List<ExamQuestionSnapshot> questions = [];
      for (final qr in qRows) {
        final snapJson = qr['snapshot_json'] as String?;
        if (snapJson != null && snapJson.isNotEmpty) {
          try {
            questions.add(ExamQuestionSnapshot.fromJson(snapJson));
          } catch (_) {}
        }
      }
      results.add(ExamPaper.fromMap(paperRow, questions: questions));
    }
    return results;
  }

  /// Retrieves an exam paper by its unique ID.
  Future<ExamPaper?> getExamPaperById(String paperId) async {
    final db = await _db;
    final paperRows = await db.query(
      DatabaseTables.tableExamPapers,
      where: 'id = ?',
      whereArgs: [paperId],
      limit: 1,
    );

    if (paperRows.isEmpty) return null;
    final paperRow = paperRows.first;

    final qRows = await db.query(
      DatabaseTables.tableExamPaperQuestions,
      where: 'exam_paper_id = ?',
      whereArgs: [paperId],
      orderBy: 'order_index ASC',
    );

    final List<ExamQuestionSnapshot> questions = [];
    for (final qr in qRows) {
      final snapJson = qr['snapshot_json'] as String?;
      if (snapJson != null && snapJson.isNotEmpty) {
        try {
          questions.add(ExamQuestionSnapshot.fromJson(snapJson));
        } catch (_) {}
      }
    }

    return ExamPaper.fromMap(paperRow, questions: questions);
  }

  /// Retrieves the latest draft exam paper for a project.
  Future<ExamPaper?> getLatestDraft(String projectId) async {
    final db = await _db;
    final paperRows = await db.query(
      DatabaseTables.tableExamPapers,
      where: 'project_id = ? AND is_finalized = 0',
      whereArgs: [projectId],
      orderBy: 'revision_number DESC, created_at DESC',
      limit: 1,
    );

    if (paperRows.isEmpty) return null;
    return getExamPaperById(paperRows.first['id'] as String);
  }

  /// Retrieves the latest finalized exam paper for a project.
  Future<ExamPaper?> getLatestFinalized(String projectId) async {
    final db = await _db;
    final paperRows = await db.query(
      DatabaseTables.tableExamPapers,
      where: 'project_id = ? AND is_finalized = 1',
      whereArgs: [projectId],
      orderBy: 'revision_number DESC, created_at DESC',
      limit: 1,
    );

    if (paperRows.isEmpty) return null;
    return getExamPaperById(paperRows.first['id'] as String);
  }

  /// Retrieves the current active master paper (prefers latest draft, falls back to latest finalized).
  Future<ExamPaper?> getExamPaper(String projectId) async {
    final draft = await getLatestDraft(projectId);
    if (draft != null) return draft;
    return await getLatestFinalized(projectId);
  }

  /// Finalizes an exam paper into an immutable record (Section 11).
  Future<void> finalizeExamPaper(String paperId) async {
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        DatabaseTables.tableExamPapers,
        where: 'id = ?',
        whereArgs: [paperId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw ArgumentError('Không tìm thấy đề thi $paperId để chốt duyệt.');
      }
      final paperRow = rows.first;
      if ((paperRow['is_finalized'] as int?) == 1) {
        AppLogger.info(
            'ExamPaper $paperId đã ở trạng thái Finalized từ trước, giữ nguyên.');
        return;
      }

      final qRows = await txn.query(
        DatabaseTables.tableExamPaperQuestions,
        where: 'exam_paper_id = ?',
        whereArgs: [paperId],
      );
      if (qRows.isEmpty) {
        throw const InvalidExamQuestionException(
            'Không thể chốt duyệt đề thi không có câu hỏi nào.');
      }

      final totalScore = (paperRow['total_score'] as num?)?.toDouble() ?? 0.0;
      if (totalScore <= 0 || totalScore.isNaN || totalScore.isInfinite) {
        throw ArgumentError('Tổng điểm đề thi không hợp lệ: $totalScore');
      }

      await txn.update(
        DatabaseTables.tableExamPapers,
        {
          'is_finalized': 1,
          'finalized_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [paperId],
      );
    });
    AppLogger.info('Finalized ExamPaper $paperId');
  }

  /// Creates a new editable revision from an existing exam paper.
  Future<ExamPaper> createNewRevision(String basePaperId) async {
    final basePaper = await getExamPaperById(basePaperId);
    if (basePaper == null) {
      throw ArgumentError(
          'Không tìm thấy đề thi gốc $basePaperId để tạo bản hiệu đính.');
    }

    final newRevisionNumber = basePaper.revisionNumber + 1;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final newPaperId =
        'paper_${basePaper.assessmentProjectId}_rev${newRevisionNumber}_$timestamp';

    final newPaper = ExamPaper(
      id: newPaperId,
      assessmentProjectId: basePaper.assessmentProjectId,
      specificationId: basePaper.specificationId,
      title: basePaper.title,
      examCode: basePaper.examCode,
      durationMinutes: basePaper.durationMinutes,
      totalScore: basePaper.totalScore,
      randomSeed: basePaper.randomSeed,
      revisionNumber: newRevisionNumber,
      isFinalized: false,
      questions: List<ExamQuestionSnapshot>.from(basePaper.questions),
      createdAt: DateTime.now(),
      finalizedAt: null,
    );

    await saveExamPaper(newPaper);
    AppLogger.info(
        'Created new revision $newRevisionNumber (id: $newPaperId) from $basePaperId');
    return newPaper;
  }

  // ==========================================
  // MULTI CODES & CODE QUESTIONS
  // ==========================================

  Future<void> saveExamCodes(List<ExamCode> codes) async {
    if (codes.isEmpty) return;
    final firstPaperId = codes.first.examPaperId;

    // Section 4: Pre-validation upfront BEFORE any database deletion
    final Set<String> codeIds = {};
    final Set<String> codeLabels = {};
    final Set<String> globalChildIds = {};

    for (final code in codes) {
      if (code.examPaperId != firstPaperId) {
        throw ArgumentError(
          'Tất cả các mã đề trong danh sách phải thuộc cùng một đề thi gốc ($firstPaperId), '
          'nhưng phát hiện mã đề ${code.code} thuộc ${code.examPaperId}.',
        );
      }
      if (code.id.trim().isEmpty) {
        throw ArgumentError('Mã định danh của ExamCode không được rỗng.');
      }
      if (!codeIds.add(code.id)) {
        throw ArgumentError('Phát hiện trùng lặp ExamCode.id: ${code.id}');
      }
      if (!codeLabels.add(code.code)) {
        throw ArgumentError('Phát hiện trùng lặp nhãn mã đề: ${code.code}');
      }

      final Set<String> questionsInCode = {};
      for (final q in code.questions) {
        if (q.examCodeId != code.id) {
          throw ArgumentError(
            'Câu hỏi mã đề ${q.id} có examCodeId (${q.examCodeId}) không khớp với mã đề cha (${code.id}).',
          );
        }
        if (q.id.trim().isEmpty) {
          throw ArgumentError(
              'Mã định danh ExamCodeQuestion.id không được rỗng.');
        }
        if (!globalChildIds.add(q.id)) {
          throw ArgumentError(
              'Phát hiện trùng lặp mã câu hỏi mã đề toàn cục: ${q.id}');
        }
        if (!questionsInCode.add(q.questionId)) {
          throw ArgumentError(
            'Phát hiện trùng lặp câu hỏi ${q.questionId} trong mã đề ${code.code}.',
          );
        }
        if (q.snapshot.prompt.trim().isEmpty) {
          throw ArgumentError(
            'Câu hỏi ${q.questionId} trong mã đề ${code.code} có nội dung snapshot rỗng.',
          );
        }
      }
    }

    final db = await _db;
    await db.transaction((txn) async {
      // Check if parent exam paper is finalized
      final paperRows = await txn.query(
        DatabaseTables.tableExamPapers,
        where: 'id = ?',
        whereArgs: [firstPaperId],
        limit: 1,
      );

      if (paperRows.isNotEmpty) {
        final isFinalized = (paperRows.first['is_finalized'] as int?) == 1;
        if (isFinalized) {
          final existingCodes = await txn.query(
            DatabaseTables.tableExamCodes,
            where: 'exam_paper_id = ?',
            whereArgs: [firstPaperId],
          );
          if (existingCodes.isNotEmpty) {
            throw FinalizedExamImmutableException(
              'Đề thi $firstPaperId đã chốt duyệt và các mã đề đã lưu là bất biến, không thể ghi đè.',
              paperId: firstPaperId,
            );
          }
        }
      }

      // Transactionally replace codes for this exam paper
      await txn.delete(
        DatabaseTables.tableExamCodeQuestions,
        where:
            'exam_code_id IN (SELECT id FROM ${DatabaseTables.tableExamCodes} WHERE exam_paper_id = ?)',
        whereArgs: [firstPaperId],
      );
      await txn.delete(
        DatabaseTables.tableExamCodes,
        where: 'exam_paper_id = ?',
        whereArgs: [firstPaperId],
      );

      for (final code in codes) {
        await txn.insert(
          DatabaseTables.tableExamCodes,
          {
            'id': code.id,
            'exam_paper_id': code.examPaperId,
            'code': code.code,
            'created_at': code.createdAt.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.abort,
        );

        for (final q in code.questions) {
          await txn.insert(
            DatabaseTables.tableExamCodeQuestions,
            q.toMap(),
            conflictAlgorithm: ConflictAlgorithm.abort,
          );
        }
      }
    });
    AppLogger.info(
        'Transactionally saved ${codes.length} ExamCodes for paper $firstPaperId');
  }

  Future<List<ExamCode>> getExamCodes(String examPaperId) async {
    final db = await _db;
    final codeRows = await db.query(
      DatabaseTables.tableExamCodes,
      where: 'exam_paper_id = ?',
      whereArgs: [examPaperId],
      orderBy: 'code ASC',
    );

    final List<ExamCode> results = [];
    for (final cr in codeRows) {
      final codeId = cr['id'] as String;
      final qRows = await db.query(
        DatabaseTables.tableExamCodeQuestions,
        where: 'exam_code_id = ?',
        whereArgs: [codeId],
        orderBy: 'order_index ASC',
      );

      final questions = qRows.map((r) => ExamCodeQuestion.fromMap(r)).toList();
      results.add(ExamCode.fromMap(cr, questions: questions));
    }
    return results;
  }

  // ==========================================
  // LEARNING OBJECTIVES
  // ==========================================

  Future<List<LearningObjective>> getLearningObjectives(String projectId) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseTables.tableLearningObjectives,
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'order_index ASC',
    );
    return rows.map((r) => LearningObjective.fromMap(r)).toList();
  }

  Future<void> saveLearningObjectives(String projectId, List<LearningObjective> objectives) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(
        DatabaseTables.tableLearningObjectives,
        where: 'project_id = ?',
        whereArgs: [projectId],
      );

      for (int i = 0; i < objectives.length; i++) {
        final obj = objectives[i].copyWith(projectId: projectId, orderIndex: i);
        await txn.insert(
          DatabaseTables.tableLearningObjectives,
          obj.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    });
    AppLogger.info('Saved ${objectives.length} LearningObjectives for project $projectId');
  }

  /// Imports structured LearningObjective records from a Teaching Suite lesson project (Section 15).
  Future<List<LearningObjective>> importObjectivesFromLessonProject({
    required String sourceLessonProjectId,
    required String targetAssessmentProjectId,
  }) async {
    final sourceObjs = await getLearningObjectives(sourceLessonProjectId);
    if (sourceObjs.isEmpty) return [];

    final imported = sourceObjs.map((o) {
      return o.copyWith(
        id: 'obj_${targetAssessmentProjectId}_${o.code}',
        projectId: targetAssessmentProjectId,
      );
    }).toList();

    await saveLearningObjectives(targetAssessmentProjectId, imported);
    AppLogger.info('Imported ${imported.length} LearningObjectives from lesson project $sourceLessonProjectId');
    return imported;
  }

  // ==========================================
  // QUESTION BANK
  // ==========================================

  /// Gets all questions available for this assessment project (from local set or linked set).
  Future<List<QuestionItem>> getQuestionBank(String projectId, {String? linkedLessonProjectId}) async {
    final db = await _db;
    final List<String> targetProjectIds = [projectId];
    if (linkedLessonProjectId != null && linkedLessonProjectId.isNotEmpty) {
      targetProjectIds.add(linkedLessonProjectId);
    }

    final placeholders = List.filled(targetProjectIds.length, '?').join(',');
    final setRows = await db.rawQuery(
      'SELECT id FROM ${DatabaseTables.tableQuestionSets} WHERE project_id IN ($placeholders)',
      targetProjectIds,
    );

    if (setRows.isEmpty) return [];

    final setIds = setRows.map((r) => r['id'] as String).toList();
    final setPlaceholders = List.filled(setIds.length, '?').join(',');

    final itemRows = await db.rawQuery(
      'SELECT * FROM ${DatabaseTables.tableQuestionItems} WHERE set_id IN ($setPlaceholders) ORDER BY order_index ASC',
      setIds,
    );

    return itemRows.map((r) => QuestionItem.fromMap(r)).toList();
  }

  /// Saves a single question into the assessment project's primary set.
  Future<void> saveQuestion(QuestionItem question, String projectId) async {
    final db = await _db;
    final setId = 'qs_$projectId';

    await db.transaction((txn) async {
      // Ensure question set exists
      await txn.insert(
        DatabaseTables.tableQuestionSets,
        {
          'id': setId,
          'project_id': projectId,
          'title': 'Ngân hàng câu hỏi đánh giá',
          'subject': 'Ngữ văn',
          'grade': '9',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      final existing = await txn.query(
        DatabaseTables.tableQuestionItems,
        where: 'id = ?',
        whereArgs: [question.id],
        limit: 1,
      );

      final questionMap = {
        'id': question.id,
        'set_id': setId,
        'type': question.type.name,
        'prompt': question.prompt,
        'choices_json': jsonEncode(question.choices),
        'correct_answer': question.correctAnswer,
        'explanation': question.explanation,
        'difficulty': question.difficulty.name,
        'objective_id': question.learningObjective,
        'order_index': question.orderIndex,
        'metadata_json': jsonEncode({'tags': question.tags}),
      };

      if (existing.isEmpty) {
        await txn.insert(
          DatabaseTables.tableQuestionItems,
          questionMap,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      } else {
        await txn.update(
          DatabaseTables.tableQuestionItems,
          questionMap,
          where: 'id = ?',
          whereArgs: [question.id],
        );
      }
    });
    AppLogger.info('Saved QuestionItem ${question.id} for project $projectId');
  }

  /// Deletes a question from the question bank.
  Future<void> deleteQuestion(String questionId) async {
    final db = await _db;
    await db.delete(
      DatabaseTables.tableQuestionItems,
      where: 'id = ?',
      whereArgs: [questionId],
    );
    AppLogger.info('Deleted QuestionItem $questionId');
  }
}
