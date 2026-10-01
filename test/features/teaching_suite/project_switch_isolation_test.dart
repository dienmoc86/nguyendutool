import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/database/database_tables.dart';
import 'package:nguyendu_tool/core/database/migrations/v1_to_v2.dart';
import 'package:nguyendu_tool/core/database/migrations/v2_to_v3.dart';
import 'package:nguyendu_tool/core/database/migrations/v3_to_v4.dart';
import 'package:nguyendu_tool/core/database/migrations/v4_to_v5.dart';
import 'package:nguyendu_tool/core/database/migrations/v5_to_v6.dart';
import 'package:nguyendu_tool/core/database/migrations/v6_to_v7.dart';
import 'package:nguyendu_tool/core/database/migrations/v7_to_v8.dart';
import 'package:nguyendu_tool/core/database/app_database.dart';
import 'package:nguyendu_tool/core/projects/data/workspace_project_repository.dart';
import 'package:nguyendu_tool/core/projects/domain/project_type.dart';
import 'package:nguyendu_tool/core/projects/domain/workspace_project.dart';
import 'package:nguyendu_tool/features/teaching_suite/data/teaching_suite_repository.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/lesson_plan_document.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/question_models.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/rubric_models.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/worksheet_models.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _TestAppDatabase extends AppDatabase {
  final Database _dbInstance;
  _TestAppDatabase(this._dbInstance);
  @override
  Future<Database> get database async => _dbInstance;
}

