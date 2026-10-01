import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/database/database_tables.dart';
import 'package:nguyendu_tool/core/errors/app_exceptions.dart';
import 'package:nguyendu_tool/core/projects/data/workspace_project_repository.dart';
import 'package:nguyendu_tool/core/projects/domain/project_type.dart';
import 'package:nguyendu_tool/core/projects/domain/workspace_project.dart';
import 'package:nguyendu_tool/features/assessment_studio/data/assessment_repository.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/assessment_project_data.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/exam_matrix.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/exam_paper.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/exam_question_snapshot.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/exam_specification.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/question_choice.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/services/exam_code_engine.dart';
import 'package:nguyendu_tool/features/teaching_suite/data/teaching_suite_repository.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/lesson_plan_document.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/question_models.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/rubric_models.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/worksheet_models.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide DatabaseException;

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Phase 7R.3 Complete Parent-Child Data Integrity Hardening Fixtures', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('phase7r3_tests_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    Future<Database> openRealDatabase(String dbPath) async {
      final db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 9,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON;');
          },
          onCreate: (db, version) async {
            for (final ddl in DatabaseTables.allCreationStatements) {
              await db.execute(ddl);
            }
          },
        ),
      );
      return db;
    }

    ExamQuestionSnapshot createDummyQuestion(String qId, int order) {
      return ExamQuestionSnapshot(
        questionId: qId,
        score: 0.25,
        type: QuestionType.multipleChoice,
        prompt: 'Question $order prompt for $qId?',
        choices: const [
          QuestionChoice(id: 'c1', text: 'Choice A'),
          QuestionChoice(id: 'c2', text: 'Choice B'),
          QuestionChoice(id: 'c3', text: 'Choice C'),
          QuestionChoice(id: 'c4', text: 'Choice D'),
        ],
        correctChoiceId: 'c1',
        correctAnswerText: 'A',
        explanation: 'Explanation for $qId',
        difficulty: QuestionDifficulty.thongHieu,
        objectiveId: 'obj_1',
      );
    }

    // ==============================================================
    // 1. PROJECT RENAME CASCADE TEST (Sections 1 & 3)
    // ==============================================================
    test('Fixture 1: Project rename must NOT wipe out child specifications, matrix, master, and codes', () async {
      final dbPath = p.join(tempDir.path, 'test_project_cascade.db');
      final db = await openRealDatabase(dbPath);
      final repo = AssessmentRepository.withDb(db);

      // 1. Create project A
      const projectId = 'proj_alpha';
      final project = AssessmentProjectData(
        id: projectId,
        name: 'Đề thi Văn Học Kỳ 1 - Lớp 9',
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
      );
      await repo.saveProjectData(project);

      // 2. Create specification
      const specId = 'spec_alpha';
      final spec = ExamSpecification(
        id: specId,
        projectId: projectId,
        title: 'Đặc tả Đề thi Văn HK1',
        subject: 'Ngữ văn',
        grade: '9',
        durationMinutes: 45,
        totalScore: 10.0,
        questionCount: 10,
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
      );
      await repo.saveSpecification(spec);

      // 3. Save matrix with 12 cells
      final matrixCells = List.generate(
        12,
        (i) => ExamMatrixCell(
          id: 'cell_$i',
          specificationId: specId,
          objectiveId: 'obj_${i % 3}',
          difficulty: QuestionDifficulty.thongHieu,
          questionCount: 1,
          scorePerQuestion: 0.25,
        ),
      );
      await repo.saveMatrix(ExamMatrix(specificationId: specId, cells: matrixCells));

      // 4. Create master exam & finalize
      const paperId = 'paper_p1';
      final questions = List.generate(10, (i) => createDummyQuestion('q_${i + 1}', i + 1));
      final master = ExamPaper(
        id: paperId,
        assessmentProjectId: projectId,
        specificationId: specId,
        title: 'Master Exam Paper',
        examCode: 'MASTER',
        durationMinutes: 45,
        totalScore: 2.5,
        revisionNumber: 1,
        isFinalized: true,
        createdAt: DateTime(2026, 9, 1),
        finalizedAt: DateTime(2026, 9, 1),
        questions: questions,
      );
      await repo.saveExamPaper(master);

      // 5. Generate and persist 4 codes (101, 102, 103, 104)
      const engine = ExamCodeEngine();
      final codeResult = engine.generateCodes(masterPaper: master, numberOfCodes: 4, startingCode: 101);
      await repo.saveExamCodes(codeResult.codes);

      // Verify baseline counts before rename
      expect((await db.query(DatabaseTables.tableWorkspaceProjects)).length, 1);
      expect((await db.query(DatabaseTables.tableExamSpecifications)).length, 1);
      expect((await db.query(DatabaseTables.tableExamMatrixCells)).length, 12);
      expect((await db.query(DatabaseTables.tableExamPapers)).length, 1);
      expect((await db.query(DatabaseTables.tableExamCodes)).length, 4);
      expect((await db.query(DatabaseTables.tableExamCodeQuestions)).length, 40);

      // 8. Rename project A and save again
      final renamedProject = project.copyWith(
        name: 'Đề thi Văn Học Kỳ 1 - ĐÃ ĐỔI TÊN',
        updatedAt: DateTime(2026, 9, 2),
      );
      await repo.saveProjectData(renamedProject);

      // 10. Check that all children survived project rename!
      final specsAfter = await db.query(DatabaseTables.tableExamSpecifications);
      final cellsAfter = await db.query(DatabaseTables.tableExamMatrixCells);
      final papersAfter = await db.query(DatabaseTables.tableExamPapers);
      final codesAfter = await db.query(DatabaseTables.tableExamCodes);
      final codeQuestionsAfter = await db.query(DatabaseTables.tableExamCodeQuestions);

      expect(specsAfter.length, 1, reason: 'Specifications must survive project rename');
      expect(cellsAfter.length, 12, reason: 'Matrix cells must survive project rename');
      expect(papersAfter.length, 1, reason: 'Master papers must survive project rename');
      expect(codesAfter.length, 4, reason: 'Exam codes must survive project rename');
      expect(codeQuestionsAfter.length, 40, reason: 'Exam code questions must survive project rename');

      // Check foreign key check returns 0 errors
      final fkCheck = await db.rawQuery('PRAGMA foreign_key_check;');
      expect(fkCheck, isEmpty);

      await db.close();
    });

    // ==============================================================
    // 2. SPECIFICATION IDEMPOTENT SAVE (Sections 2 & 4)
    // ==============================================================
    test('Fixture 2: Idempotent saveSpecification must NOT wipe out matrix cells or cascade delete', () async {
      final dbPath = p.join(tempDir.path, 'test_spec_cascade.db');
      final db = await openRealDatabase(dbPath);
      final repo = AssessmentRepository.withDb(db);

      const projectId = 'proj_spec_test';
      const specId = 'spec_test_1';
      final project = AssessmentProjectData(
        id: projectId,
        name: 'Project For Spec Test',
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
      );
      await repo.saveProjectData(project);

      final spec = ExamSpecification(
        id: specId,
        projectId: projectId,
        title: 'Spec Title',
        subject: 'Ngữ văn',
        grade: '9',
        durationMinutes: 45,
        totalScore: 10.0,
        questionCount: 10,
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
      );
      await repo.saveSpecification(spec);

      // Save 12 matrix cells
      final matrixCells = List.generate(
        12,
        (i) => ExamMatrixCell(
          id: 'cell_$i',
          specificationId: specId,
          objectiveId: 'obj_${i % 3}',
          difficulty: QuestionDifficulty.thongHieu,
          questionCount: 1,
          scorePerQuestion: 0.25,
        ),
      );
      await repo.saveMatrix(ExamMatrix(specificationId: specId, cells: matrixCells));

      // Verify matrix cells exist
      expect((await db.query(DatabaseTables.tableExamMatrixCells)).length, 12);

      // Idempotently re-save specification
      await repo.saveSpecification(spec);

      final cellsAfter = await db.query(DatabaseTables.tableExamMatrixCells);
      expect(cellsAfter.length, 12, reason: 'Matrix cells must survive idempotent specification save');

      await db.close();
    });

    // ==============================================================
    // 3. FINALIZED BLUEPRINT PROTECTION (Sections 2, 4, 9)
    // ==============================================================
    test('Fixture 3: Mutating protected blueprint fields on finalized exam specification is rejected', () async {
      final dbPath = p.join(tempDir.path, 'test_spec_protection.db');
      final db = await openRealDatabase(dbPath);
      final repo = AssessmentRepository.withDb(db);

      const projectId = 'proj_prot';
      const specId = 'spec_prot';
      const paperId = 'paper_prot';

      await repo.saveProjectData(AssessmentProjectData(id: projectId, name: 'Prot Test', createdAt: DateTime.now(), updatedAt: DateTime.now()));
      final spec = ExamSpecification(
        id: specId,
        projectId: projectId,
        title: 'Original Spec',
        durationMinutes: 45,
        totalScore: 10.0,
        questionCount: 10,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.saveSpecification(spec);

      final master = ExamPaper(
        id: paperId,
        assessmentProjectId: projectId,
        specificationId: specId,
        title: 'Master',
        durationMinutes: 45,
        totalScore: 10.0,
        isFinalized: true,
        createdAt: DateTime.now(),
        questions: List.generate(10, (i) => createDummyQuestion('q_$i', i + 1)),
      );
      await repo.saveExamPaper(master);

      // Updating non-protected field like title succeeds
      final specWithNewTitle = spec.copyWith(title: 'Updated Spec Title');
      await repo.saveSpecification(specWithNewTitle);
      final loadedSpec = await repo.getSpecification(projectId);
      expect(loadedSpec!.title, 'Updated Spec Title');

      // Attempting to change totalScore on finalized spec must throw FinalizedExamImmutableException
      final specWithBadScore = spec.copyWith(totalScore: 20.0);
      await expectLater(
        repo.saveSpecification(specWithBadScore),
        throwsA(isA<FinalizedExamImmutableException>()),
      );

      // Attempting to change durationMinutes on finalized spec must throw FinalizedExamImmutableException
      final specWithBadDuration = spec.copyWith(durationMinutes: 90);
      await expectLater(
        repo.saveSpecification(specWithBadDuration),
        throwsA(isA<FinalizedExamImmutableException>()),
      );

      // Attempting to change questionCount on finalized spec must throw FinalizedExamImmutableException
      final specWithBadCount = spec.copyWith(questionCount: 50);
      await expectLater(
        repo.saveSpecification(specWithBadCount),
        throwsA(isA<FinalizedExamImmutableException>()),
      );

      await db.close();
    });

    // ==============================================================
    // 4. MATRIX MUTATION PROTECTION ON FINALIZED EXAM (Sections 2 & 9)
    // ==============================================================
    test('Fixture 4: Mutating matrix cells on finalized exam specification is rejected', () async {
      final dbPath = p.join(tempDir.path, 'test_matrix_protection.db');
      final db = await openRealDatabase(dbPath);
      final repo = AssessmentRepository.withDb(db);

      const projectId = 'proj_mat_prot';
      const specId = 'spec_mat_prot';
      const paperId = 'paper_mat_prot';

      await repo.saveProjectData(AssessmentProjectData(id: projectId, name: 'Mat Prot', createdAt: DateTime.now(), updatedAt: DateTime.now()));
      final spec = ExamSpecification(id: specId, projectId: projectId, title: 'Spec', createdAt: DateTime.now(), updatedAt: DateTime.now());
      await repo.saveSpecification(spec);

      final cells = [
        const ExamMatrixCell(id: 'c1', specificationId: specId, objectiveId: 'obj_1', difficulty: QuestionDifficulty.thongHieu, questionCount: 5, scorePerQuestion: 0.5),
        const ExamMatrixCell(id: 'c2', specificationId: specId, objectiveId: 'obj_2', difficulty: QuestionDifficulty.vanDung, questionCount: 5, scorePerQuestion: 0.5),
      ];
      await repo.saveMatrix(ExamMatrix(specificationId: specId, cells: cells));

      final master = ExamPaper(
        id: paperId,
        assessmentProjectId: projectId,
        specificationId: specId,
        title: 'Master',
        isFinalized: true,
        createdAt: DateTime.now(),
        questions: List.generate(10, (i) => createDummyQuestion('q_$i', i + 1)),
      );
      await repo.saveExamPaper(master);

      // Re-saving identical matrix on finalized paper succeeds idempotently
      await repo.saveMatrix(ExamMatrix(specificationId: specId, cells: cells));
      expect((await db.query(DatabaseTables.tableExamMatrixCells)).length, 2);

      // Mutating cells on finalized paper throws FinalizedExamImmutableException
      final mutatedCells = [
        const ExamMatrixCell(id: 'c1', specificationId: specId, objectiveId: 'obj_1', difficulty: QuestionDifficulty.thongHieu, questionCount: 8, scorePerQuestion: 0.5),
      ];
      await expectLater(
        repo.saveMatrix(ExamMatrix(specificationId: specId, cells: mutatedCells)),
        throwsA(isA<FinalizedExamImmutableException>()),
      );

      await db.close();
    });

    // ==============================================================
    // 5. WORKSPACE PROJECT REPO AUDIT & DELETION SAFETY (Sections 6 & 8)
    // ==============================================================
    test('Fixture 5: WorkspaceProjectRepository saveProject, archiveProject, and delete safety', () async {
      final dbPath = p.join(tempDir.path, 'test_ws_repo.db');
      final db = await openRealDatabase(dbPath);
      final wsRepo = WorkspaceProjectRepository.withDb(db);

      const projId = 'proj_ws_1';
      final project = WorkspaceProject(
        id: projId,
        name: 'Workspace Project 1',
        type: ProjectType.assessment,
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await wsRepo.saveProject(project);

      // Update name safely
      final updatedProject = project.copyWith(name: 'Updated Project 1');
      await wsRepo.saveProject(updatedProject);
      final fetched = await wsRepo.getProject(projId);
      expect(fetched!.name, 'Updated Project 1');

      // Add finalized exam to project
      final master = ExamPaper(
        id: 'paper_del_safe',
        assessmentProjectId: projId,
        specificationId: 'spec_any',
        title: 'Master Paper',
        isFinalized: true,
        createdAt: DateTime.now(),
      );
      // Insert master directly
      await db.insert(DatabaseTables.tableExamPapers, {
        'id': master.id,
        'project_id': projId,
        'specification_id': master.specificationId,
        'title': master.title,
        'is_finalized': 1,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Verify hasFinalizedExams
      expect(await wsRepo.hasFinalizedExams(projId), isTrue);

      // Attempting unforced delete must throw ProjectHasFinalizedExamsException
      await expectLater(
        wsRepo.deleteProject(projId, force: false),
        throwsA(isA<ProjectHasFinalizedExamsException>()),
      );

      // Archive project sets status = archived without deleting
      await wsRepo.archiveProject(projId);
      final archived = await wsRepo.getProject(projId);
      expect(archived!.status, 'archived');
      expect((await db.query(DatabaseTables.tableExamPapers)).length, 1);

      // Explicit forced delete succeeds
      await wsRepo.deleteProject(projId, force: true);
      expect(await wsRepo.getProject(projId), isNull);

      await db.close();
    });

    // ==============================================================
    // 6. TEACHING SUITE REPOSITORY AUDIT (Sections 5 & 6)
    // ==============================================================
    test('Fixture 6: TeachingSuiteRepository saveQuestionSet, saveRubric, saveWorksheet without cascade', () async {
      final dbPath = p.join(tempDir.path, 'test_ts_repo.db');
      final db = await openRealDatabase(dbPath);
      final tsRepo = TeachingSuiteRepository.withDb(db);
      final wsRepo = WorkspaceProjectRepository.withDb(db);

      const projId = 'proj_ts_1';
      await wsRepo.saveProject(WorkspaceProject(
        id: projId,
        name: 'Teaching Project',
        type: ProjectType.lesson,
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // 1. QuestionSet & QuestionItems
      final qSet = QuestionSet(
        id: 'qs_1',
        projectId: projId,
        title: 'Original Question Set',
        subject: 'Ngữ văn',
        grade: '9',
        items: const [
          QuestionItem(id: 'qi_1', type: QuestionType.multipleChoice, prompt: 'Item 1', correctAnswer: 'A'),
          QuestionItem(id: 'qi_2', type: QuestionType.multipleChoice, prompt: 'Item 2', correctAnswer: 'B'),
        ],
        createdAt: DateTime.now(),
      );
      await tsRepo.saveQuestionSet(qSet);
      expect((await db.query(DatabaseTables.tableQuestionSets)).length, 1);
      expect((await db.query(DatabaseTables.tableQuestionItems)).length, 2);

      // Re-save question set with updated title
      await tsRepo.saveQuestionSet(qSet.copyWith(title: 'Updated Set Title'));
      final loadedSets = await tsRepo.getQuestionSetsForProject(projId);
      expect(loadedSets.first.title, 'Updated Set Title');
      expect((await db.query(DatabaseTables.tableQuestionItems)).length, 2);

      // 2. Rubric
      final rubric = RubricModel(
        id: 'rub_1',
        projectId: projId,
        title: 'Rubric 1',
        criteria: const [RubricCriterion(id: 'rc_1', name: 'Crit 1', weight: 100, levels: [])],
        createdAt: DateTime.now(),
      );
      await tsRepo.saveRubric(rubric);
      await tsRepo.saveRubric(rubric.copyWith(title: 'Updated Rubric'));
      final rubrics = await tsRepo.getRubricsForProject(projId);
      expect(rubrics.first.title, 'Updated Rubric');

      // 3. Worksheet
      final worksheet = WorksheetModel(
        id: 'ws_1',
        projectId: projId,
        title: 'Worksheet 1',
        tasks: const [
          WorksheetTask(id: 'wt_1', instruction: 'Task 1', content: 'Content 1'),
        ],
        createdAt: DateTime.now(),
      );
      await tsRepo.saveWorksheet(projId, worksheet);
      await tsRepo.saveWorksheet(projId, worksheet.copyWith(title: 'Updated Worksheet'));
      final loadedWs = await tsRepo.getWorksheet(projId);
      expect(loadedWs!.title, 'Updated Worksheet');

      await db.close();
    });

    // ==============================================================
    // 7. REAL DATABASE SCHEMA VERIFICATION (Section 10)
    // ==============================================================
    test('Fixture 7: SQLite schema and PRAGMA integrity verification', () async {
      final dbPath = p.join(tempDir.path, 'test_integrity.db');
      final db = await openRealDatabase(dbPath);

      // Check foreign_keys = 1
      final fkPragma = await db.rawQuery('PRAGMA foreign_keys;');
      expect(fkPragma.first.values.first, equals(1));

      // Check integrity_check = ok
      final integrityCheck = await db.rawQuery('PRAGMA integrity_check;');
      expect(integrityCheck.first.values.first, equals('ok'));

      // Check foreign_key_check is empty
      final fkCheck = await db.rawQuery('PRAGMA foreign_key_check;');
      expect(fkCheck, isEmpty);

      await db.close();
    });

    // ==============================================================
    // 8. MULTI-PROJECT END-TO-END (Section 11)
    // ==============================================================
    test('Fixture 8: Multi-Project E2E with shared questions, rename, metadata update, and DB restart', () async {
      final dbPath = p.join(tempDir.path, 'test_multi_project.db');
      var db = await openRealDatabase(dbPath);
      var repo = AssessmentRepository.withDb(db);

      const projA = 'proj_A';
      const projB = 'proj_B';
      const specA = 'spec_A';
      const specB = 'spec_B';
      const paperA = 'paper_A';
      const paperB = 'paper_B';

      // 1. Save projects & specifications
      await repo.saveProjectData(AssessmentProjectData(id: projA, name: 'Project A', createdAt: DateTime.now(), updatedAt: DateTime.now()));
      await repo.saveProjectData(AssessmentProjectData(id: projB, name: 'Project B', createdAt: DateTime.now(), updatedAt: DateTime.now()));

      await repo.saveSpecification(ExamSpecification(id: specA, projectId: projA, title: 'Spec A', createdAt: DateTime.now(), updatedAt: DateTime.now()));
      await repo.saveSpecification(ExamSpecification(id: specB, projectId: projB, title: 'Spec B', createdAt: DateTime.now(), updatedAt: DateTime.now()));

      // 2. Create 20 questions each, sharing 5 question IDs
      final questionsA = List.generate(20, (i) => createDummyQuestion('shared_q_${i + 1}', i + 1));
      final questionsB = [
        ...List.generate(5, (i) => createDummyQuestion('shared_q_${i + 1}', i + 1)), // Shared 5 questions
        ...List.generate(15, (i) => createDummyQuestion('unique_b_${i + 1}', i + 6)),
      ];

      final masterA = ExamPaper(id: paperA, assessmentProjectId: projA, specificationId: specA, title: 'Master A', isFinalized: true, createdAt: DateTime.now(), questions: questionsA);
      final masterB = ExamPaper(id: paperB, assessmentProjectId: projB, specificationId: specB, title: 'Master B', isFinalized: true, createdAt: DateTime.now(), questions: questionsB);

      await repo.saveExamPaper(masterA);
      await repo.saveExamPaper(masterB);

      // 3. Generate 4 codes for each project (101, 102, 103, 104)
      const engine = ExamCodeEngine();
      final codesA = engine.generateCodes(masterPaper: masterA, numberOfCodes: 4, startingCode: 101);
      final codesB = engine.generateCodes(masterPaper: masterB, numberOfCodes: 4, startingCode: 101);

      await repo.saveExamCodes(codesA.codes);
      await repo.saveExamCodes(codesB.codes);

      // Verify baseline: 2 projects, 2 specs, 2 papers, 8 codes, 160 code questions
      expect((await db.query(DatabaseTables.tableWorkspaceProjects)).length, 2);
      expect((await db.query(DatabaseTables.tableExamSpecifications)).length, 2);
      expect((await db.query(DatabaseTables.tableExamPapers)).length, 2);
      expect((await db.query(DatabaseTables.tableExamCodes)).length, 8);
      expect((await db.query(DatabaseTables.tableExamCodeQuestions)).length, 160);

      // 4. Perform non-destructive mutations:
      // Rename A
      await repo.saveProjectData(AssessmentProjectData(id: projA, name: 'Project A RENAMED', createdAt: DateTime.now(), updatedAt: DateTime.now()));
      // Update B metadata
      await repo.saveProjectData(AssessmentProjectData(id: projB, name: 'Project B METADATA UPDATED', createdAt: DateTime.now(), updatedAt: DateTime.now()));
      // Save spec A without changes
      await repo.saveSpecification(ExamSpecification(id: specA, projectId: projA, title: 'Spec A', createdAt: DateTime.now(), updatedAt: DateTime.now()));

      // 5. Restart DB: close and reopen
      await db.close();
      db = await openRealDatabase(dbPath);
      repo = AssessmentRepository.withDb(db);

      // Verify all 160 records and parents survive restart
      expect((await db.query(DatabaseTables.tableWorkspaceProjects)).length, 2);
      expect((await db.query(DatabaseTables.tableExamSpecifications)).length, 2);
      expect((await db.query(DatabaseTables.tableExamPapers)).length, 2);
      expect((await db.query(DatabaseTables.tableExamCodes)).length, 8);
      expect((await db.query(DatabaseTables.tableExamCodeQuestions)).length, 160);

      final fkCheck = await db.rawQuery('PRAGMA foreign_key_check;');
      expect(fkCheck, isEmpty);

      await db.close();
    });

    // ==============================================================
    // 9. HISTORICAL DATA PRESERVATION (Section 12)
    // ==============================================================
    test('Fixture 9: Historical Teaching Suite & Assessment Studio data preserved across operations', () async {
      final dbPath = p.join(tempDir.path, 'test_hist_pres.db');
      final db = await openRealDatabase(dbPath);
      final repo = AssessmentRepository.withDb(db);
      final tsRepo = TeachingSuiteRepository.withDb(db);
      final wsRepo = WorkspaceProjectRepository.withDb(db);

      const projId = 'proj_hist';
      await wsRepo.saveProject(WorkspaceProject(id: projId, name: 'Hist Project', type: ProjectType.assessment, status: 'active', createdAt: DateTime.now(), updatedAt: DateTime.now()));

      // Seed data in multiple tables
      await tsRepo.saveLessonPlanDraft(projId, const LessonPlanDocument(title: 'Plan Draft', grade: '9', subject: 'Văn'));
      await tsRepo.saveRubric(RubricModel(id: 'rub_h', projectId: projId, title: 'Rubric H', criteria: [], createdAt: DateTime.now()));
      await tsRepo.saveWorksheet(projId, WorksheetModel(id: 'ws_h', projectId: projId, title: 'Worksheet H', tasks: [], createdAt: DateTime.now()));
      await repo.saveSpecification(ExamSpecification(id: 'spec_h', projectId: projId, title: 'Spec H', createdAt: DateTime.now(), updatedAt: DateTime.now()));

      // Perform project update
      await wsRepo.saveProject(WorkspaceProject(id: projId, name: 'Hist Project RENAMED', type: ProjectType.assessment, status: 'active', createdAt: DateTime.now(), updatedAt: DateTime.now()));

      // Verify all tables retain records
      expect((await db.query(DatabaseTables.tableLessonPlanDrafts)).length, 1);
      expect((await db.query(DatabaseTables.tableRubrics)).length, 1);
      expect((await db.query(DatabaseTables.tableWorksheets)).length, 1);
      expect((await db.query(DatabaseTables.tableExamSpecifications)).length, 1);

      await db.close();
    });

    // ==============================================================
    // 10. TRANSACTION FAILURE & ROLLBACK (Section 13)
    // ==============================================================
    test('Fixture 10: Mid-transaction failure leaves existing data completely intact', () async {
      final dbPath = p.join(tempDir.path, 'test_rollback.db');
      final db = await openRealDatabase(dbPath);
      final repo = AssessmentRepository.withDb(db);

      const projId = 'proj_rb';
      await repo.saveProjectData(AssessmentProjectData(id: projId, name: 'Project Rollback', createdAt: DateTime.now(), updatedAt: DateTime.now()));

      // Attempt an atomic operation that intentionally fails mid-transaction
      try {
        await db.transaction((txn) async {
          await txn.update(
            DatabaseTables.tableWorkspaceProjects,
            {'name': 'Mutated In Transaction'},
            where: 'id = ?',
            whereArgs: [projId],
          );
          // Throw error to trigger rollback
          throw Exception('Simulated mid-transaction disk failure');
        });
      } catch (_) {}

      // Verify name was NOT changed
      final loaded = await repo.getProjectData(projId);
      expect(loaded!.name, 'Project Rollback');

      await db.close();
    });

    // ==============================================================
    // 11. INVARIANT TESTS (Section 14)
    // ==============================================================
    test('Fixture 11: Invariant counts and content snapshots comparison', () async {
      final dbPath = p.join(tempDir.path, 'test_invariants.db');
      final db = await openRealDatabase(dbPath);
      final repo = AssessmentRepository.withDb(db);

      const projId = 'proj_inv';
      const specId = 'spec_inv';
      const paperId = 'paper_inv';

      await repo.saveProjectData(AssessmentProjectData(id: projId, name: 'Inv Proj', createdAt: DateTime.now(), updatedAt: DateTime.now()));
      await repo.saveSpecification(ExamSpecification(id: specId, projectId: projId, title: 'Inv Spec', createdAt: DateTime.now(), updatedAt: DateTime.now()));
      await repo.saveMatrix(const ExamMatrix(specificationId: specId, cells: [
        ExamMatrixCell(id: 'c1', specificationId: specId, objectiveId: 'obj_1', difficulty: QuestionDifficulty.thongHieu, questionCount: 4, scorePerQuestion: 1.0),
      ]));

      final master = ExamPaper(
        id: paperId,
        assessmentProjectId: projId,
        specificationId: specId,
        title: 'Master Inv',
        isFinalized: true,
        createdAt: DateTime.now(),
        questions: List.generate(4, (i) => createDummyQuestion('q_$i', i + 1)),
      );
      await repo.saveExamPaper(master);

      const engine = ExamCodeEngine();
      final codeRes = engine.generateCodes(masterPaper: master, numberOfCodes: 2, startingCode: 101);
      await repo.saveExamCodes(codeRes.codes);

      // Capture before snapshots
      final beforePaper = await repo.getExamPaperById(paperId);
      final beforeCodes = await repo.getExamCodes(paperId);

      // Perform harmless project rename
      await repo.saveProjectData(AssessmentProjectData(id: projId, name: 'Inv Proj Renamed', createdAt: DateTime.now(), updatedAt: DateTime.now()));

      // Capture after snapshots
      final afterPaper = await repo.getExamPaperById(paperId);
      final afterCodes = await repo.getExamCodes(paperId);

      // Invariant checks
      expect(afterPaper!.id, equals(beforePaper!.id));
      expect(afterPaper.totalScore, equals(beforePaper.totalScore));
      expect(afterPaper.questions.length, equals(beforePaper.questions.length));
      expect(afterCodes.length, equals(beforeCodes.length));
      for (int i = 0; i < beforeCodes.length; i++) {
        expect(afterCodes[i].code, equals(beforeCodes[i].code));
        expect(afterCodes[i].questions.length, equals(beforeCodes[i].questions.length));
      }

      await db.close();
    });

    // ==============================================================
    // 12. REVIEW ORPHAN REPAIR SAFETY (Section 15)
    // ==============================================================
    test('Fixture 12: Safe ambiguous orphan repair maintains fail-closed policy', () async {
      final dbPath = p.join(tempDir.path, 'test_orphan_safety.db');
      final db = await openRealDatabase(dbPath);
      final repo = AssessmentRepository.withDb(db);

      // Run repair on clean database
      final report = await repo.repairOrphanRecordsDetailed(dryRun: true);
      expect(report.ambiguousCount, equals(0));
      expect(report.totalOrphans, equals(0));

      await db.close();
    });
  });
}
