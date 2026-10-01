import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/database/database_tables.dart';
import 'package:nguyendu_tool/features/assessment_studio/data/assessment_repository.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/exam_paper.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/exam_question_snapshot.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/question_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Assessment Studio - Snapshot Immutability Tests (Section 8, 30, 86)', () {
    late Database db;
    late AssessmentRepository repository;
    const String projectId = 'proj_immutability_test';
    const String paperId = 'paper_immutability_master';

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);

      // Create all production tables
      for (final ddl in DatabaseTables.allCreationStatements) {
        await db.execute(ddl);
      }

      repository = AssessmentRepository.withDb(db);

      // Create parent workspace project
      await db.insert(
        DatabaseTables.tableWorkspaceProjects,
        {
          'id': projectId,
          'type': 'assessment',
          'name': 'Test Immutability Project',
          'status': 'active',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Finalized ExamPaper remains immutable even when source QuestionItem in bank is mutated (Section 86)', () async {
      const qId = 'q_source_01';

      // 1. Create a QuestionItem in question bank
      const originalItem = QuestionItem(
        id: qId,
        setId: 'set_$projectId',
        prompt: 'Nội dung gốc: Nhân vật Vũ Nương trong tác phẩm nào?',
        type: QuestionType.multipleChoice,
        difficulty: QuestionDifficulty.nhanBiet,
        choices: [
          'Chuyện người con gái Nam Xương',
          'Truyện Kiều',
          'Đồng chí',
          'Làng',
        ],
        correctAnswer: 'A',
      );
      await repository.saveQuestion(originalItem, projectId);

      // 2. Snapshot the question into ExamQuestionSnapshot
      final snapshot = ExamQuestionSnapshot.fromQuestionItem(
        originalItem,
        score: 1.0,
        sectionIndex: 0,
      );

      // 3. Create and finalize Master ExamPaper
      final masterPaper = ExamPaper(
        id: paperId,
        assessmentProjectId: projectId,
        specificationId: 'spec_01',
        title: 'Đề thi chính thức môn Ngữ văn 9',
        examCode: 'MASTER',
        questions: [snapshot],
        durationMinutes: 45,
        totalScore: 10.0,
        createdAt: DateTime.now(),
        finalizedAt: DateTime.now(),
        revisionNumber: 1,
      );

      await repository.saveExamPaper(masterPaper);
      await repository.finalizeExamPaper(paperId);

      // 4. NOW: Mutate the source question in the question bank (simulating user editing it later)
      final mutatedItem = originalItem.copyWith(
        prompt: 'Nội dung ĐÃ BỊ SỬA ĐỔI: Ai là tác giả bài thơ Ánh trăng?',
        choices: const ['Nguyễn Duy', 'Chính Hữu', 'Huy Cận', 'Xuân Quỳnh'],
        correctAnswer: 'A',
      );
      await repository.saveQuestion(mutatedItem, projectId);

      // Verify the question bank itself actually changed
      final bankQuestions = await repository.getQuestionBank(projectId);
      expect(bankQuestions.first.prompt, contains('Nội dung ĐÃ BỊ SỬA ĐỔI'));

      // 5. Reload the finalized exam paper from database
      final reloadedPaper = await repository.getExamPaper(projectId);

      // 6. VERIFY: The finalized exam content remains 100% UNCHANGED and preserved!
      expect(reloadedPaper, isNotNull);
      expect(reloadedPaper!.isFinalized, isTrue);
      expect(reloadedPaper.questions.length, equals(1));

      final paperQuestion = reloadedPaper.questions.first;
      expect(paperQuestion.prompt, equals('Nội dung gốc: Nhân vật Vũ Nương trong tác phẩm nào?'));
      expect(paperQuestion.choices[0].text, equals('Chuyện người con gái Nam Xương'));
      expect(paperQuestion.prompt, isNot(contains('Nội dung ĐÃ BỊ SỬA ĐỔI')));
    });
  });
}