void main() {
  sqfliteFfiInit();

  group('Project Switch Isolation Test (Phase 6B-R)', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('nguyendu_isolation_test_');
      dbPath = p.join(tempDir.path, 'isolation_test.db');
    });

    tearDown(() async {
      try {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    Future<Database> openV8Db() async {
      return await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 8,
          onCreate: (db, version) async {
            await db.execute(DatabaseTables.createAppSettingsTable);
            await db.execute(DatabaseTables.createProjectsTable);
            await db.execute(DatabaseTables.createFilesTable);
            await db.execute(DatabaseTables.createJobsTable);
            await db.execute(DatabaseTables.createProvidersTable);
            await db.execute(DatabaseTables.createPdfJobsTable);
            await db.execute(DatabaseTables.createOcrCacheTable);

            await V1ToV2Migration.migrate(db);
            await V2ToV3Migration.migrate(db);
            await V3ToV4Migration.migrate(db);
            await V4ToV5Migration.migrate(db);
            await V5ToV6Migration.migrate(db);
            await V6ToV7Migration.migrate(db);
            await V7ToV8Migration.migrate(db);
          },
        ),
      );
    }

    test('Switching A -> B -> A has zero data leakage across all 4 teaching domains', () async {
      final db = await openV8Db();
      final projectRepo = WorkspaceProjectRepository(appDatabase: _TestAppDatabase(db));
      final teachingRepo = TeachingSuiteRepository.withDb(db);
      final now = DateTime.now();

      // Setup Project A
      const projAId = 'proj_A';
      await projectRepo.createProject(WorkspaceProject(
        id: projAId,
        name: 'Dự án A - Chị em Thúy Kiều',
        type: ProjectType.lesson,
        createdAt: now,
        updatedAt: now,
        metadataJson: '{"lessonTitle":"Chị em Thúy Kiều"}',
      ));

      await teachingRepo.saveLessonPlanDraft(
        projAId,
        LessonPlanDocument.createDefault5512(topic: 'Chị em Thúy Kiều', grade: '9', subject: 'Ngữ văn'),
      );

      await teachingRepo.saveWorksheet(WorksheetModel(
        id: 'ws_A',
        projectId: projAId,
        title: 'Phiếu học tập A',
        preset: 'A',
        durationMinutes: 15,
        tasks: [
          const WorksheetTask(id: 't_A1', instruction: 'Nhiệm vụ A', points: 10),
        ],
      ));

      await teachingRepo.saveQuestionSet(
        QuestionSet(
          id: 'qset_A',
          projectId: projAId,
          title: 'Bộ câu hỏi A',
          items: const [
            QuestionItem(
              id: 'q_A1',
              type: QuestionType.multipleChoice,
              prompt: 'Câu hỏi riêng của A?',
              choices: ['A. 1', 'B. 2', 'C. 3', 'D. 4'],
              correctAnswer: 'A',
            ),
          ],
        ),
      );

      await teachingRepo.saveRubric(
        RubricModel(
          id: 'rubric_A',
          projectId: projAId,
          title: 'Rubric bài học A',
          totalScore: 10,
          criteria: const [
            RubricCriterion(id: 'c_A1', title: 'Tiêu chí A', maxScore: 10),
          ],
        ),
      );

      // Setup Project B
      const projBId = 'proj_B';
      await projectRepo.createProject(WorkspaceProject(
        id: projBId,
        name: 'Dự án B - Lục Vân Tiên',
        type: ProjectType.lesson,
        createdAt: now,
        updatedAt: now,
        metadataJson: '{"lessonTitle":"Lục Vân Tiên"}',
      ));

      await teachingRepo.saveLessonPlanDraft(
        projBId,
        LessonPlanDocument.createDefault5512(topic: 'Lục Vân Tiên cứu Kiều Nguyệt Nga', grade: '9', subject: 'Ngữ văn'),
      );

      await teachingRepo.saveWorksheet(WorksheetModel(
        id: 'ws_B',
        projectId: projBId,
        title: 'Phiếu học tập B',
        preset: 'B',
        durationMinutes: 30,
        tasks: [
          const WorksheetTask(id: 't_B1', instruction: 'Nhiệm vụ B', points: 5),
        ],
      ));

      await teachingRepo.saveQuestionSet(
        QuestionSet(
          id: 'qset_B',
          projectId: projBId,
          title: 'Bộ câu hỏi B',
          items: const [
            QuestionItem(
              id: 'q_B1',
              type: QuestionType.multipleChoice,
              prompt: 'Câu hỏi riêng của B?',
              choices: ['A. X', 'B. Y', 'C. Z', 'D. W'],
              correctAnswer: 'B',
            ),
          ],
        ),
      );

      await teachingRepo.saveRubric(
        RubricModel(
          id: 'rubric_B',
          projectId: projBId,
          title: 'Rubric bài học B',
          totalScore: 10,
          criteria: const [
            RubricCriterion(id: 'c_B1', title: 'Tiêu chí B', maxScore: 10),
          ],
        ),
      );

      // Switch to A: verify all elements belong strictly to A
      final planA = await teachingRepo.getLessonPlanDraft(projAId);
      final wsA = await teachingRepo.getWorksheet(projAId);
      final qA = (await teachingRepo.getQuestionSetsForProject(projAId)).firstOrNull;
      final rA = (await teachingRepo.getRubricsForProject(projAId)).firstOrNull;

      expect(planA?.title, contains('Chị em Thúy Kiều'));
      expect(wsA?.title, equals('Phiếu học tập A'));
      expect(wsA?.tasks.first.instruction, equals('Nhiệm vụ A'));
      expect(qA?.items.first.prompt, equals('Câu hỏi riêng của A?'));
      expect(rA?.criteria.first.title, equals('Tiêu chí A'));

      // Switch to B: verify all elements belong strictly to B
      final planB = await teachingRepo.getLessonPlanDraft(projBId);
      final wsB = await teachingRepo.getWorksheet(projBId);
      final qB = (await teachingRepo.getQuestionSetsForProject(projBId)).firstOrNull;
      final rB = (await teachingRepo.getRubricsForProject(projBId)).firstOrNull;

      expect(planB?.title, contains('Lục Vân Tiên'));
      expect(wsB?.title, equals('Phiếu học tập B'));
      expect(wsB?.tasks.first.instruction, equals('Nhiệm vụ B'));
      expect(qB?.items.first.prompt, equals('Câu hỏi riêng của B?'));
      expect(rB?.criteria.first.title, equals('Tiêu chí B'));

      // Switch back to A: verify zero state leakage from B
      final planA2 = await teachingRepo.getLessonPlanDraft(projAId);
      final wsA2 = await teachingRepo.getWorksheet(projAId);
      final qA2 = (await teachingRepo.getQuestionSetsForProject(projAId)).firstOrNull;
      final rA2 = (await teachingRepo.getRubricsForProject(projAId)).firstOrNull;

      expect(planA2?.title, contains('Chị em Thúy Kiều'));
      expect(wsA2?.title, equals('Phiếu học tập A'));
      expect(qA2?.items.first.prompt, equals('Câu hỏi riêng của A?'));
      expect(rA2?.criteria.first.title, equals('Tiêu chí A'));

      await db.close();
    });
  });
}
