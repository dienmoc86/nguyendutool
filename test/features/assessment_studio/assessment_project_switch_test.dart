import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/database/database_tables.dart';
import 'package:nguyendu_tool/features/assessment_studio/data/assessment_repository.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/assessment_project_data.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/exam_code.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/exam_matrix.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/exam_paper.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/exam_question_snapshot.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/exam_specification.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/question_choice.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/question_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Assessment Studio - Project Switch Isolation Tests (Section 92)', () {
    late Database db;
    late AssessmentRepository repository;

    const String projectAId = 'proj_A';
    const String projectBId = 'proj_B';

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);

      // Create necessary tables
      await db.execute('''
        CREATE TABLE ${DatabaseTables.tableWorkspaceProjects} (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          status TEXT NOT NULL,
          metadata_json TEXT
        );
      ''');

      await db.execute(DatabaseTables.createExamSpecificationsTable);
      await db.execute(DatabaseTables.createExamMatrixCellsTable);
      await db.execute(DatabaseTables.createExamPapersTable);
      await db.execute(DatabaseTables.createExamPaperQuestionsTable);
      await db.execute(DatabaseTables.createExamCodesTable);
      await db.execute(DatabaseTables.createExamCodeQuestionsTable);

      repository = AssessmentRepository.withDb(db);

      // 1. Setup Project A: Ngữ văn 9, 10 câu, 45 phút
      final projectA = AssessmentProjectData(
        id: projectAId,
        name: 'Đề kiểm tra Ngữ văn 9',
        subject: 'Ngữ văn',
        grade: '9',
        durationMinutes: 45,
        totalScore: 10.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repository.saveProjectData(projectA);

      final specA = ExamSpecification(
        id: 'spec_A',
        projectId: projectAId,
        title: 'Đặc tả môn Văn',
        subject: 'Ngữ văn',
        grade: '9',
        durationMinutes: 45,
        totalScore: 10.0,
        questionCount: 10,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repository.saveSpecification(specA);

      const matrixA = ExamMatrix(
        specificationId: 'spec_A',
        cells: [
          ExamMatrixCell(
            id: 'c_A1',
            specificationId: 'spec_A',
            objectiveId: 'obj_A',
            difficulty: QuestionDifficulty.nhanBiet,
            questionCount: 10,
            scorePerQuestion: 1.0,
          ),
        ],
      );
      await repository.saveMatrix(matrixA);

      final paperA = ExamPaper(
        id: 'paper_A',
        assessmentProjectId: projectAId,
        specificationId: 'spec_A',
        title: 'Đề thi Văn',
        examCode: 'MASTER_A',
        durationMinutes: 45,
        totalScore: 10.0,
        questions: const [
          ExamQuestionSnapshot(
            questionId: 'q_van_1',
            prompt: 'Câu hỏi Văn số 1',
            choices: [QuestionChoice(id: 'c1', text: 'Văn A'), QuestionChoice(id: 'c2', text: 'Văn B')],
            correctChoiceId: 'c1',
            correctAnswerText: 'A',
          ),
        ],
        createdAt: DateTime.now(),
      );
      await repository.saveExamPaper(paperA);

      final codeA = ExamCode(
        id: 'code_A_101',
        examPaperId: 'paper_A',
        code: '101',
        questions: [],
        createdAt: DateTime.now(),
      );
      await repository.saveExamCodes([codeA]);

      // 2. Setup Project B: Lịch sử 9, 20 câu, 90 phút
      final projectB = AssessmentProjectData(
        id: projectBId,
        name: 'Đề thi Lịch sử 9',
        subject: 'Lịch sử',
        grade: '9',
        durationMinutes: 90,
        totalScore: 10.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repository.saveProjectData(projectB);

      final specB = ExamSpecification(
        id: 'spec_B',
        projectId: projectBId,
        title: 'Đặc tả môn Sử',
        subject: 'Lịch sử',
        grade: '9',
        durationMinutes: 90,
        totalScore: 10.0,
        questionCount: 20,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repository.saveSpecification(specB);

      const matrixB = ExamMatrix(
        specificationId: 'spec_B',
        cells: [
          ExamMatrixCell(
            id: 'c_B1',
            specificationId: 'spec_B',
            objectiveId: 'obj_B',
            difficulty: QuestionDifficulty.thongHieu,
            questionCount: 20,
            scorePerQuestion: 0.5,
          ),
        ],
      );
      await repository.saveMatrix(matrixB);

      final paperB = ExamPaper(
        id: 'paper_B',
        assessmentProjectId: projectBId,
        specificationId: 'spec_B',
        title: 'Đề thi Sử',
        examCode: 'MASTER_B',
        durationMinutes: 90,
        totalScore: 10.0,
        questions: const [
          ExamQuestionSnapshot(
            questionId: 'q_su_1',
            prompt: 'Câu hỏi Sử số 1',
            choices: [QuestionChoice(id: 'c1', text: 'Sử A'), QuestionChoice(id: 'c2', text: 'Sử B')],
            correctChoiceId: 'c2',
            correctAnswerText: 'B',
          ),
        ],
        createdAt: DateTime.now(),
      );
      await repository.saveExamPaper(paperB);

      final codeB = ExamCode(
        id: 'code_B_201',
        examPaperId: 'paper_B',
        code: '201',
        questions: [],
        createdAt: DateTime.now(),
      );
      await repository.saveExamCodes([codeB]);
    });

    tearDown(() async {
      await db.close();
    });

    test('Switching from Project A -> Project B -> Project A guarantees ZERO state leakage (Section 92)', () async {
      // 1. Load Project A
      final loadedProjA = await repository.getProjectData(projectAId);
      final loadedSpecA = await repository.getSpecification(projectAId);
      final loadedMatrixA = await repository.getMatrix(loadedSpecA!.id);
      final loadedPaperA = await repository.getExamPaper(projectAId);
      final loadedCodesA = await repository.getExamCodes(loadedPaperA!.id);

      expect(loadedProjA!.subject, equals('Ngữ văn'));
      expect(loadedSpecA.title, equals('Đặc tả môn Văn'));
      expect(loadedMatrixA!.cells.first.objectiveId, equals('obj_A'));
      expect(loadedPaperA.examCode, equals('MASTER_A'));
      expect(loadedPaperA.questions.first.prompt, equals('Câu hỏi Văn số 1'));
      expect(loadedCodesA.first.code, equals('101'));

      // 2. Switch to Project B
      final loadedProjB = await repository.getProjectData(projectBId);
      final loadedSpecB = await repository.getSpecification(projectBId);
      final loadedMatrixB = await repository.getMatrix(loadedSpecB!.id);
      final loadedPaperB = await repository.getExamPaper(projectBId);
      final loadedCodesB = await repository.getExamCodes(loadedPaperB!.id);

      expect(loadedProjB!.subject, equals('Lịch sử'));
      expect(loadedSpecB.title, equals('Đặc tả môn Sử'));
      expect(loadedMatrixB!.cells.first.objectiveId, equals('obj_B'));
      expect(loadedPaperB.examCode, equals('MASTER_B'));
      expect(loadedPaperB.questions.first.prompt, equals('Câu hỏi Sử số 1'));
      expect(loadedCodesB.first.code, equals('201'));

      // 3. Switch back to Project A and verify NO leakage from Project B
      final reloadedProjA = await repository.getProjectData(projectAId);
      final reloadedSpecA = await repository.getSpecification(projectAId);
      final reloadedMatrixA = await repository.getMatrix(reloadedSpecA!.id);
      final reloadedPaperA = await repository.getExamPaper(projectAId);
      final reloadedCodesA = await repository.getExamCodes(reloadedPaperA!.id);

      expect(reloadedProjA!.subject, equals('Ngữ văn'));
      expect(reloadedSpecA.title, equals('Đặc tả môn Văn'));
      expect(reloadedMatrixA!.cells.first.objectiveId, equals('obj_A'));
      expect(reloadedPaperA.examCode, equals('MASTER_A'));
      expect(reloadedPaperA.questions.first.prompt, equals('Câu hỏi Văn số 1'));
      expect(reloadedCodesA.first.code, equals('101'));

      // Strict non-cross contamination check
      expect(reloadedSpecA.title, isNot(contains('Sử')));
      expect(reloadedPaperA.questions.first.prompt, isNot(contains('Sử')));
      expect(reloadedCodesA.any((c) => c.code == '201'), isFalse);
    });
  });
}
