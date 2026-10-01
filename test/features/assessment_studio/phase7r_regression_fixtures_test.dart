import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/database/database_tables.dart';
import 'package:nguyendu_tool/core/errors/app_exceptions.dart';
import 'package:nguyendu_tool/core/projects/data/workspace_project_repository.dart';
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
import 'package:nguyendu_tool/features/assessment_studio/domain/validation/exam_code_verifier.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/validation/exam_preflight_validator.dart';
import 'package:nguyendu_tool/features/assessment_studio/infrastructure/assessment_docx_exporter.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/learning_objective.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/question_models.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide DatabaseException;

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Phase 7R Required Regression Fixtures (Sections 1-22)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('phase7r_fixtures_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    Future<Database> createInitializedDb(String dbPath) async {
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

    // ==============================================================
    // FIXTURE A & FINDING 1: 20-QUESTION MIXED EXAM, 4 CODES, RESTART
    // ==============================================================
    test('Fixture A / Finding 1: Canonical ExamCode IDs survive save and restart with PRAGMA foreign_key_check = 0', () async {
      final dbFile = p.join(tempDir.path, 'fixture_a.db');

      // 1. First DB session
      var db = await createInitializedDb(dbFile);
      var repo = AssessmentRepository.withDb(db);

      // Create Assessment Project
      final project = AssessmentProjectData(
        id: 'proj_20q',
        name: 'Đề kiểm tra 20 câu',
        subject: 'Ngữ văn',
        grade: '9',
        durationMinutes: 45,
        totalScore: 10.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.saveProjectData(project);

      // Create Specification
      final spec = ExamSpecification(
        id: 'spec_20q',
        projectId: 'proj_20q',
        title: 'Đặc tả 20 câu',
        subject: 'Ngữ văn',
        grade: '9',
        durationMinutes: 45,
        totalScore: 10.0,
        questionCount: 20,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.saveSpecification(spec);

      // Create 20 Question Snapshots: 16 MCQ (0.25đ each), 2 Short Answer (1.0đ each), 2 Essay (2.0đ each)
      final List<ExamQuestionSnapshot> snapshots = [];
      for (int i = 1; i <= 16; i++) {
        snapshots.add(
          ExamQuestionSnapshot(
            questionId: 'q_mcq_$i',
            prompt: 'Nội dung câu hỏi trắc nghiệm số $i',
            choices: [
              QuestionChoice(id: 'c1_$i', text: 'Lựa chọn A câu $i'),
              QuestionChoice(id: 'c2_$i', text: 'Lựa chọn B câu $i'),
              QuestionChoice(id: 'c3_$i', text: 'Lựa chọn C câu $i'),
              QuestionChoice(id: 'c4_$i', text: 'Lựa chọn D câu $i'),
            ],
            correctChoiceId: 'c2_$i',
            correctAnswerText: 'B',
            type: QuestionType.multipleChoice,
            difficulty: QuestionDifficulty.nhanBiet,
            score: 0.25,
            sectionIndex: 0,
          ),
        );
      }
      for (int i = 17; i <= 18; i++) {
        snapshots.add(
          ExamQuestionSnapshot(
            questionId: 'q_short_$i',
            prompt: 'Câu hỏi trả lời ngắn số $i',
            correctChoiceId: '',
            correctAnswerText: 'Đáp án ngắn mẫu $i',
            type: QuestionType.shortAnswer,
            difficulty: QuestionDifficulty.thongHieu,
            score: 1.0,
            sectionIndex: 1,
          ),
        );
      }
      for (int i = 19; i <= 20; i++) {
        snapshots.add(
          ExamQuestionSnapshot(
            questionId: 'q_essay_$i',
            prompt: 'Câu hỏi tự luận phân tích số $i',
            correctChoiceId: '',
            correctAnswerText: 'Hướng dẫn chấm tự luận câu $i',
            type: QuestionType.essay,
            difficulty: QuestionDifficulty.vanDungCao,
            score: 2.0,
            sectionIndex: 2,
          ),
        );
      }

      final masterPaper = ExamPaper(
        id: 'paper_master_20q',
        assessmentProjectId: 'proj_20q',
        specificationId: 'spec_20q',
        title: 'Đề thi gốc 20 câu',
        examCode: 'MASTER',
        durationMinutes: 45,
        totalScore: 10.0,
        questions: snapshots,
        createdAt: DateTime.now(),
      );
      await repo.saveExamPaper(masterPaper);

      // Generate 4 codes: 101, 102, 103, 104
      const engine = ExamCodeEngine();
      final multiCodeResult = engine.generateCodes(
        masterPaper: masterPaper,
        numberOfCodes: 4,
        startingCode: 101,
        shuffleQuestions: true,
        shuffleChoices: true,
        baseSeed: 9999,
      );

      expect(multiCodeResult.codes.length, equals(4));
      for (final code in multiCodeResult.codes) {
        expect(code.id, equals('ec_${masterPaper.id}_${code.code}'));
        for (final q in code.questions) {
          expect(q.examCodeId, equals(code.id),
              reason: 'Parent code.id must strictly match child examCodeId');
        }
      }

      // Persist codes to real SQLite database
      await repo.saveExamCodes(multiCodeResult.codes);

      // Verify PRAGMA foreign_key_check is zero BEFORE closing
      final fkCheckBefore = await repo.checkForeignKeys();
      expect(fkCheckBefore, isEmpty, reason: 'Zero FK violations before close');

      // CLOSE DATABASE
      await db.close();

      // 2. REOPEN DATABASE FROM DISK
      db = await createInitializedDb(dbFile);
      repo = AssessmentRepository.withDb(db);

      // Verify PRAGMA foreign_key_check on fresh reopened connection
      final fkCheckAfter = await repo.checkForeignKeys();
      expect(fkCheckAfter, isEmpty, reason: 'Zero FK violations after restart');

      // Load each code and assert integrity
      final loadedCodes = await repo.getExamCodes(masterPaper.id);
      expect(loadedCodes.length, equals(4));

      for (int i = 0; i < 4; i++) {
        final expectedCodeStr = (101 + i).toString();
        final code = loadedCodes.firstWhere((c) => c.code == expectedCodeStr);
        expect(code.id, equals('ec_${masterPaper.id}_$expectedCodeStr'));
        expect(code.questions.length, equals(20));

        // Assert all choices and answers survive serialization
        for (final q in code.questions) {
          expect(q.examCodeId, equals(code.id));
          if (q.snapshot.type == QuestionType.multipleChoice) {
            expect(q.orderedChoices.length, equals(4));
            expect(q.correctDisplayAnswer, isIn(['A', 'B', 'C', 'D']));
            final choiceIndex = QuestionChoice.letterToIndex(q.correctDisplayAnswer);
            expect(q.orderedChoices[choiceIndex].id, equals(q.snapshot.correctChoiceId));
          }
        }
      }

      await db.close();
    });

    // ==============================================================
    // FIXTURE L & FINDING 2: SQLITE REFERENTIAL INTEGRITY REJECTION
    // ==============================================================
    test('Fixture L / Finding 2: SQLite strictly rejects child row with missing parent exam_code_id', () async {
      final db = await createInitializedDb(inMemoryDatabasePath);

      // Deliberately insert child with non-existent parent ID
      expect(
        db.insert(DatabaseTables.tableExamCodeQuestions, {
          'id': 'ecq_orphan_01',
          'exam_code_id': 'ec_non_existent_code_999',
          'question_id': 'q_test_01',
          'order_index': 0,
          'score': 1.0,
          'correct_display_answer': 'A',
          'snapshot_json': '{}',
        }),
        throwsA(predicate((e) => e.toString().contains('FOREIGN KEY constraint failed'))),
        reason: 'PRAGMA foreign_keys = ON must reject inserting orphan child records',
      );

      await db.close();
    });

    // ==============================================================
    // FINDING 2 REPAIR: NON-DESTRUCTIVE REPAIR STRATEGY
    // ==============================================================
    test('Finding 2 Repair: Non-destructive repair links historical orphan exam questions', () async {
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      // Create tables without FK momentarily to simulate legacy orphan state
      for (final ddl in DatabaseTables.allCreationStatements) {
        await db.execute(ddl);
      }

      // Insert parent with new canonical ID
      await db.insert(DatabaseTables.tableExamCodes, {
        'id': 'ec_paper01_101',
        'exam_paper_id': 'paper01',
        'code': '101',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Insert orphan row with old legacy format 'ec_101'
      await db.insert(DatabaseTables.tableExamCodeQuestions, {
        'id': 'ecq_legacy_01',
        'exam_code_id': 'ec_101',
        'question_id': 'q1',
        'order_index': 0,
        'score': 1.0,
        'correct_display_answer': 'A',
        'snapshot_json': '{}',
      });

      final repo = AssessmentRepository.withDb(db);
      final repairedCount = await repo.repairOrphanRecords();
      expect(repairedCount, equals(1));

      final repairedRow = await db.query(
        DatabaseTables.tableExamCodeQuestions,
        where: 'id = ?',
        whereArgs: ['ecq_legacy_01'],
      );
      expect(repairedRow.first['exam_code_id'], equals('ec_paper01_101'),
          reason: 'Orphan question must be safely relinked to its canonical parent');

      await db.close();
    });

    // ==============================================================
    // FIXTURE C & FINDING 3: NO GUESSING CORRECT ANSWERS (FAIL-CLOSED)
    // ==============================================================
    test('Fixture C / Finding 3: Correct answer fail-closed validation', () {
      // 1. Correct B -> B
      const qB = QuestionItem(
        id: 'q_b',
        prompt: 'Câu hỏi có đáp án B',
        type: QuestionType.multipleChoice,
        difficulty: QuestionDifficulty.nhanBiet,
        choices: ['Lựa chọn 1', 'Lựa chọn 2', 'Lựa chọn 3', 'Lựa chọn 4'],
        correctAnswer: 'B',
      );
      final snapB = ExamQuestionSnapshot.fromQuestionItem(qB);
      expect(snapB.correctChoiceId, equals(snapB.choices[1].id));

      // 2. Correct text matching D -> D
      const qD = QuestionItem(
        id: 'q_d',
        prompt: 'Câu hỏi khớp text đáp án D',
        type: QuestionType.multipleChoice,
        difficulty: QuestionDifficulty.nhanBiet,
        choices: ['Hà Nội', 'Đà Nẵng', 'Huế', 'Hồ Chí Minh'],
        correctAnswer: 'Hồ Chí Minh',
      );
      final snapD = ExamQuestionSnapshot.fromQuestionItem(qD);
      expect(snapD.correctChoiceId, equals(snapD.choices[3].id));

      // 3. Missing answer -> FAIL
      const qMissing = QuestionItem(
        id: 'q_missing',
        prompt: 'Câu hỏi thiếu đáp án',
        type: QuestionType.multipleChoice,
        difficulty: QuestionDifficulty.nhanBiet,
        choices: ['A1', 'B1', 'C1', 'D1'],
        correctAnswer: '',
      );
      expect(
        () => ExamQuestionSnapshot.fromQuestionItem(qMissing),
        throwsA(isA<InvalidExamQuestionException>()),
      );

      // 4. Unknown answer -> FAIL (Never silently choose A!)
      const qUnknown = QuestionItem(
        id: 'q_unknown',
        prompt: 'Câu hỏi đáp án lạ',
        type: QuestionType.multipleChoice,
        difficulty: QuestionDifficulty.nhanBiet,
        choices: ['A1', 'B1', 'C1', 'D1'],
        correctAnswer: 'XYZ_UNKNOWN',
      );
      expect(
        () => ExamQuestionSnapshot.fromQuestionItem(qUnknown),
        throwsA(isA<InvalidExamQuestionException>()),
      );

      // 5. Duplicate answer text -> FAIL if ambiguous
      const qDup = QuestionItem(
        id: 'q_dup',
        prompt: 'Câu hỏi trùng lặp phương án',
        type: QuestionType.multipleChoice,
        difficulty: QuestionDifficulty.nhanBiet,
        choices: ['Phương án X', 'Phương án Y', 'Phương án X', 'Phương án Z'],
        correctAnswer: 'Phương án X',
      );
      expect(
        () => ExamQuestionSnapshot.fromQuestionItem(qDup),
        throwsA(isA<InvalidExamQuestionException>()),
      );

      // 6. Empty choices -> FAIL
      const qEmptyChoices = QuestionItem(
        id: 'q_empty_c',
        prompt: 'Câu hỏi không có choices',
        type: QuestionType.multipleChoice,
        difficulty: QuestionDifficulty.nhanBiet,
        choices: [],
        correctAnswer: 'A',
      );
      expect(
        () => ExamQuestionSnapshot.fromQuestionItem(qEmptyChoices),
        throwsA(isA<InvalidExamQuestionException>()),
      );

      // 7. Invalid choice ID / choice count != 4 -> FAIL
      const q3Choices = QuestionItem(
        id: 'q_3c',
        prompt: 'Câu hỏi chỉ có 3 choices',
        type: QuestionType.multipleChoice,
        difficulty: QuestionDifficulty.nhanBiet,
        choices: ['C1', 'C2', 'C3'],
        correctAnswer: 'A',
      );
      expect(
        () => ExamQuestionSnapshot.fromQuestionItem(q3Choices),
        throwsA(isA<InvalidExamQuestionException>()),
      );
    });

    // ==============================================================
    // FIXTURE F & FINDINGS 4, 5: FINALIZED EXAM IMMUTABILITY & REVISIONS
    // ==============================================================
    test('Fixture F / Findings 4 & 5: Finalized exam rejects mutation and creates independent revision', () async {
      final db = await createInitializedDb(inMemoryDatabasePath);
      final repo = AssessmentRepository.withDb(db);

      // Create parent workspace project to satisfy foreign key
      await repo.saveProjectData(AssessmentProjectData(
        id: 'proj_immutability',
        name: 'Dự án bất biến',
        subject: 'Văn',
        grade: '9',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Create and finalize Revision 1
      const initialQuestion = ExamQuestionSnapshot(
        questionId: 'q_rev1',
        prompt: 'Câu hỏi gốc ban đầu',
        choices: [
          QuestionChoice(id: 'c1', text: 'A'),
          QuestionChoice(id: 'c2', text: 'B'),
          QuestionChoice(id: 'c3', text: 'C'),
          QuestionChoice(id: 'c4', text: 'D'),
        ],
        correctChoiceId: 'c1',
        correctAnswerText: 'A',
      );

      final paperRev1 = ExamPaper(
        id: 'paper_rev1',
        assessmentProjectId: 'proj_immutability',
        specificationId: 'spec_immutability',
        title: 'Đề thi bản 1',
        examCode: 'MASTER',
        durationMinutes: 45,
        totalScore: 10.0,
        revisionNumber: 1,
        isFinalized: true,
        questions: [initialQuestion],
        createdAt: DateTime.now(),
        finalizedAt: DateTime.now(),
      );
      await repo.saveExamPaper(paperRev1);

      // Attempt to mutate questions on finalized paper
      final mutatedQuestion = initialQuestion.copyWith(prompt: 'Câu hỏi đã bị sửa đổi trái phép');
      final mutatedPaper = paperRev1.copyWith(questions: [mutatedQuestion]);

      expect(
        () async => await repo.saveExamPaper(mutatedPaper),
        throwsA(isA<FinalizedExamImmutableException>()),
        reason: 'Repository must reject mutating questions on finalized exam paper',
      );

      // Verify Revision 1 remains completely byte-equivalent
      final loadedRev1 = await repo.getExamPaperById('paper_rev1');
      expect(loadedRev1!.questions.first.prompt, equals('Câu hỏi gốc ban đầu'));
      expect(loadedRev1.isFinalized, isTrue);

      // Create Revision 2 explicitly
      final paperRev2 = await repo.createNewRevision('paper_rev1');
      expect(paperRev2.revisionNumber, equals(2));
      expect(paperRev2.isFinalized, isFalse);
      expect(paperRev2.id, isNot(equals('paper_rev1')));

      // Mutate Revision 2 as draft
      final updatedRev2 = paperRev2.copyWith(questions: [mutatedQuestion]);
      await repo.saveExamPaper(updatedRev2);

      // Verify both revisions exist independently
      final allPapers = await repo.listExamPapers('proj_immutability');
      expect(allPapers.length, equals(2));

      final checkRev1 = await repo.getExamPaperById('paper_rev1');
      final checkRev2 = await repo.getExamPaperById(paperRev2.id);

      expect(checkRev1!.questions.first.prompt, equals('Câu hỏi gốc ban đầu'));
      expect(checkRev2!.questions.first.prompt, equals('Câu hỏi đã bị sửa đổi trái phép'));

      await db.close();
    });

    // ==============================================================
    // FIXTURE D & FINDING 6: MATRIX QUESTION TYPE DISTRIBUTION
    // ==============================================================
    test('Fixture D / Finding 6: Selector honors explicit questionTypeDistribution and reports deficit', () {
      const matrix = ExamMatrix(
        specificationId: 'spec_type_dist',
        cells: [
          ExamMatrixCell(
            id: 'c1',
            specificationId: 'spec_type_dist',
            objectiveId: 'OBJ_A',
            difficulty: QuestionDifficulty.nhanBiet,
            questionCount: 5,
            scorePerQuestion: 1.0,
            questionTypeDistribution: {
              QuestionType.multipleChoice: 3,
              QuestionType.essay: 2,
            },
          ),
        ],
      );

      // Bank has 5 MCQ and 0 Essay
      final bank = List.generate(
        5,
        (i) => QuestionItem(
          id: 'q_mcq_$i',
          prompt: 'MCQ $i',
          type: QuestionType.multipleChoice,
          difficulty: QuestionDifficulty.nhanBiet,
          learningObjective: 'OBJ_A',
          choices: ['A', 'B', 'C', 'D'],
          correctAnswer: 'A',
        ),
      );

      const selector = ExamQuestionSelector();
      final result = selector.selectQuestions(matrix: matrix, questionBank: bank);

      expect(result.isSuccess, isFalse);
      expect(result.shortages.length, equals(1));
      final shortage = result.shortages.first;
      expect(shortage.objectiveId, equals('OBJ_A'));
      expect(shortage.questionType, equals(QuestionType.essay));
      expect(shortage.requiredCount, equals(2));
      expect(shortage.availableCount, equals(0));
      expect(shortage.deficit, equals(2));

      // Now supply the 2 required Essays and verify selection
      final fullBank = [
        ...bank,
        const QuestionItem(
          id: 'q_essay_1',
          prompt: 'Essay 1',
          type: QuestionType.essay,
          difficulty: QuestionDifficulty.nhanBiet,
          learningObjective: 'OBJ_A',
          choices: [],
          correctAnswer: 'HD 1',
        ),
        const QuestionItem(
          id: 'q_essay_2',
          prompt: 'Essay 2',
          type: QuestionType.essay,
          difficulty: QuestionDifficulty.nhanBiet,
          learningObjective: 'OBJ_A',
          choices: [],
          correctAnswer: 'HD 2',
        ),
      ];

      final successResult = selector.selectQuestions(matrix: matrix, questionBank: fullBank);
      expect(successResult.isSuccess, isTrue);
      expect(successResult.questions.length, equals(5));

      final mcqCount = successResult.questions.where((q) => q.type == QuestionType.multipleChoice).length;
      final essayCount = successResult.questions.where((q) => q.type == QuestionType.essay).length;
      expect(mcqCount, equals(3));
      expect(essayCount, equals(2));
    });

    // ==============================================================
    // FIXTURE E & FINDING 7: OVERLAPPING MATRIX CELLS ALLOCATION
    // ==============================================================
    test('Fixture E / Finding 7: Constraint-aware allocation prevents starving specific cells', () {
      // Cell 1: ALL, Count 3, nhanBiet
      // Cell 2: OBJ_A, Count 2, nhanBiet
      const matrix = ExamMatrix(
        specificationId: 'spec_overlap',
        cells: [
          ExamMatrixCell(
            id: 'cell_all',
            specificationId: 'spec_overlap',
            objectiveId: 'ALL',
            difficulty: QuestionDifficulty.nhanBiet,
            questionCount: 3,
            scorePerQuestion: 1.0,
          ),
          ExamMatrixCell(
            id: 'cell_obja',
            specificationId: 'spec_overlap',
            objectiveId: 'OBJ_A',
            difficulty: QuestionDifficulty.nhanBiet,
            questionCount: 2,
            scorePerQuestion: 1.0,
          ),
        ],
      );

      // Bank has exactly 2 OBJ_A questions and 3 OBJ_B questions
      const bank = [
        QuestionItem(
          id: 'q_a1',
          prompt: 'OBJ A 1',
          type: QuestionType.multipleChoice,
          difficulty: QuestionDifficulty.nhanBiet,
          learningObjective: 'OBJ_A',
          choices: ['A', 'B', 'C', 'D'],
          correctAnswer: 'A',
        ),
        QuestionItem(
          id: 'q_a2',
          prompt: 'OBJ A 2',
          type: QuestionType.multipleChoice,
          difficulty: QuestionDifficulty.nhanBiet,
          learningObjective: 'OBJ_A',
          choices: ['A', 'B', 'C', 'D'],
          correctAnswer: 'B',
        ),
        QuestionItem(
          id: 'q_b1',
          prompt: 'OBJ B 1',
          type: QuestionType.multipleChoice,
          difficulty: QuestionDifficulty.nhanBiet,
          learningObjective: 'OBJ_B',
          choices: ['A', 'B', 'C', 'D'],
          correctAnswer: 'C',
        ),
        QuestionItem(
          id: 'q_b2',
          prompt: 'OBJ B 2',
          type: QuestionType.multipleChoice,
          difficulty: QuestionDifficulty.nhanBiet,
          learningObjective: 'OBJ_B',
          choices: ['A', 'B', 'C', 'D'],
          correctAnswer: 'D',
        ),
        QuestionItem(
          id: 'q_b3',
          prompt: 'OBJ B 3',
          type: QuestionType.multipleChoice,
          difficulty: QuestionDifficulty.nhanBiet,
          learningObjective: 'OBJ_B',
          choices: ['A', 'B', 'C', 'D'],
          correctAnswer: 'A',
        ),
      ];

      const selector = ExamQuestionSelector();
      final result = selector.selectQuestions(
        matrix: matrix,
        questionBank: bank,
        randomSeed: 42,
      );

      // Both cells must succeed because OBJ_A was prioritized first
      expect(result.isSuccess, isTrue,
          reason: 'Constraint-aware sorting must fulfill OBJ_A before ALL');
      expect(result.questions.length, equals(5));

      final selectedIds = result.questions.map((q) => q.questionId).toSet();
      expect(selectedIds.length, equals(5), reason: 'No question selected twice');
      expect(selectedIds.contains('q_a1'), isTrue);
      expect(selectedIds.contains('q_a2'), isTrue);
    });

    // ==============================================================
    // FIXTURE G & FINDINGS 12, 13: STALE CODES & PREFLIGHT DETECTION
    // ==============================================================
    test('Fixture G / Findings 12 & 13: Preflight detects stale codes when master paper changes', () {
      final spec = ExamSpecification(
        id: 'spec_pf',
        projectId: 'proj_pf',
        title: 'Đặc tả',
        subject: 'Văn',
        grade: '9',
        durationMinutes: 45,
        totalScore: 10.0,
        questionCount: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      const matrix = ExamMatrix(
        specificationId: 'spec_pf',
        cells: [
          ExamMatrixCell(
            id: 'c1',
            specificationId: 'spec_pf',
            objectiveId: 'ALL',
            difficulty: QuestionDifficulty.nhanBiet,
            questionCount: 1,
            scorePerQuestion: 10.0,
          ),
        ],
      );

      final masterPaperV1 = ExamPaper(
        id: 'paper_v1',
        assessmentProjectId: 'proj_pf',
        specificationId: 'spec_pf',
        title: 'Master V1',
        examCode: 'MASTER',
        durationMinutes: 45,
        totalScore: 10.0,
        questions: const [
          ExamQuestionSnapshot(
            questionId: 'q1',
            prompt: 'Prompt 1',
            choices: [
              QuestionChoice(id: 'c1', text: 'A'),
              QuestionChoice(id: 'c2', text: 'B'),
              QuestionChoice(id: 'c3', text: 'C'),
              QuestionChoice(id: 'c4', text: 'D'),
            ],
            correctChoiceId: 'c1',
            correctAnswerText: 'A',
            score: 10.0,
          ),
        ],
        createdAt: DateTime.now(),
      );

      // Generate codes for V1
      const engine = ExamCodeEngine();
      final res = engine.generateCodes(masterPaper: masterPaperV1, numberOfCodes: 1);

      // Now create a new master paper V2 (e.g. after teacher updated the exam)
      final masterPaperV2 = masterPaperV1.copyWith(id: 'paper_v2');

      const preflight = ExamPreflightValidator();
      final result = preflight.validate(
        specification: spec,
        matrix: matrix,
        masterPaper: masterPaperV2, // Validating against V2
        codes: res.codes,           // But codes still point to V1!
        answerKeys: res.answerKeys,
      );

      expect(result.canExport, isFalse);
      expect(result.isStale, isTrue);
      expect(result.blockingErrors.any((err) => err.contains('STALE_EXAM_CODE')), isTrue);
    });

    // ==============================================================
    // FIXTURES H, I, J, K: CODE VERIFIER HARDENING
    // ==============================================================
    test('Fixtures H, I, J, K: Hardened ExamCodeVerifier detects corrupt or altered codes', () {
      final master = ExamPaper(
        id: 'p_canonical',
        assessmentProjectId: 'proj_cv',
        specificationId: 'spec_cv',
        title: 'Master',
        examCode: 'MASTER',
        durationMinutes: 45,
        totalScore: 2.0,
        questions: const [
          ExamQuestionSnapshot(
            questionId: 'q1',
            prompt: 'Q1',
            choices: [
              QuestionChoice(id: 'c1', text: 'A'),
              QuestionChoice(id: 'c2', text: 'B'),
              QuestionChoice(id: 'c3', text: 'C'),
              QuestionChoice(id: 'c4', text: 'D'),
            ],
            correctChoiceId: 'c1',
            correctAnswerText: 'A',
            score: 1.0,
          ),
          ExamQuestionSnapshot(
            questionId: 'q2',
            prompt: 'Q2',
            choices: [
              QuestionChoice(id: 'c5', text: 'A'),
              QuestionChoice(id: 'c6', text: 'B'),
              QuestionChoice(id: 'c7', text: 'C'),
              QuestionChoice(id: 'c8', text: 'D'),
            ],
            correctChoiceId: 'c6',
            correctAnswerText: 'B',
            score: 1.0,
          ),
        ],
        createdAt: DateTime.now(),
      );

      const verifier = ExamCodeVerifier();

      // Fixture H: Duplicate question ID within code
      final codeDuplicateQ = ExamCode(
        id: 'ec_dup',
        examPaperId: 'p_canonical',
        code: '101',
        questions: [
          ExamCodeQuestion(
            id: 'ecq1',
            examCodeId: 'ec_dup',
            questionId: 'q1',
            orderIndex: 0,
            score: 1.0,
            correctDisplayAnswer: 'A',
            snapshot: master.questions[0],
          ),
          ExamCodeQuestion(
            id: 'ecq2',
            examCodeId: 'ec_dup',
            questionId: 'q1', // Duplicate Q1!
            orderIndex: 1,
            score: 1.0,
            correctDisplayAnswer: 'A',
            snapshot: master.questions[0],
          ),
        ],
        createdAt: DateTime.now(),
      );
      final resH = verifier.verifyCodes([codeDuplicateQ], canonicalMaster: master);
      expect(resH.isEquivalent, isFalse);
      expect(resH.mismatches.any((m) => m.contains('DUPLICATE_QUESTION_IN_CODE')), isTrue);

      // Fixture I: Code missing one question
      final codeMissingQ = ExamCode(
        id: 'ec_missing',
        examPaperId: 'p_canonical',
        code: '102',
        questions: [
          ExamCodeQuestion(
            id: 'ecq1',
            examCodeId: 'ec_missing',
            questionId: 'q1',
            orderIndex: 0,
            score: 1.0,
            correctDisplayAnswer: 'A',
            snapshot: master.questions[0],
          ),
        ],
        createdAt: DateTime.now(),
      );
      final resI = verifier.verifyCodes([codeMissingQ], canonicalMaster: master);
      expect(resI.isEquivalent, isFalse);
      expect(resI.mismatches.any((m) => m.contains('QUESTION_COUNT_MISMATCH')), isTrue);

      // Fixture K: Correct answer remapped incorrectly (wrong letter)
      final codeWrongAnswer = ExamCode(
        id: 'ec_wrong_ans',
        examPaperId: 'p_canonical',
        code: '103',
        questions: [
          ExamCodeQuestion(
            id: 'ecq1',
            examCodeId: 'ec_wrong_ans',
            questionId: 'q1',
            orderIndex: 0,
            score: 1.0,
            correctDisplayAnswer: 'D', // c1 is at index 0 ('A'), but letter is 'D'!
            choiceOrder: ['c1', 'c2', 'c3', 'c4'],
            snapshot: master.questions[0],
          ),
          ExamCodeQuestion(
            id: 'ecq2',
            examCodeId: 'ec_wrong_ans',
            questionId: 'q2',
            orderIndex: 1,
            score: 1.0,
            correctDisplayAnswer: 'B',
            choiceOrder: ['c5', 'c6', 'c7', 'c8'],
            snapshot: master.questions[1],
          ),
        ],
        createdAt: DateTime.now(),
      );
      final resK = verifier.verifyCodes([codeWrongAnswer], canonicalMaster: master);
      expect(resK.isEquivalent, isFalse);
      expect(resK.mismatches.any((m) => m.contains('SEMANTIC_ANSWER_REMAP_FAILURE')), isTrue);
    });

    // ==============================================================
    // FIXTURE M & FINDING 14: PROJECT SWITCH ISOLATION
    // ==============================================================
    test('Fixture M / Finding 14: Switching Project A -> Project B -> Project A guarantees full state isolation', () async {
      final db = await createInitializedDb(inMemoryDatabasePath);
      final repo = AssessmentRepository.withDb(db);

      // Setup Project A: 20 questions, 10.0 points
      final projA = AssessmentProjectData(
        id: 'proj_A',
        name: 'Project A',
        subject: 'Toán',
        grade: '9',
        totalScore: 10.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.saveProjectData(projA);

      final paperA = ExamPaper(
        id: 'paper_A',
        assessmentProjectId: 'proj_A',
        specificationId: 'spec_A',
        title: 'Đề Toán A',
        examCode: 'MASTER_A',
        durationMinutes: 45,
        totalScore: 10.0,
        questions: List.generate(
          20,
          (i) => ExamQuestionSnapshot(
            questionId: 'qa_$i',
            prompt: 'Toán $i',
            choices: [
              const QuestionChoice(id: 'c1', text: '1'),
              const QuestionChoice(id: 'c2', text: '2'),
              const QuestionChoice(id: 'c3', text: '3'),
              const QuestionChoice(id: 'c4', text: '4'),
            ],
            correctChoiceId: 'c1',
            correctAnswerText: 'A',
            score: 0.5,
          ),
        ),
        createdAt: DateTime.now(),
      );
      await repo.saveExamPaper(paperA);

      // Setup Project B: 10 questions, 5.0 points
      final projB = AssessmentProjectData(
        id: 'proj_B',
        name: 'Project B',
        subject: 'Lý',
        grade: '9',
        totalScore: 5.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.saveProjectData(projB);

      final paperB = ExamPaper(
        id: 'paper_B',
        assessmentProjectId: 'proj_B',
        specificationId: 'spec_B',
        title: 'Đề Lý B',
        examCode: 'MASTER_B',
        durationMinutes: 45,
        totalScore: 5.0,
        questions: List.generate(
          10,
          (i) => ExamQuestionSnapshot(
            questionId: 'qb_$i',
            prompt: 'Lý $i',
            choices: [
              const QuestionChoice(id: 'c1', text: '1'),
              const QuestionChoice(id: 'c2', text: '2'),
              const QuestionChoice(id: 'c3', text: '3'),
              const QuestionChoice(id: 'c4', text: '4'),
            ],
            correctChoiceId: 'c2',
            correctAnswerText: 'B',
            score: 0.5,
          ),
        ),
        createdAt: DateTime.now(),
      );
      await repo.saveExamPaper(paperB);

      // Switch A -> B -> A
      final loadA1 = await repo.getExamPaper('proj_A');
      expect(loadA1!.title, equals('Đề Toán A'));
      expect(loadA1.questions.length, equals(20));

      final loadB = await repo.getExamPaper('proj_B');
      expect(loadB!.title, equals('Đề Lý B'));
      expect(loadB.questions.length, equals(10));

      final loadA2 = await repo.getExamPaper('proj_A');
      expect(loadA2!.title, equals('Đề Toán A'));
      expect(loadA2.questions.length, equals(20));
      expect(loadA2.questions.any((q) => q.prompt.contains('Lý')), isFalse);

      await db.close();
    });

    // ==============================================================
    // FIXTURE B: 100-QUESTION EXAM STRESS TEST
    // ==============================================================
    test('Fixture B: 100-question exam generation, verification, and persistence', () async {
      final db = await createInitializedDb(inMemoryDatabasePath);
      final repo = AssessmentRepository.withDb(db);

      final project = AssessmentProjectData(
        id: 'proj_100q',
        name: 'Đề 100 câu',
        subject: 'Tiếng Anh',
        grade: '12',
        totalScore: 10.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.saveProjectData(project);

      final questions = List.generate(
        100,
        (i) => ExamQuestionSnapshot(
          questionId: 'q100_$i',
          prompt: 'English question prompt #$i',
          choices: [
            QuestionChoice(id: 'c1_$i', text: 'Choice A $i'),
            QuestionChoice(id: 'c2_$i', text: 'Choice B $i'),
            QuestionChoice(id: 'c3_$i', text: 'Choice C $i'),
            QuestionChoice(id: 'c4_$i', text: 'Choice D $i'),
          ],
          correctChoiceId: 'c1_$i',
          correctAnswerText: 'A',
          score: 0.10,
        ),
      );

      final masterPaper = ExamPaper(
        id: 'paper_100q',
        assessmentProjectId: 'proj_100q',
        specificationId: 'spec_100q',
        title: 'Master 100 câu',
        examCode: 'MASTER',
        durationMinutes: 90,
        totalScore: 10.0,
        questions: questions,
        createdAt: DateTime.now(),
      );
      await repo.saveExamPaper(masterPaper);

      const engine = ExamCodeEngine();
      final res = engine.generateCodes(
        masterPaper: masterPaper,
        numberOfCodes: 4,
        startingCode: 201,
      );

      expect(res.codes.length, equals(4));
      for (final code in res.codes) {
        expect(code.questions.length, equals(100));
      }

      const verifier = ExamCodeVerifier();
      final vRes = verifier.verifyCodes(res.codes, canonicalMaster: masterPaper);
      expect(vRes.isEquivalent, isTrue);

      await repo.saveExamCodes(res.codes);
      final loaded = await repo.getExamCodes(masterPaper.id);
      expect(loaded.length, equals(4));
      expect(loaded.first.questions.length, equals(100));

      await db.close();
    });

    // ==============================================================
    // FIXTURE O: CORRUPT SNAPSHOT JSON RESILIENCE
    // ==============================================================
    test('Fixture O: Corrupt snapshot JSON in database is safely handled without crash', () async {
      final db = await createInitializedDb(inMemoryDatabasePath);
      final repo = AssessmentRepository.withDb(db);

      // Create parent project to satisfy foreign key constraint
      await repo.saveProjectData(AssessmentProjectData(
        id: 'proj_corrupt',
        name: 'Dự án lỗi',
        subject: 'Toán',
        grade: '9',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Insert paper
      await db.insert(DatabaseTables.tableExamPapers, {
        'id': 'p_corrupt',
        'project_id': 'proj_corrupt',
        'specification_id': 'spec_corrupt',
        'title': 'Paper with corrupt question',
        'exam_code': 'MASTER',
        'duration_minutes': 45,
        'total_score': 10.0,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Insert corrupt JSON row
      await db.insert(DatabaseTables.tableExamPaperQuestions, {
        'id': 'epq_bad',
        'exam_paper_id': 'p_corrupt',
        'question_id': 'q_corrupt',
        'order_index': 0,
        'score': 1.0,
        'section_index': 0,
        'snapshot_json': 'INVALID_NON_JSON_STRING{{{',
      });

      final loaded = await repo.getExamPaperById('p_corrupt');
      expect(loaded, isNotNull);
      // Corrupted question is ignored gracefully rather than crashing the repository
      expect(loaded!.questions, isEmpty);

      await db.close();
    });

    // ==============================================================
    // FIXTURE 18: DOCX ARCHIVE INTEGRITY & STUDENT LEAK AUDIT
    // ==============================================================
    test('Section 18: Exported DOCX contains valid OpenXML structure and NO teacher answers in student exam', () async {
      final code = ExamCode(
        id: 'ec_test_101',
        examPaperId: 'paper_test',
        code: '101',
        questions: const [
          ExamCodeQuestion(
            id: 'ecq1',
            examCodeId: 'ec_test_101',
            questionId: 'q1',
            orderIndex: 0,
            score: 0.25,
            correctDisplayAnswer: 'C',
            choiceOrder: ['c1', 'c2', 'c3', 'c4'],
            snapshot: ExamQuestionSnapshot(
              questionId: 'q1',
              prompt: 'Nội dung câu hỏi đề thi bí mật',
              choices: [
                QuestionChoice(id: 'c1', text: 'Đáp án sai 1'),
                QuestionChoice(id: 'c2', text: 'Đáp án sai 2'),
                QuestionChoice(id: 'c3', text: 'Đáp án ĐÚNG bí mật'),
                QuestionChoice(id: 'c4', text: 'Đáp án sai 3'),
              ],
              correctChoiceId: 'c3',
              correctAnswerText: 'C',
              explanation: 'Lời giải chi tiết chỉ dành cho giáo viên',
            ),
          ),
        ],
        createdAt: DateTime.now(),
      );

      final exportPath = p.join(tempDir.path, 'De_101.docx');
      await AssessmentDocxExporter.exportExamCode(
        examCode: code,
        headerConfig: const ExamHeaderConfig(),
        outputPath: exportPath,
      );

      expect(File(exportPath).existsSync(), isTrue);

      // Inspect DOCX as ZIP Archive
      final bytes = File(exportPath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);

      final fileNames = archive.files.map((f) => f.name).toSet();
      expect(fileNames.contains('[Content_Types].xml'), isTrue);
      expect(fileNames.contains('_rels/.rels'), isTrue);
      expect(fileNames.contains('word/document.xml'), isTrue);
      expect(fileNames.contains('word/styles.xml'), isTrue);

      // Extract visible document text from document.xml
      final docXmlFile = archive.files.firstWhere((f) => f.name == 'word/document.xml');
      final docXmlContent = utf8.decode(docXmlFile.content as List<int>);

      // Verify prompt and choices are present
      expect(docXmlContent.contains('Nội dung câu hỏi đề thi bí mật'), isTrue);
      expect(docXmlContent.contains('Đáp án ĐÚNG bí mật'), isTrue);

      // CRITICAL LEAK AUDIT: Ensure teacher explanation and correctChoiceId are NEVER in student exam!
      expect(docXmlContent.contains('Lời giải chi tiết chỉ dành cho giáo viên'), isFalse,
          reason: 'Teacher explanation must not leak into student exam DOCX');
      expect(docXmlContent.contains('c3'), isFalse,
          reason: 'Internal correct choice IDs must not leak');
    });

    // ==============================================================
    // FIXTURE 17 & 20: EXPORT PACKAGE 12 FILES & ARTIFACT METADATA
    // ==============================================================
    test('Section 17 & 20: exportPackage generates exact 12 files for 4 codes and registers exact metadata', () async {
      final db = await createInitializedDb(inMemoryDatabasePath);
      final repo = AssessmentRepository.withDb(db);
      final projectRepo = WorkspaceProjectRepository.withDb(db);

      final project = AssessmentProjectData(
        id: 'proj_export_test',
        name: 'Kỳ thi HKI',
        subject: 'Ngữ văn',
        grade: '9',
        totalScore: 10.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.saveProjectData(project);

      final spec = ExamSpecification(
        id: 'spec_exp',
        projectId: 'proj_export_test',
        title: 'Đặc tả',
        subject: 'Ngữ văn',
        grade: '9',
        durationMinutes: 45,
        totalScore: 10.0,
        questionCount: 4,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.saveSpecification(spec);

      const matrix = ExamMatrix(
        specificationId: 'spec_exp',
        cells: [
          ExamMatrixCell(
            id: 'c1',
            specificationId: 'spec_exp',
            objectiveId: 'ALL',
            difficulty: QuestionDifficulty.nhanBiet,
            questionCount: 4,
            scorePerQuestion: 2.5,
          ),
        ],
      );
      await repo.saveMatrix(matrix);

      final master = ExamPaper(
        id: 'paper_exp_master',
        assessmentProjectId: 'proj_export_test',
        specificationId: 'spec_exp',
        title: 'Đề gốc xuất tệp',
        examCode: 'MASTER',
        durationMinutes: 45,
        totalScore: 10.0,
        questions: List.generate(
          4,
          (i) => ExamQuestionSnapshot(
            questionId: 'q_$i',
            prompt: 'Câu hỏi số $i',
            choices: [
              QuestionChoice(id: 'c1_$i', text: 'A'),
              QuestionChoice(id: 'c2_$i', text: 'B'),
              QuestionChoice(id: 'c3_$i', text: 'C'),
              QuestionChoice(id: 'c4_$i', text: 'D'),
            ],
            correctChoiceId: 'c1_$i',
            correctAnswerText: 'A',
            score: 2.5,
          ),
        ),
        createdAt: DateTime.now(),
      );
      await repo.saveExamPaper(master);

      const engine = ExamCodeEngine();
      final res = engine.generateCodes(masterPaper: master, numberOfCodes: 4, startingCode: 101);
      await repo.saveExamCodes(res.codes);

      final exportResult = await AssessmentDocxExporter.exportPackage(
        project: project,
        specification: spec,
        matrix: matrix,
        objectives: const [LearningObjective(id: 'ALL', projectId: 'proj_export_test', code: 'ALL', description: 'Chung')],
        masterPaper: master,
        codes: res.codes,
        answerKeys: res.answerKeys,
        baseExportDir: tempDir.path,
        projectRepository: projectRepo,
      );

      expect(exportResult.successful, isTrue);
      // Expected 12 files: 1 matrix, 1 spec, 1 master, 4 student papers, 4 answer keys, 1 summary
      expect(exportResult.successfulFiles.length, equals(12));

      final exportedDir = Directory(exportResult.exportDirectory);
      final filesOnDisk = exportedDir.listSync().whereType<File>().map((f) => p.basename(f.path)).toList();
      expect(filesOnDisk.length, equals(12));

      expect(filesOnDisk.contains('01_Ma_tran_de.docx'), isTrue);
      expect(filesOnDisk.contains('02_Ban_dac_ta.docx'), isTrue);
      expect(filesOnDisk.contains('03_De_Goc_MASTER.docx'), isTrue);
      expect(filesOnDisk.contains('De_101.docx'), isTrue);
      expect(filesOnDisk.contains('De_102.docx'), isTrue);
      expect(filesOnDisk.contains('De_103.docx'), isTrue);
      expect(filesOnDisk.contains('De_104.docx'), isTrue);
      expect(filesOnDisk.contains('Dap_an_101.docx'), isTrue);
      expect(filesOnDisk.contains('Dap_an_102.docx'), isTrue);
      expect(filesOnDisk.contains('Dap_an_103.docx'), isTrue);
      expect(filesOnDisk.contains('Dap_an_104.docx'), isTrue);
      expect(filesOnDisk.contains('Bang_Dap_an_Tong_hop.docx'), isTrue);

      // Verify Artifact Metadata (Section 20)
      final artifacts = await projectRepo.listArtifacts(project.id);
      expect(artifacts.length, equals(12));

      final student101Art = artifacts.firstWhere((a) => a.filePath!.endsWith('De_101.docx'));
      final meta101 = jsonDecode(student101Art.metadataJson!) as Map<String, dynamic>;
      expect(meta101['examCode'], equals('101'), reason: 'Artifact metadata must record actual student code');
      expect(meta101['masterPaperId'], equals(master.id));
      expect(meta101['revisionNumber'], equals(master.revisionNumber));

      await db.close();
    });
  });
}
