import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/database/app_database.dart';
import 'package:nguyendu_tool/core/projects/data/workspace_project_repository.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/assessment_project_data.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/exam_matrix.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/exam_paper.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/exam_question_snapshot.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/exam_specification.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/question_choice.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/services/exam_code_engine.dart';
import 'package:nguyendu_tool/features/assessment_studio/infrastructure/assessment_docx_exporter.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/learning_objective.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/question_models.dart';
import 'package:nguyendu_tool/core/projects/domain/project_type.dart';
import 'package:nguyendu_tool/core/projects/domain/workspace_project.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Assessment Studio - Full Exam Package Export Tests (Section 50, 89)', () {
    late Directory tempDir;
    late AppDatabase appDatabase;
    late WorkspaceProjectRepository projectRepository;

    const String projectId = 'proj_package_fixture';
    const String specId = 'spec_package_fixture';

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('assessment_package_test_');
      appDatabase = AppDatabase(inMemory: true);
      await appDatabase.init();
      projectRepository = WorkspaceProjectRepository(appDatabase: appDatabase);

      // Create parent workspace project to satisfy foreign key constraints
      await projectRepository.createProject(
        WorkspaceProject(
          id: projectId,
          type: ProjectType.assessment,
          name: 'Đề kiểm tra cuối kỳ I',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test('Section 89 Fixture: Ngữ văn 9, 20 questions, 10-point scale, 4 exam codes exported and verified', () async {
      // 1. Objectives (GDPT 2018)
      final objectives = [
        const LearningObjective(
          id: 'obj_1',
          projectId: projectId,
          code: 'NL_DOC_01',
          description: 'Nhận biết các yếu tố thể loại văn bản truyện ngắn',
          category: 'Đọc hiểu',
        ),
        const LearningObjective(
          id: 'obj_2',
          projectId: projectId,
          code: 'NL_DOC_02',
          description: 'Thông hiểu nội dung, nghệ thuật và ý nghĩa của văn bản',
          category: 'Đọc hiểu',
        ),
        const LearningObjective(
          id: 'obj_3',
          projectId: projectId,
          code: 'NL_TIENG_VIET',
          description: 'Vận dụng kiến thức tiếng Việt thực hành giao tiếp',
          category: 'Tiếng Việt',
        ),
        const LearningObjective(
          id: 'obj_4',
          projectId: projectId,
          code: 'NL_VIET',
          description: 'Viết bài văn nghị luận xã hội về một vấn đề đời sống',
          category: 'Viết',
        ),
      ];

      // 2. Specification: 20 questions, 10.0 points, 90 minutes
      final spec = ExamSpecification(
        id: specId,
        projectId: projectId,
        title: 'Đề kiểm tra cuối kỳ I - Ngữ văn 9',
        subject: 'Ngữ văn',
        grade: '9',
        durationMinutes: 90,
        totalScore: 10.0,
        questionCount: 20,
        instructions: 'Thí sinh làm bài trên giấy thi. Không sử dụng tài liệu.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 3. Matrix: 20 questions = 10.0 points
      // 16 MCQ (0.25 pt each = 4.0 pt) + 2 Short Answer (1.0 pt each = 2.0 pt) + 2 Essay (2.0 pt each = 4.0 pt)
      final matrixCells = [
        const ExamMatrixCell(
          id: 'c1',
          specificationId: specId,
          objectiveId: 'obj_1',
          difficulty: QuestionDifficulty.nhanBiet,
          questionCount: 8,
          scorePerQuestion: 0.25, // 2.0 pt
        ),
        const ExamMatrixCell(
          id: 'c2',
          specificationId: specId,
          objectiveId: 'obj_2',
          difficulty: QuestionDifficulty.thongHieu,
          questionCount: 8,
          scorePerQuestion: 0.25, // 2.0 pt
        ),
        const ExamMatrixCell(
          id: 'c3',
          specificationId: specId,
          objectiveId: 'obj_3',
          difficulty: QuestionDifficulty.vanDung,
          questionCount: 2,
          scorePerQuestion: 1.0, // 2.0 pt
        ),
        const ExamMatrixCell(
          id: 'c4',
          specificationId: specId,
          objectiveId: 'obj_4',
          difficulty: QuestionDifficulty.vanDungCao,
          questionCount: 2,
          scorePerQuestion: 2.0, // 4.0 pt
        ),
      ];

      final matrix = ExamMatrix(
        specificationId: specId,
        cells: matrixCells,
      );

      expect(matrix.totalQuestionCount, equals(20));
      expect(matrix.totalScore, equals(10.0));

      // 4. Construct 20 snapshot questions
      final List<ExamQuestionSnapshot> questions = [];
      // 16 MCQ questions
      for (int i = 1; i <= 16; i++) {
        final objId = i <= 8 ? 'obj_1' : 'obj_2';
        final diff = i <= 8 ? QuestionDifficulty.nhanBiet : QuestionDifficulty.thongHieu;
        questions.add(
          ExamQuestionSnapshot(
            questionId: 'q_mcq_$i',
            prompt: 'Câu hỏi trắc nghiệm số $i về truyện ngắn hiện đại Việt Nam?',
            choices: [
              QuestionChoice(id: 'c_${i}_1', text: 'Phương án A cho câu $i'),
              QuestionChoice(id: 'c_${i}_2', text: 'Phương án B cho câu $i'),
              QuestionChoice(id: 'c_${i}_3', text: 'Phương án C cho câu $i'),
              QuestionChoice(id: 'c_${i}_4', text: 'Phương án D cho câu $i'),
            ],
            correctChoiceId: 'c_${i}_1',
            correctAnswerText: 'A',
            type: QuestionType.multipleChoice,
            difficulty: diff,
            objectiveId: objId,
            score: 0.25,
            sectionIndex: 0,
          ),
        );
      }

      // 2 Short Answer questions
      for (int i = 1; i <= 2; i++) {
        questions.add(
          ExamQuestionSnapshot(
            questionId: 'q_short_$i',
            prompt: 'Câu hỏi ngắn số $i: Xác định thành phần biệt lập trong câu sau...',
            choices: const [],
            correctChoiceId: '',
            correctAnswerText: 'Thành phần phụ chú / tình thái',
            type: QuestionType.shortAnswer,
            difficulty: QuestionDifficulty.vanDung,
            objectiveId: 'obj_3',
            score: 1.0,
            sectionIndex: 1,
          ),
        );
      }

      // 2 Essay questions
      for (int i = 1; i <= 2; i++) {
        questions.add(
          ExamQuestionSnapshot(
            questionId: 'q_essay_$i',
            prompt: 'Câu hỏi tự luận $i: Viết bài văn nghị luận xã hội về ý chí, nghị lực sống...',
            choices: const [],
            correctChoiceId: '',
            correctAnswerText: 'Dàn ý và thang điểm tự luận số $i',
            type: QuestionType.essay,
            difficulty: QuestionDifficulty.vanDungCao,
            objectiveId: 'obj_4',
            score: 2.0,
            sectionIndex: 2,
          ),
        );
      }

      expect(questions.length, equals(20));

      final masterPaper = ExamPaper(
        id: 'paper_fixture_master',
        assessmentProjectId: projectId,
        specificationId: specId,
        title: 'Đề thi cuối kỳ I Ngữ văn 9',
        examCode: 'MASTER',
        questions: questions,
        durationMinutes: 90,
        totalScore: 10.0,
        createdAt: DateTime.now(),
        finalizedAt: DateTime.now(),
      );

      final projectData = AssessmentProjectData(
        id: projectId,
        name: 'Đề kiểm tra cuối kỳ I',
        subject: 'Ngữ văn',
        grade: '9',
        examType: ExamType.finalExam,
        durationMinutes: 90,
        totalScore: 10.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        headerConfig: const ExamHeaderConfig(
          schoolName: 'TRƯỜNG THCS NGUYỄN DU',
          examTitle: 'KIỂM TRA CUỐI HỌC KỲ I',
          subject: 'Ngữ văn',
          grade: '9',
          schoolYear: '2026 - 2027',
          semester: 'Học kỳ I',
          durationMinutes: 90,
        ),
      );

      // 5. Generate 4 Student Exam Codes (101, 102, 103, 104)
      const codeEngine = ExamCodeEngine();
      final multiCodeResult = codeEngine.generateCodes(
        masterPaper: masterPaper,
        numberOfCodes: 4,
        startingCode: 101,
        shuffleQuestions: true,
        shuffleChoices: true,
        baseSeed: 9999,
      );

      expect(multiCodeResult.codes.length, equals(4));
      expect(multiCodeResult.answerKeys.length, equals(4));

      // 6. EXPORT COMPLETE PACKAGE (Section 50)
      final exportResult = await AssessmentDocxExporter.exportPackage(
        project: projectData,
        specification: spec,
        matrix: matrix,
        objectives: objectives,
        masterPaper: masterPaper,
        codes: multiCodeResult.codes,
        answerKeys: multiCodeResult.answerKeys,
        baseExportDir: tempDir.path,
        projectRepository: projectRepository,
      );

      // 7. VERIFY EXPORT RESULTS
      expect(exportResult.successful, isTrue, reason: 'Export package should succeed completely');
      expect(exportResult.failedFiles, isEmpty);
      expect(exportResult.errors, isEmpty);

      // Expected files in package:
      // 1. Matrix
      // 2. Specification
      // 3. Master Paper
      // 4. Summary Answer Key
      // 5-8. Student Codes (101, 102, 103, 104)
      // 9-12. Answer Keys (101, 102, 103, 104)
      // Total = 12 files
      expect(exportResult.successfulFiles.length, equals(12));

      // Verify every file physically exists and has valid size
      for (final filePath in exportResult.successfulFiles) {
        final f = File(filePath);
        expect(f.existsSync(), isTrue, reason: 'File $filePath must exist on disk');
        expect(f.lengthSync(), greaterThan(500), reason: 'File $filePath must not be empty');
      }

      // 8. VERIFY PROJECT ARTIFACTS REGISTRATION (Section 52, 53)
      final attachedArtifacts = await projectRepository.listArtifacts(projectId);
      expect(attachedArtifacts.length, equals(12));
    });
  });
}
