import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_tables.dart';
import '../../../core/logging/app_logger.dart';
import '../domain/models/question_models.dart';
import '../domain/models/rubric_models.dart';
import '../domain/models/lesson_plan_document.dart';
import '../domain/models/worksheet_models.dart';
import '../domain/models/mini_assessment_model.dart';
import '../domain/models/learning_objective.dart';

/// SQLite persistence repository for Teaching Suite questions, sets, and rubrics.
class TeachingSuiteRepository {
  final AppDatabase? _appDatabase;
  final Database? _rawDb;

  TeachingSuiteRepository(AppDatabase appDatabase)
      : _appDatabase = appDatabase,
        _rawDb = null;

  TeachingSuiteRepository.withDb(Database db)
      : _appDatabase = null,
        _rawDb = db;

  Future<Database> get _db async => _rawDb ?? await _appDatabase!.database;

  // ==========================================
  // QUESTION SETS & ITEMS
  // ==========================================

  /// Saves or updates a QuestionSet and its QuestionItems safely without replacing parent.
  Future<void> saveQuestionSet(QuestionSet set) async {
    final db = await _db;
    await db.transaction((txn) async {
      final existing = await txn.query(
        DatabaseTables.tableQuestionSets,
        where: 'id = ?',
        whereArgs: [set.id],
        limit: 1,
      );
      final setMap = {
        'id': set.id,
        'project_id': set.projectId,
        'title': set.title,
        'subject': set.subject,
        'grade': set.grade,
        'created_at': set.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'metadata_json': jsonEncode({'item_count': set.items.length}),
      };

      if (existing.isEmpty) {
        await txn.insert(
          DatabaseTables.tableQuestionSets,
          setMap,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      } else {
        await txn.update(
          DatabaseTables.tableQuestionSets,
          setMap,
          where: 'id = ?',
          whereArgs: [set.id],
        );
      }

      // Refresh items in set
      await txn.delete(
        DatabaseTables.tableQuestionItems,
        where: 'set_id = ?',
        whereArgs: [set.id],
      );

      for (int i = 0; i < set.items.length; i++) {
        final item = set.items[i];
        await txn.insert(
          DatabaseTables.tableQuestionItems,
          {
            'id': item.id,
            'set_id': set.id,
            'type': item.type.name,
            'prompt': item.prompt,
            'choices_json': jsonEncode(item.choices),
            'correct_answer': item.correctAnswer,
            'explanation': item.explanation,
            'difficulty': item.difficulty.name,
            'objective_id': item.learningObjective,
            'order_index': i,
            'metadata_json': jsonEncode({'tags': item.tags}),
          },
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    });
    AppLogger.info('Saved QuestionSet: ${set.id} with ${set.items.length} items');
  }

  /// Retrieves all question sets for a project, including question items.
  Future<List<QuestionSet>> getQuestionSetsForProject(String projectId) async {
    final db = await _db;
    final setRows = await db.query(
      DatabaseTables.tableQuestionSets,
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'created_at DESC',
    );

    final List<QuestionSet> results = [];
    for (final row in setRows) {
      final setId = row['id'] as String;
      final itemRows = await db.query(
        DatabaseTables.tableQuestionItems,
        where: 'set_id = ?',
        whereArgs: [setId],
        orderBy: 'order_index ASC',
      );

      final items = itemRows.map((ir) => QuestionItem.fromMap(ir)).toList();
      results.add(QuestionSet.fromMap(row, items: items));
    }
    return results;
  }

  /// Retrieves a specific question set by ID with items.
  Future<QuestionSet?> getQuestionSet(String setId) async {
    final db = await _db;
    final setRows = await db.query(
      DatabaseTables.tableQuestionSets,
      where: 'id = ?',
      whereArgs: [setId],
      limit: 1,
    );
    if (setRows.isEmpty) return null;

    final itemRows = await db.query(
      DatabaseTables.tableQuestionItems,
      where: 'set_id = ?',
      whereArgs: [setId],
      orderBy: 'order_index ASC',
    );

    final items = itemRows.map((ir) => QuestionItem.fromMap(ir)).toList();
    return QuestionSet.fromMap(setRows.first, items: items);
  }

  /// Deletes a question set (cascades to items).
  Future<void> deleteQuestionSet(String setId) async {
    final db = await _db;
    await db.delete(
      DatabaseTables.tableQuestionSets,
      where: 'id = ?',
      whereArgs: [setId],
    );
    AppLogger.info('Deleted QuestionSet: $setId');
  }

  // ==========================================
  // RUBRICS
  // ==========================================

  /// Saves or updates a RubricModel safely without replacing parent.
  Future<void> saveRubric(RubricModel rubric) async {
    final db = await _db;
    await db.transaction((txn) async {
      final existing = await txn.query(
        DatabaseTables.tableRubrics,
        where: 'id = ?',
        whereArgs: [rubric.id],
        limit: 1,
      );
      final map = {
        'id': rubric.id,
        'project_id': rubric.projectId,
        'title': rubric.title,
        'criteria_json': jsonEncode(rubric.criteria.map((c) => c.toMap()).toList()),
        'total_weight': rubric.totalWeight,
        'created_at': rubric.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (existing.isEmpty) {
        await txn.insert(
          DatabaseTables.tableRubrics,
          map,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      } else {
        await txn.update(
          DatabaseTables.tableRubrics,
          map,
          where: 'id = ?',
          whereArgs: [rubric.id],
        );
      }
    });
    AppLogger.info('Saved Rubric: ${rubric.id} (total weight: ${rubric.totalWeight}%)');
  }

  /// Retrieves all rubrics for a project.
  Future<List<RubricModel>> getRubricsForProject(String projectId) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseTables.tableRubrics,
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => RubricModel.fromMap(r)).toList();
  }

  /// Retrieves a specific rubric by ID.
  Future<RubricModel?> getRubric(String rubricId) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseTables.tableRubrics,
      where: 'id = ?',
      whereArgs: [rubricId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return RubricModel.fromMap(rows.first);
  }

  /// Deletes a rubric by ID.
  Future<void> deleteRubric(String rubricId) async {
    final db = await _db;
    await db.delete(
      DatabaseTables.tableRubrics,
      where: 'id = ?',
      whereArgs: [rubricId],
    );
    AppLogger.info('Deleted Rubric: $rubricId');
  }

  // ==========================================
  // LESSON PLAN DRAFTS
  // ==========================================

  /// Saves or updates a LessonPlanDocument draft for a project safely without replacing parent.
  Future<void> saveLessonPlanDraft(
    String projectId,
    LessonPlanDocument plan, {
    String? promptVersion,
  }) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    final draftId = 'draft_$projectId';
    await db.transaction((txn) async {
      final existing = await txn.query(
        DatabaseTables.tableLessonPlanDrafts,
        where: 'id = ?',
        whereArgs: [draftId],
        limit: 1,
      );
      final map = {
        'id': draftId,
        'project_id': projectId,
        'document_json': plan.toJson(),
        'prompt_version': promptVersion ?? '5512_v1',
        'created_at': existing.isEmpty ? now : (existing.first['created_at'] as String? ?? now),
        'updated_at': now,
      };
      if (existing.isEmpty) {
        await txn.insert(
          DatabaseTables.tableLessonPlanDrafts,
          map,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      } else {
        await txn.update(
          DatabaseTables.tableLessonPlanDrafts,
          map,
          where: 'id = ?',
          whereArgs: [draftId],
        );
      }
    });
    AppLogger.info('Saved LessonPlanDraft for project: $projectId');
  }

  /// Retrieves the LessonPlanDocument draft for a project.
  Future<LessonPlanDocument?> getLessonPlanDraft(String projectId) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseTables.tableLessonPlanDrafts,
      where: 'project_id = ?',
      whereArgs: [projectId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final jsonStr = rows.first['document_json'] as String?;
    if (jsonStr == null || jsonStr.isEmpty) return null;
    return LessonPlanDocument.fromJson(jsonStr);
  }

  /// Deletes the LessonPlanDocument draft for a project.
  Future<void> deleteLessonPlanDraft(String projectId) async {
    final db = await _db;
    await db.delete(
      DatabaseTables.tableLessonPlanDrafts,
      where: 'project_id = ?',
      whereArgs: [projectId],
    );
    AppLogger.info('Deleted LessonPlanDraft for project: $projectId');
  }

  // ==========================================
  // WORKSHEETS & TASKS
  // ==========================================

  /// Saves or updates a WorksheetModel and its tasks.
  /// Can be called as saveWorksheet(worksheet) or saveWorksheet(projectId, worksheet).
  Future<void> saveWorksheet(dynamic arg1, [WorksheetModel? arg2]) async {
    final WorksheetModel worksheet;
    final String targetProjectId;
    if (arg1 is WorksheetModel) {
      worksheet = arg1;
      targetProjectId = arg2 != null ? (arg2.projectId ?? '') : (worksheet.projectId ?? '');
    } else {
      targetProjectId = arg1 as String;
      worksheet = arg2!;
    }
    final projectId = targetProjectId.isNotEmpty ? targetProjectId : (worksheet.projectId ?? '');

    final db = await _db;
    await db.transaction((txn) async {
      final existing = await txn.query(
        DatabaseTables.tableWorksheets,
        where: 'id = ?',
        whereArgs: [worksheet.id],
        limit: 1,
      );
      final wsMap = {
        'id': worksheet.id,
        'project_id': projectId,
        'title': worksheet.title,
        'preset': worksheet.preset.name,
        'duration': worksheet.durationMinutes,
        'teacher_notes': worksheet.teacherNotes,
        'created_at': worksheet.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (existing.isEmpty) {
        await txn.insert(
          DatabaseTables.tableWorksheets,
          wsMap,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      } else {
        await txn.update(
          DatabaseTables.tableWorksheets,
          wsMap,
          where: 'id = ?',
          whereArgs: [worksheet.id],
        );
      }

      // Replace tasks for this worksheet
      await txn.delete(
        DatabaseTables.tableWorksheetTasks,
        where: 'worksheet_id = ?',
        whereArgs: [worksheet.id],
      );

      for (int i = 0; i < worksheet.tasks.length; i++) {
        final t = worksheet.tasks[i];
        await txn.insert(
          DatabaseTables.tableWorksheetTasks,
          {
            'id': t.id,
            'worksheet_id': worksheet.id,
            'instruction': t.instruction,
            'content': t.content,
            'task_type': t.taskType.name,
            'points': t.points,
            'order_index': i,
            'answer_hint': t.hint,
          },
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    });
    AppLogger.info('Saved Worksheet: ${worksheet.id} (${worksheet.tasks.length} tasks) for project: $projectId');
  }

  /// Retrieves the latest WorksheetModel for a project.
  Future<WorksheetModel?> getWorksheetForProject(String projectId) async {
    final db = await _db;
    final wsRows = await db.query(
      DatabaseTables.tableWorksheets,
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (wsRows.isEmpty) return null;

    final wsRow = wsRows.first;
    final wsId = wsRow['id'] as String;

    final taskRows = await db.query(
      DatabaseTables.tableWorksheetTasks,
      where: 'worksheet_id = ?',
      whereArgs: [wsId],
      orderBy: 'order_index ASC',
    );

    final tasks = taskRows.map((tr) => WorksheetTask.fromMap(tr)).toList();
    return WorksheetModel.fromMap(wsRow, tasks: tasks);
  }

  /// Alias for getWorksheetForProject.
  Future<WorksheetModel?> getWorksheet(String projectId) => getWorksheetForProject(projectId);

  /// Deletes a worksheet by ID (cascades to tasks).
  Future<void> deleteWorksheet(String worksheetId) async {
    final db = await _db;
    await db.delete(
      DatabaseTables.tableWorksheets,
      where: 'id = ?',
      whereArgs: [worksheetId],
    );
    AppLogger.info('Deleted Worksheet: $worksheetId');
  }

  // ==========================================
  // MINI ASSESSMENTS
  // ==========================================

  /// Saves a structured MiniAssessment safely without replacing parent.
  Future<void> saveMiniAssessment(MiniAssessment assessment) async {
    final db = await _db;
    await db.transaction((txn) async {
      final existing = await txn.query(
        DatabaseTables.tableMiniAssessments,
        where: 'id = ?',
        whereArgs: [assessment.id],
        limit: 1,
      );
      final maMap = {
        'id': assessment.id,
        'project_id': assessment.projectId,
        'source_question_set_id': assessment.sourceQuestionSetId,
        'title': assessment.title,
        'duration': assessment.durationMinutes,
        'created_at': assessment.createdAt.toIso8601String(),
      };

      if (existing.isEmpty) {
        await txn.insert(
          DatabaseTables.tableMiniAssessments,
          maMap,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      } else {
        await txn.update(
          DatabaseTables.tableMiniAssessments,
          maMap,
          where: 'id = ?',
          whereArgs: [assessment.id],
        );
      }

      await txn.delete(
        DatabaseTables.tableMiniAssessmentItems,
        where: 'mini_assessment_id = ?',
        whereArgs: [assessment.id],
      );

      final orderList = assessment.questionOrder.isNotEmpty
          ? assessment.questionOrder
          : assessment.questions.map((q) => q.id).toList();

      for (int i = 0; i < orderList.length; i++) {
        final qId = orderList[i];
        final q = assessment.questions.cast<QuestionItem?>().firstWhere(
              (item) => item?.id == qId,
              orElse: () => null,
            );
        await txn.insert(
          DatabaseTables.tableMiniAssessmentItems,
          {
            'id': 'mai_${assessment.id}_$i',
            'mini_assessment_id': assessment.id,
            'question_id': qId,
            'order_index': i,
            'snapshot_json': q != null ? jsonEncode(q.toMap()) : null,
          },
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    });
    AppLogger.info('Saved MiniAssessment: ${assessment.id} (${assessment.questionIds.length} questions)');
  }

  /// Retrieves all mini assessments for a project.
  Future<List<MiniAssessment>> getMiniAssessmentsForProject(String projectId) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseTables.tableMiniAssessments,
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'created_at DESC',
    );

    final List<MiniAssessment> results = [];
    for (final r in rows) {
      final aId = r['id'] as String;
      final itemRows = await db.query(
        DatabaseTables.tableMiniAssessmentItems,
        where: 'mini_assessment_id = ?',
        whereArgs: [aId],
        orderBy: 'order_index ASC',
      );

      final List<QuestionItem> questions = [];
      final List<String> questionIds = [];
      for (final ir in itemRows) {
        final qId = ir['question_id'] as String;
        questionIds.add(qId);
        final snap = ir['snapshot_json'] as String?;
        if (snap != null && snap.isNotEmpty) {
          try {
            questions.add(QuestionItem.fromMap(jsonDecode(snap) as Map<String, dynamic>));
          } catch (_) {}
        }
      }
      results.add(MiniAssessment.fromMap(
        r,
        questions: questions,
        questionOrder: questionIds,
      ));
    }
    return results;
  }

  /// Alias for getMiniAssessmentsForProject.
  Future<List<MiniAssessment>> listMiniAssessments(String projectId) => getMiniAssessmentsForProject(projectId);

  /// Deletes a mini assessment.
  Future<void> deleteMiniAssessment(String assessmentId) async {
    final db = await _db;
    await db.delete(
      DatabaseTables.tableMiniAssessments,
      where: 'id = ?',
      whereArgs: [assessmentId],
    );
    AppLogger.info('Deleted MiniAssessment: $assessmentId');
  }

  // ==========================================
  // LEARNING OBJECTIVES
  // ==========================================

  /// Saves learning objectives for a project safely without replacing parent.
  Future<void> saveLearningObjectives(String projectId, List<LearningObjective> objectives) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(
        DatabaseTables.tableLearningObjectives,
        where: 'project_id = ?',
        whereArgs: [projectId],
      );

      for (int i = 0; i < objectives.length; i++) {
        final obj = objectives[i];
        await txn.insert(
          DatabaseTables.tableLearningObjectives,
          {
            'id': obj.id,
            'project_id': projectId,
            'code': obj.code,
            'description': obj.description,
            'category': obj.category,
            'order_index': i,
          },
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    });
    AppLogger.info('Saved ${objectives.length} LearningObjectives for project: $projectId');
  }

  /// Retrieves learning objectives for a project.
  Future<List<LearningObjective>> getLearningObjectivesForProject(String projectId) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseTables.tableLearningObjectives,
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'order_index ASC',
    );
    return rows.map((r) => LearningObjective.fromMap(r)).toList();
  }
}

