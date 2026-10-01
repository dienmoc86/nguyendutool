import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/database/database_tables.dart';
import 'package:nguyendu_tool/core/errors/app_exceptions.dart';
import 'package:nguyendu_tool/features/assessment_studio/data/assessment_repository.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/assessment_project_data.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/exam_code.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/exam_matrix.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/exam_paper.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/exam_question_snapshot.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/exam_specification.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/question_choice.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/services/exam_code_engine.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/services/exam_question_selector.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/services/score_precision_handler.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/validation/exam_code_verifier.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/validation/exam_preflight_validator.dart';
import 'package:nguyendu_tool/features/assessment_studio/infrastructure/assessment_docx_exporter.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/question_models.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide DatabaseException;

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Phase 7R.2 Final Database & Exam Integrity Remediation Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('phase7r2_tests_');
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
      await db.execute('PRAGMA foreign_keys = ON;');
      return db;
    }

    ExamQuestionSnapshot createSnapshot({
      required String id,
      required String prompt,
      double score = 0.5,
      QuestionDifficulty difficulty = QuestionDifficulty.nhanBiet,
      String? objectiveId,
      QuestionType type = QuestionType.multipleChoice,
      String correctChoiceId = 'c1',
      String correctAnswerText = 'A',
    }) {
      return ExamQuestionSnapshot(
        questionId: id,
        prompt: prompt,
        score: score,
        difficulty: difficulty,
        objectiveId: objectiveId,
        type: type,
        correctChoiceId: correctChoiceId,
        correctAnswerText: correctAnswerText,
        choices: const [
          QuestionChoice(id: 'c1', text: 'Phương án 1'),
          QuestionChoice(id: 'c2', text: 'Phương án 2'),
          QuestionChoice(id: 'c3', text: 'Phương án 3'),
          QuestionChoice(id: 'c4', text: 'Phương án 4'),
        ],
      );
    }

    // ==============================================================
    // 1. P0 — SQLITE REPLACE AND CASCADE DATA LOSS (Sections 1 & 13 Test A)
    // ==============================================================
    test('P0 Section 1: saveExamPaper does not use REPLACE and preserves all child codes and questions', () async {
      final dbPath = p.join(tempDir.path, 'cascade_test.db');
      var db = await openRealDatabase(dbPath);
      var repo = AssessmentRepository.withDb(db);

      const projId = 'proj_cascade';
      const specId = 'spec_cascade';
      const paperId = 'paper_cascade_master';

      // 1. Create project, spec, paper
      await repo.saveProjectData(AssessmentProjectData(id: projId, name: 'Cascade Test', createdAt: DateTime.now(), updatedAt: DateTime.now()));
      await repo.saveSpecification(ExamSpecification(
        id: specId,
        projectId: projId,
        title: 'Spec',
        questionCount: 4,
        totalScore: 4.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final questions = List.generate(4, (i) => createSnapshot(id: 'q_$i', prompt: 'Prompt $i', score: 1.0));
      final master = ExamPaper(
        id: paperId,
        assessmentProjectId: projId,
        specificationId: specId,
        title: 'Master Draft',
        durationMinutes: 45,
        totalScore: 4.0,
        questions: questions,
        createdAt: DateTime.now(),
      );
      await repo.saveExamPaper(master);

      // 2. Generate 4 student codes
      const engine = ExamCodeEngine();
      final codeResult = engine.generateCodes(masterPaper: master, numberOfCodes: 4, startingCode: 101);
      await repo.saveExamCodes(codeResult.codes);

      // 3. Finalize master
      await repo.finalizeExamPaper(paperId);
      final finalized = await repo.getExamPaperById(paperId);
      expect(finalized!.isFinalized, isTrue);

      // 4. Verify initial codes count
      var savedCodes = await repo.getExamCodes(paperId);
      expect(savedCodes.length, equals(4));
      var childCountRows = await db.rawQuery('SELECT COUNT(*) as count FROM ${DatabaseTables.tableExamCodeQuestions}');
      expect(childCountRows.first['count'], equals(16));

      // 5. Call saveExamPaper with identical finalized master
      await repo.saveExamPaper(finalized);

      // 6. Verify children survived in active session
      savedCodes = await repo.getExamCodes(paperId);
      expect(savedCodes.length, equals(4));
      childCountRows = await db.rawQuery('SELECT COUNT(*) as count FROM ${DatabaseTables.tableExamCodeQuestions}');
      expect(childCountRows.first['count'], equals(16));

      // 7. Close and reopen SQLite with FK ON
      await db.close();
      db = await openRealDatabase(dbPath);
      repo = AssessmentRepository.withDb(db);

      // 8. Verify all 4 codes and every code question survive after restart
      final fkCheck = await db.rawQuery('PRAGMA foreign_key_check;');
      expect(fkCheck, isEmpty);

      savedCodes = await repo.getExamCodes(paperId);
      expect(savedCodes.length, equals(4));
      for (final c in savedCodes) {
        expect(c.questions.length, equals(4));
        expect(c.examPaperId, equals(paperId));
      }

      await db.close();
    });

    // ==============================================================
    // 2. P0 — FINALIZED METADATA IMMUTABILITY (Sections 2 & 13 Test E)
    // ==============================================================
    test('P0 Section 2: Attempts to modify finalized exam fields throw FinalizedExamImmutableException', () async {
      final dbPath = p.join(tempDir.path, 'immutable_test.db');
      final db = await openRealDatabase(dbPath);
      final repo = AssessmentRepository.withDb(db);

      const paperId = 'paper_imm_01';
      await repo.saveProjectData(AssessmentProjectData(
        id: 'proj_imm',
        name: 'Project Imm',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await repo.saveSpecification(ExamSpecification(
        id: 'spec_imm',
        projectId: 'proj_imm',
        title: 'Spec Imm',
        questionCount: 1,
        totalScore: 10.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final questions = [createSnapshot(id: 'q1', prompt: 'Prompt 1', score: 10.0)];
      final paper = ExamPaper(
        id: paperId,
        assessmentProjectId: 'proj_imm',
        specificationId: 'spec_imm',
        title: 'Initial Title',
        examCode: 'MASTER',
        durationMinutes: 45,
        totalScore: 10.0,
        randomSeed: 42,
        revisionNumber: 1,
        questions: questions,
        createdAt: DateTime.now(),
      );

      await repo.saveExamPaper(paper);
      await repo.finalizeExamPaper(paperId);
      final finalized = (await repo.getExamPaperById(paperId))!;

      // 1. Modifying title
      expect(
        () => repo.saveExamPaper(finalized.copyWith(title: 'Hacked Title')),
        throwsA(isA<FinalizedExamImmutableException>()),
      );

      // 2. Modifying totalScore
      expect(
        () => repo.saveExamPaper(finalized.copyWith(totalScore: 9.0)),
        throwsA(isA<FinalizedExamImmutableException>()),
      );

      // 3. Modifying durationMinutes
      expect(
        () => repo.saveExamPaper(finalized.copyWith(durationMinutes: 90)),
        throwsA(isA<FinalizedExamImmutableException>()),
      );

      // 4. Modifying examCode
      expect(
        () => repo.saveExamPaper(finalized.copyWith(examCode: 'MUTATED')),
        throwsA(isA<FinalizedExamImmutableException>()),
      );

      // 5. Attempt downgrade isFinalized to false
      expect(
        () => repo.saveExamPaper(finalized.copyWith(isFinalized: false)),
        throwsA(isA<FinalizedExamImmutableException>()),
      );

      // 6. Modifying questions
      final alteredQ = [createSnapshot(id: 'q1', prompt: 'Altered Prompt', score: 10.0)];
      expect(
        () => repo.saveExamPaper(finalized.copyWith(questions: alteredQ)),
        throwsA(isA<FinalizedExamImmutableException>()),
      );

      // Verify original DB row unchanged
      final reloaded = (await repo.getExamPaperById(paperId))!;
      expect(reloaded.title, equals('Initial Title'));
      expect(reloaded.isFinalized, isTrue);
      expect(reloaded.questions.first.prompt, equals('Prompt 1'));

      await db.close();
    });

    // ==============================================================
    // 3. P0 — EXAM CODE QUESTION GLOBAL ID COLLISION (Sections 3 & 13 Test B)
    // ==============================================================
    test('P0 Section 3: Child IDs across two exams sharing student code 101 and question q1 never collide', () async {
      final dbPath = p.join(tempDir.path, 'collision_test.db');
      var db = await openRealDatabase(dbPath);
      var repo = AssessmentRepository.withDb(db);

      // Setup Assessment A and Assessment B
      await repo.saveProjectData(AssessmentProjectData(id: 'proj_A', name: 'Proj A', createdAt: DateTime.now(), updatedAt: DateTime.now()));
      await repo.saveProjectData(AssessmentProjectData(id: 'proj_B', name: 'Proj B', createdAt: DateTime.now(), updatedAt: DateTime.now()));
      await repo.saveSpecification(ExamSpecification(
        id: 'spec_A',
        projectId: 'proj_A',
        title: 'Spec A',
        questionCount: 1,
        totalScore: 1.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await repo.saveSpecification(ExamSpecification(
        id: 'spec_B',
        projectId: 'proj_B',
        title: 'Spec B',
        questionCount: 1,
        totalScore: 1.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final qShared = createSnapshot(id: 'q_shared_01', prompt: 'Shared Question Content', score: 1.0);

      final paperA = ExamPaper(
        id: 'paper_A',
        assessmentProjectId: 'proj_A',
        specificationId: 'spec_A',
        title: 'Exam A',
        questions: [qShared],
        createdAt: DateTime.now(),
      );
      final paperB = ExamPaper(
        id: 'paper_B',
        assessmentProjectId: 'proj_B',
        specificationId: 'spec_B',
        title: 'Exam B',
        questions: [qShared],
        createdAt: DateTime.now(),
      );

      await repo.saveExamPaper(paperA);
      await repo.saveExamPaper(paperB);

      const engine = ExamCodeEngine();
      final codesA = engine.generateCodes(masterPaper: paperA, numberOfCodes: 1, startingCode: 101);
      final codesB = engine.generateCodes(masterPaper: paperB, numberOfCodes: 1, startingCode: 101);

      // Persist both into the same database
      await repo.saveExamCodes(codesA.codes);
      await repo.saveExamCodes(codesB.codes);

      // Close and reopen database
      await db.close();
      db = await openRealDatabase(dbPath);
      repo = AssessmentRepository.withDb(db);

      // Verify child records
      final qA = (await repo.getExamCodes('paper_A')).first.questions.first;
      final qB = (await repo.getExamCodes('paper_B')).first.questions.first;

      expect(qA.id, isNot(equals(qB.id)), reason: 'Child IDs must be globally distinct across exams');
      expect(qA.id, contains('paper_A'));
      expect(qB.id, contains('paper_B'));
      expect(qA.questionId, equals('q_shared_01'));
      expect(qB.questionId, equals('q_shared_01'));

      final allChildRows = await db.query(DatabaseTables.tableExamCodeQuestions);
      expect(allChildRows.length, equals(2));

      final fkCheck = await db.rawQuery('PRAGMA foreign_key_check;');
      expect(fkCheck, isEmpty);

      await db.close();
    });

    // ==============================================================
    // 4. P0 — SAVE EXAM CODES TRANSACTION VALIDATION (Sections 4 & 13 Test C, I)
    // ==============================================================
    test('P0 Section 4: saveExamCodes validates atomically before deleting any old records', () async {
      final dbPath = p.join(tempDir.path, 'atomic_save_test.db');
      final db = await openRealDatabase(dbPath);
      final repo = AssessmentRepository.withDb(db);

      const paperId = 'paper_valid';
      await repo.saveProjectData(AssessmentProjectData(id: 'proj_v', name: 'Proj V', createdAt: DateTime.now(), updatedAt: DateTime.now()));
      await repo.saveSpecification(ExamSpecification(
        id: 'spec_v',
        projectId: 'proj_v',
        title: 'Spec V',
        questionCount: 1,
        totalScore: 1.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final questions = [createSnapshot(id: 'q1', prompt: 'Q1', score: 1.0)];
      final paper = ExamPaper(
        id: paperId,
        assessmentProjectId: 'proj_v',
        specificationId: 'spec_v',
        title: 'Valid Paper',
        questions: questions,
        createdAt: DateTime.now(),
      );
      await repo.saveExamPaper(paper);

      const engine = ExamCodeEngine();
      final validGen = engine.generateCodes(masterPaper: paper, numberOfCodes: 2, startingCode: 101);
      await repo.saveExamCodes(validGen.codes);

      var saved = await repo.getExamCodes(paperId);
      expect(saved.length, equals(2));

      // Test 1: Mixed code list (code belonging to a different paper)
      final foreignCode = ExamCode(
        id: 'ec_foreign_999',
        examPaperId: 'paper_DIFFERENT',
        code: '999',
        questions: const [],
        createdAt: DateTime.now(),
      );

      expect(
        () => repo.saveExamCodes([...validGen.codes, foreignCode]),
        throwsA(isA<ArgumentError>()),
      );

      // Verify previous valid codes remain intact!
      saved = await repo.getExamCodes(paperId);
      expect(saved.length, equals(2), reason: 'Transaction aborted before deleting existing codes');

      // Test 2: Duplicate child question ID
      final corruptCode = ExamCode(
        id: 'ec_paper_valid_103',
        examPaperId: paperId,
        code: '103',
        createdAt: DateTime.now(),
        questions: [
          ExamCodeQuestion(
            id: 'ecq_dup_01',
            examCodeId: 'ec_paper_valid_103',
            questionId: 'q1',
            orderIndex: 0,
            score: 1.0,
            correctDisplayAnswer: 'A',
            snapshot: questions.first,
          ),
          ExamCodeQuestion(
            id: 'ecq_dup_01', // DUPLICATE CHILD ID!
            examCodeId: 'ec_paper_valid_103',
            questionId: 'q2',
            orderIndex: 1,
            score: 1.0,
            correctDisplayAnswer: 'B',
            snapshot: questions.first,
          ),
        ],
      );

      expect(
        () => repo.saveExamCodes([corruptCode]),
        throwsA(isA<ArgumentError>()),
      );

      saved = await repo.getExamCodes(paperId);
      expect(saved.length, equals(2));

      await db.close();
    });

    // ==============================================================
    // 5. P0 — ORPHAN REPAIR IS AMBIGUOUS (Sections 5 & 13 Test D)
    // ==============================================================
    test('P0 Section 5: Orphan repair refuses ambiguous matches and preserves orphan rows', () async {
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      for (final ddl in DatabaseTables.allCreationStatements) {
        await db.execute(ddl);
      }

      // Two papers both containing student code 101
      await db.insert(DatabaseTables.tableExamPapers, {
        'id': 'paper_01',
        'project_id': 'proj_1',
        'specification_id': 'spec_1',
        'title': 'Paper 1',
        'exam_code': 'MASTER',
        'duration_minutes': 45,
        'total_score': 10.0,
        'created_at': DateTime.now().toIso8601String(),
      });
      await db.insert(DatabaseTables.tableExamPapers, {
        'id': 'paper_02',
        'project_id': 'proj_2',
        'specification_id': 'spec_2',
        'title': 'Paper 2',
        'exam_code': 'MASTER',
        'duration_minutes': 45,
        'total_score': 10.0,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Paper 1 questions: q_p1
      await db.insert(DatabaseTables.tableExamPaperQuestions, {
        'id': 'epq_1',
        'exam_paper_id': 'paper_01',
        'question_id': 'q_p1',
        'order_index': 0,
        'score': 1.0,
        'snapshot_json': '{}',
      });

      // Both papers have student code 101
      await db.insert(DatabaseTables.tableExamCodes, {
        'id': 'ec_paper_01_101',
        'exam_paper_id': 'paper_01',
        'code': '101',
        'created_at': DateTime.now().toIso8601String(),
      });
      await db.insert(DatabaseTables.tableExamCodes, {
        'id': 'ec_paper_02_101',
        'exam_paper_id': 'paper_02',
        'code': '101',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Orphan 1: question_id is 'q_p1', references legacy 'ec_101' -> can be unambiguously resolved to paper_01
      await db.insert(DatabaseTables.tableExamCodeQuestions, {
        'id': 'ecq_orphan_clear',
        'exam_code_id': 'ec_101',
        'question_id': 'q_p1',
        'order_index': 0,
        'score': 1.0,
        'correct_display_answer': 'A',
        'snapshot_json': '{}',
      });

      // Orphan 2: question_id is 'q_unknown', references legacy 'ec_101' -> AMBIGUOUS!
      await db.insert(DatabaseTables.tableExamCodeQuestions, {
        'id': 'ecq_orphan_ambiguous',
        'exam_code_id': 'ec_101',
        'question_id': 'q_unknown',
        'order_index': 1,
        'score': 1.0,
        'correct_display_answer': 'B',
        'snapshot_json': '{}',
      });

      final repo = AssessmentRepository.withDb(db);
      final report = await repo.repairOrphanRecordsDetailed();

      expect(report.totalOrphans, equals(2));
      expect(report.repairedCount, equals(1));
      expect(report.ambiguousCount, equals(1));

      // Verify clear orphan was repaired to paper_01
      final repairedRow = await db.query(DatabaseTables.tableExamCodeQuestions, where: 'id = ?', whereArgs: ['ecq_orphan_clear']);
      expect(repairedRow.first['exam_code_id'], equals('ec_paper_01_101'));

      // Verify ambiguous orphan was NOT arbitrarily relinked and preserved
      final ambiguousRow = await db.query(DatabaseTables.tableExamCodeQuestions, where: 'id = ?', whereArgs: ['ecq_orphan_ambiguous']);
      expect(ambiguousRow.first['exam_code_id'], equals('ec_101'));

      await db.close();
    });

    // ==============================================================
    // 6. P1 — VALID CHOICE PERMUTATION (Sections 6 & 13 Test F)
    // ==============================================================
    test('P1 Section 6: ExamCodeVerifier detects and rejects invalid choice permutations', () {
      final master = ExamPaper(
        id: 'p_perm',
        assessmentProjectId: 'proj_p',
        specificationId: 'spec_p',
        title: 'Master',
        totalScore: 1.0,
        questions: [
          createSnapshot(id: 'q1', prompt: 'Q1', score: 1.0),
        ],
        createdAt: DateTime.now(),
      );

      const verifier = ExamCodeVerifier();

      ExamCode buildTestCode(List<String> choiceOrder) {
        return ExamCode(
          id: 'ec_perm_101',
          examPaperId: 'p_perm',
          code: '101',
          createdAt: DateTime.now(),
          questions: [
            ExamCodeQuestion(
              id: 'ecq_p1',
              examCodeId: 'ec_perm_101',
              questionId: 'q1',
              orderIndex: 0,
              score: 1.0,
              correctDisplayAnswer: 'A',
              choiceOrder: choiceOrder,
              snapshot: master.questions.first,
            ),
          ],
        );
      }

      // 1. Duplicate IDs: A, A, B, C, D
      final resDuplicate = verifier.verifyCodes([buildTestCode(['c1', 'c1', 'c2', 'c3'])], canonicalMaster: master);
      expect(resDuplicate.isEquivalent, isFalse);
      expect(resDuplicate.mismatches.any((m) => m.contains('CHOICE_PERMUTATION_CORRUPTED')), isTrue);

      // 2. Length mismatch (missing ID): A, B, C
      final resMissing = verifier.verifyCodes([buildTestCode(['c1', 'c2', 'c3'])], canonicalMaster: master);
      expect(resMissing.isEquivalent, isFalse);
      expect(resMissing.mismatches.any((m) => m.contains('CHOICE_PERMUTATION_CORRUPTED')), isTrue);

      // 3. Unknown ID: A, B, C, X
      final resUnknown = verifier.verifyCodes([buildTestCode(['c1', 'c2', 'c3', 'c_X'])], canonicalMaster: master);
      expect(resUnknown.isEquivalent, isFalse);
      expect(resUnknown.mismatches.any((m) => m.contains('CHOICE_PERMUTATION_CORRUPTED')), isTrue);

      // 4. Blank ID
      final resBlank = verifier.verifyCodes([buildTestCode(['c1', 'c2', 'c3', ''])], canonicalMaster: master);
      expect(resBlank.isEquivalent, isFalse);

      // 5. Valid permutation: c4, c2, c1, c3
      // When c1 is at index 2, letter must be 'C'
      final validCode = ExamCode(
        id: 'ec_perm_101',
        examPaperId: 'p_perm',
        code: '101',
        createdAt: DateTime.now(),
        questions: [
          ExamCodeQuestion(
            id: 'ecq_p1',
            examCodeId: 'ec_perm_101',
            questionId: 'q1',
            orderIndex: 0,
            score: 1.0,
            correctDisplayAnswer: 'C',
            choiceOrder: ['c4', 'c2', 'c1', 'c3'],
            snapshot: master.questions.first,
          ),
        ],
      );
      final resValid = verifier.verifyCodes([validCode], canonicalMaster: master);
      expect(resValid.isEquivalent, isTrue);
    });

    // ==============================================================
    // 7. P1 — SNAPSHOT CONTENT COMPARISON (Sections 7 & 13 Test G)
    // ==============================================================
    test('P1 Section 7: Altered snapshot content fails verification', () {
      final master = ExamPaper(
        id: 'p_snap',
        assessmentProjectId: 'proj_s',
        specificationId: 'spec_s',
        title: 'Master',
        totalScore: 1.0,
        questions: [
          createSnapshot(id: 'q1', prompt: 'Prompt Gốc', score: 1.0),
        ],
        createdAt: DateTime.now(),
      );

      const verifier = ExamCodeVerifier();

      // Altered prompt
      final codeAlteredPrompt = ExamCode(
        id: 'ec_snap_101',
        examPaperId: 'p_snap',
        code: '101',
        createdAt: DateTime.now(),
        questions: [
          ExamCodeQuestion(
            id: 'ecq_s1',
            examCodeId: 'ec_snap_101',
            questionId: 'q1',
            orderIndex: 0,
            score: 1.0,
            correctDisplayAnswer: 'A',
            choiceOrder: ['c1', 'c2', 'c3', 'c4'],
            snapshot: master.questions.first.copyWith(prompt: 'Prompt Bị Sửa Đổi'),
          ),
        ],
      );
      final resPrompt = verifier.verifyCodes([codeAlteredPrompt], canonicalMaster: master);
      expect(resPrompt.isEquivalent, isFalse);
      expect(resPrompt.mismatches.any((m) => m.contains('QUESTION_PROMPT_MUTATED')), isTrue);

      // Altered choice text
      final codeAlteredChoice = ExamCode(
        id: 'ec_snap_101',
        examPaperId: 'p_snap',
        code: '101',
        createdAt: DateTime.now(),
        questions: [
          ExamCodeQuestion(
            id: 'ecq_s1',
            examCodeId: 'ec_snap_101',
            questionId: 'q1',
            orderIndex: 0,
            score: 1.0,
            correctDisplayAnswer: 'A',
            choiceOrder: ['c1', 'c2', 'c3', 'c4'],
            snapshot: master.questions.first.copyWith(
              choices: [
                const QuestionChoice(id: 'c1', text: 'Text Bị Thay Đổi'),
                const QuestionChoice(id: 'c2', text: 'Phương án 2'),
                const QuestionChoice(id: 'c3', text: 'Phương án 3'),
                const QuestionChoice(id: 'c4', text: 'Phương án 4'),
              ],
            ),
          ),
        ],
      );
      final resChoice = verifier.verifyCodes([codeAlteredChoice], canonicalMaster: master);
      expect(resChoice.isEquivalent, isFalse);
      expect(resChoice.mismatches.any((m) => m.contains('CHOICE_TEXT_MUTATED')), isTrue);
    });

    // ==============================================================
    // 8. P1 — PREFLIGHT MATRIX RECONCILIATION (Sections 8 & 13 Test H)
    // ==============================================================
    test('P1 Section 8: Preflight matrix reconciliation detects unsatisfied cognitive / type distributions', () {
      final spec = ExamSpecification(
        id: 'spec_rec',
        projectId: 'proj_rec',
        title: 'Spec Rec',
        questionCount: 2,
        totalScore: 2.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      const matrix = ExamMatrix(
        specificationId: 'spec_rec',
        cells: [
          ExamMatrixCell(
            id: 'c1',
            specificationId: 'spec_rec',
            objectiveId: 'obj_1',
            difficulty: QuestionDifficulty.nhanBiet,
            questionCount: 1,
            scorePerQuestion: 1.0,
          ),
          ExamMatrixCell(
            id: 'c2',
            specificationId: 'spec_rec',
            objectiveId: 'ALL',
            difficulty: QuestionDifficulty.thongHieu,
            questionCount: 1,
            scorePerQuestion: 1.0,
          ),
        ],
      );

      // Deficient master: both questions are nhanBiet (missing thongHieu)
      final deficientMaster = ExamPaper(
        id: 'paper_rec',
        assessmentProjectId: 'proj_rec',
        specificationId: 'spec_rec',
        title: 'Master',
        totalScore: 2.0,
        questions: [
          createSnapshot(id: 'q1', prompt: 'Q1', difficulty: QuestionDifficulty.nhanBiet, objectiveId: 'obj_1', score: 1.0),
          createSnapshot(id: 'q2', prompt: 'Q2', difficulty: QuestionDifficulty.nhanBiet, objectiveId: 'obj_1', score: 1.0),
        ],
        createdAt: DateTime.now(),
      );

      const validator = ExamPreflightValidator();
      final resDeficient = validator.validate(
        specification: spec,
        matrix: matrix,
        masterPaper: deficientMaster,
        codes: [],
        answerKeys: {},
      );

      expect(resDeficient.canExport, isFalse);
      expect(resDeficient.blockingErrors.any((e) => e.contains('MATRIX_RECONCILIATION_FAILURE')), isTrue);
    });

    // ==============================================================
    // 9. P1 — SELECTOR CONSTRAINT VALIDITY (Section 9 Counterexample)
    // ==============================================================
    test('P1 Section 9: Counterexample where greedy allocation fails but constraint-aware allocation succeeds', () {
      // Counterexample scenario:
      // Bank:
      // q1: obj1, nhanBiet, multipleChoice
      // q2: obj1, nhanBiet, essay
      //
      // Matrix:
      // Cell 1: obj1, nhanBiet, count 1, any type
      // Cell 2: ALL, nhanBiet, count 1, type essay
      //
      // If Cell 1 greedily takes q2 (essay), Cell 2 has no candidates left.
      // Constraint-aware bipartite matching finds: Cell 1 -> q1, Cell 2 -> q2.
      const matrix = ExamMatrix(
        specificationId: 'spec_counter',
        cells: [
          ExamMatrixCell(
            id: 'c1',
            specificationId: 'spec_counter',
            objectiveId: 'obj1',
            difficulty: QuestionDifficulty.nhanBiet,
            questionCount: 1,
            scorePerQuestion: 1.0,
          ),
          ExamMatrixCell(
            id: 'c2',
            specificationId: 'spec_counter',
            objectiveId: 'ALL',
            difficulty: QuestionDifficulty.nhanBiet,
            questionCount: 1,
            scorePerQuestion: 1.0,
            questionTypeDistribution: {QuestionType.essay: 1},
          ),
        ],
      );

      final bank = [
        const QuestionItem(
          id: 'q1',
          prompt: 'MCQ Question',
          type: QuestionType.multipleChoice,
          difficulty: QuestionDifficulty.nhanBiet,
          learningObjective: 'obj1',
          choices: ['A', 'B', 'C', 'D'],
          correctAnswer: 'A',
        ),
        const QuestionItem(
          id: 'q2',
          prompt: 'Essay Question',
          type: QuestionType.essay,
          difficulty: QuestionDifficulty.nhanBiet,
          learningObjective: 'obj1',
          choices: [],
          correctAnswer: 'Answer Guide',
        ),
      ];

      const selector = ExamQuestionSelector();
      final result = selector.selectQuestions(matrix: matrix, questionBank: bank, randomSeed: 12345);

      expect(result.isSuccess, isTrue, reason: 'Constraint-aware matching must find feasible assignment');
      expect(result.questions.length, equals(2));
      final qIds = result.questions.map((q) => q.questionId).toSet();
      expect(qIds, containsAll(['q1', 'q2']));
    });

    // ==============================================================
    // 10. SCORE REPRESENTATION (Section 10)
    // ==============================================================
    test('Section 10: ScorePrecisionHandler rejects non-finite, negative, and invalid precision', () {
      expect(ScorePrecisionHandler.toHundredths(0.25), equals(25));
      expect(ScorePrecisionHandler.toHundredths(10.0), equals(1000));
      expect(ScorePrecisionHandler.fromHundredths(25), equals(0.25));

      // Over 2 decimals
      expect(() => ScorePrecisionHandler.toHundredths(0.125), throwsA(isA<ScorePrecisionException>()));
      // Negative
      expect(() => ScorePrecisionHandler.toHundredths(-1.0), throwsA(isA<ScorePrecisionException>()));
      // NaN
      expect(() => ScorePrecisionHandler.toHundredths(double.nan), throwsA(isA<ScorePrecisionException>()));
      // Infinity
      expect(() => ScorePrecisionHandler.toHundredths(double.infinity), throwsA(isA<ScorePrecisionException>()));
    });

    // ==============================================================
    // 11. FINALIZE EXAM SAFETY (Section 11)
    // ==============================================================
    test('Section 11: finalizeExamPaper is transactional, idempotent, and refuses empty exam', () async {
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      for (final ddl in DatabaseTables.allCreationStatements) {
        await db.execute(ddl);
      }
      final repo = AssessmentRepository.withDb(db);

      await repo.saveProjectData(AssessmentProjectData(id: 'proj_e', name: 'Proj E', createdAt: DateTime.now(), updatedAt: DateTime.now()));
      await repo.saveSpecification(ExamSpecification(
        id: 'spec_e',
        projectId: 'proj_e',
        title: 'Spec E',
        questionCount: 1,
        totalScore: 10.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Empty paper
      final emptyPaper = ExamPaper(
        id: 'p_empty',
        assessmentProjectId: 'proj_e',
        specificationId: 'spec_e',
        title: 'Empty',
        questions: const [],
        createdAt: DateTime.now(),
      );
      await repo.saveExamPaper(emptyPaper);
      expect(() => repo.finalizeExamPaper('p_empty'), throwsA(isA<InvalidExamQuestionException>()));

      // Valid paper
      final validPaper = ExamPaper(
        id: 'p_valid',
        assessmentProjectId: 'proj_e',
        specificationId: 'spec_e',
        title: 'Valid',
        questions: [createSnapshot(id: 'q1', prompt: 'Q1', score: 10.0)],
        createdAt: DateTime.now(),
      );
      await repo.saveExamPaper(validPaper);
      await repo.finalizeExamPaper('p_valid');

      final fin1 = (await repo.getExamPaperById('p_valid'))!;
      expect(fin1.isFinalized, isTrue);
      final finTime1 = fin1.finalizedAt;
      expect(finTime1, isNotNull);

      // Re-finalize should be harmless and NOT overwrite timestamp
      await Future.delayed(const Duration(milliseconds: 50));
      await repo.finalizeExamPaper('p_valid');
      final fin2 = (await repo.getExamPaperById('p_valid'))!;
      expect(fin2.finalizedAt, equals(finTime1));

      await db.close();
    });

    // ==============================================================
    // 14. REAL E2E ASSESSMENT TEST (Section 14 & 13 Test J, K)
    // ==============================================================
    test('Section 14: Real E2E Assessment Test with Projects A & B, 5 shared questions, restart, and DOCX export', () async {
      final dbPath = p.join(tempDir.path, 'e2e_real_assessment.db');
      var db = await openRealDatabase(dbPath);
      var repo = AssessmentRepository.withDb(db);

      const projAId = 'proj_e2e_A';
      const projBId = 'proj_e2e_B';

      await repo.saveProjectData(AssessmentProjectData(id: projAId, name: 'Project A', grade: '9', subject: 'Ngữ văn', createdAt: DateTime.now(), updatedAt: DateTime.now()));
      await repo.saveProjectData(AssessmentProjectData(id: projBId, name: 'Project B', grade: '9', subject: 'Ngữ văn', createdAt: DateTime.now(), updatedAt: DateTime.now()));

      await repo.saveSpecification(ExamSpecification(
        id: 'spec_A',
        projectId: projAId,
        title: 'Spec A',
        questionCount: 20,
        totalScore: 10.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await repo.saveSpecification(ExamSpecification(
        id: 'spec_B',
        projectId: projBId,
        title: 'Spec B',
        questionCount: 20,
        totalScore: 10.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Create 5 shared question snapshots and 15 unique for A, 15 unique for B (20 each)
      final sharedQuestions = List.generate(5, (i) => createSnapshot(id: 'q_shared_$i', prompt: 'Shared Question $i', score: 0.5));
      final uniqueA = List.generate(15, (i) => createSnapshot(id: 'q_a_$i', prompt: 'Question A $i', score: 0.5));
      final uniqueB = List.generate(15, (i) => createSnapshot(id: 'q_b_$i', prompt: 'Question B $i', score: 0.5));

      final paperA = ExamPaper(
        id: 'paper_A_20q',
        assessmentProjectId: projAId,
        specificationId: 'spec_A',
        title: 'Đề thi Văn A',
        durationMinutes: 45,
        totalScore: 10.0,
        questions: [...sharedQuestions, ...uniqueA],
        createdAt: DateTime.now(),
      );

      final paperB = ExamPaper(
        id: 'paper_B_20q',
        assessmentProjectId: projBId,
        specificationId: 'spec_B',
        title: 'Đề thi Văn B',
        durationMinutes: 45,
        totalScore: 10.0,
        questions: [...sharedQuestions, ...uniqueB],
        createdAt: DateTime.now(),
      );

      await repo.saveExamPaper(paperA);
      await repo.saveExamPaper(paperB);

      const engine = ExamCodeEngine();
      final codesA = engine.generateCodes(masterPaper: paperA, numberOfCodes: 4, startingCode: 101);
      final codesB = engine.generateCodes(masterPaper: paperB, numberOfCodes: 4, startingCode: 101);

      await repo.saveExamCodes(codesA.codes);
      await repo.saveExamCodes(codesB.codes);

      // Finalize Project A
      await repo.finalizeExamPaper('paper_A_20q');

      // Close SQLite database
      await db.close();

      // REOPEN SQLite database
      db = await openRealDatabase(dbPath);
      repo = AssessmentRepository.withDb(db);

      // Verify PRAGMAs
      final integrity = await db.rawQuery('PRAGMA integrity_check;');
      expect(integrity.first['integrity_check'], equals('ok'));

      final fkCheck = await db.rawQuery('PRAGMA foreign_key_check;');
      expect(fkCheck, isEmpty);

      // Verify A and B records
      final loadedA = await repo.getExamCodes('paper_A_20q');
      final loadedB = await repo.getExamCodes('paper_B_20q');

      expect(loadedA.length, equals(4));
      expect(loadedB.length, equals(4));

      int countChildA = 0;
      for (final code in loadedA) {
        countChildA += code.questions.length;
        expect(code.examPaperId, equals('paper_A_20q'));
      }

      int countChildB = 0;
      for (final code in loadedB) {
        countChildB += code.questions.length;
        expect(code.examPaperId, equals('paper_B_20q'));
      }

      expect(countChildA, equals(80)); // 4 codes * 20 questions
      expect(countChildB, equals(80)); // 4 codes * 20 questions

      final totalChildren = await db.rawQuery('SELECT COUNT(*) as count FROM ${DatabaseTables.tableExamCodeQuestions}');
      expect(totalChildren.first['count'], equals(160));

      // Attempt modified save on finalized Paper A: must reject without deleting children
      final finalizedA = (await repo.getExamPaperById('paper_A_20q'))!;
      expect(
        () => repo.saveExamPaper(finalizedA.copyWith(title: 'Corrupted Finalized Title')),
        throwsA(isA<FinalizedExamImmutableException>()),
      );

      final postCheckChildren = await db.rawQuery('SELECT COUNT(*) as count FROM ${DatabaseTables.tableExamCodeQuestions}');
      expect(postCheckChildren.first['count'], equals(160), reason: 'All 160 children survive rejected modification');

      // Export A and B independently to DOCX and verify OpenXML structure
      const headerA = ExamHeaderConfig(
        schoolName: 'TRƯỜNG THCS NGUYỄN DU',
        examTitle: 'ĐỀ KIỂM TRA ĐỊNH KỲ A',
        subject: 'Ngữ văn',
        grade: '9',
        durationMinutes: 45,
      );
      const headerB = ExamHeaderConfig(
        schoolName: 'TRƯỜNG THCS NGUYỄN DU',
        examTitle: 'ĐỀ KIỂM TRA ĐỊNH KỲ B',
        subject: 'Ngữ văn',
        grade: '9',
        durationMinutes: 45,
      );
      final outDirA = Directory(p.join(tempDir.path, 'out_A'))..createSync();
      final outDirB = Directory(p.join(tempDir.path, 'out_B'))..createSync();

      for (final code in loadedA) {
        final docx = await AssessmentDocxExporter.exportExamCode(
          examCode: code,
          headerConfig: headerA,
          outputPath: p.join(outDirA.path, 'exam_A_${code.code}.docx'),
        );
        expect(docx.existsSync(), isTrue);

        final keyDocx = await AssessmentDocxExporter.exportAnswerKey(
          answerKey: codesA.answerKeys[code.code]!,
          headerConfig: headerA,
          outputPath: p.join(outDirA.path, 'key_A_${code.code}.docx'),
        );
        expect(keyDocx.existsSync(), isTrue);
      }

      for (final code in loadedB) {
        final docx = await AssessmentDocxExporter.exportExamCode(
          examCode: code,
          headerConfig: headerB,
          outputPath: p.join(outDirB.path, 'exam_B_${code.code}.docx'),
        );
        expect(docx.existsSync(), isTrue);

        final keyDocx = await AssessmentDocxExporter.exportAnswerKey(
          answerKey: codesB.answerKeys[code.code]!,
          headerConfig: headerB,
          outputPath: p.join(outDirB.path, 'key_B_${code.code}.docx'),
        );
        expect(keyDocx.existsSync(), isTrue);
      }

      // Inspect DOCX structure of exported student code 101 for both projects
      for (final outDir in [outDirA, outDirB]) {
        final docxFiles = outDir.listSync().whereType<File>().where((f) => f.path.endsWith('.docx')).toList();
        expect(docxFiles.length, greaterThanOrEqualTo(5)); // 4 student exams + 1 answer key

        for (final docx in docxFiles) {
          final bytes = docx.readAsBytesSync();
          final archive = ZipDecoder().decodeBytes(bytes);
          final docXml = archive.findFile('word/document.xml');
          expect(docXml, isNotNull);
          final content = utf8.decode(docXml!.content as List<int>);
          expect(content.contains('<w:document'), isTrue);
        }
      }

      await db.close();
    });
  });
}
