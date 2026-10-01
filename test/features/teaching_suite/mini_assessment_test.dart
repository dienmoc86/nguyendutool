import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/database/database_tables.dart';
import 'package:nguyendu_tool/core/database/migrations/v1_to_v2.dart';
import 'package:nguyendu_tool/core/database/migrations/v2_to_v3.dart';
import 'package:nguyendu_tool/core/database/migrations/v3_to_v4.dart';
import 'package:nguyendu_tool/core/database/migrations/v4_to_v5.dart';
import 'package:nguyendu_tool/core/database/migrations/v5_to_v6.dart';
import 'package:nguyendu_tool/core/database/migrations/v6_to_v7.dart';
import 'package:nguyendu_tool/core/database/migrations/v7_to_v8.dart';
import 'package:nguyendu_tool/features/teaching_suite/data/teaching_suite_repository.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/mini_assessment_model.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/question_models.dart';
import 'package:nguyendu_tool/features/teaching_suite/infrastructure/teaching_suite_docx_exporter.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('Mini Assessment Persistence & Exact Selection Export Test (Phase 6B-R)', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('nguyendu_mini_assess_test_');
      dbPath = p.join(tempDir.path, 'mini_assessment.db');
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

    test('Persists MiniAssessment and reloads exact question IDs and order', () async {
      var db = await openV8Db();
      var repo = TeachingSuiteRepository.withDb(db);
      const projectId = 'proj_mini_303';
      final now = DateTime.now();

      // Create a persistent MiniAssessment
      final assessment = MiniAssessment(
        id: 'mini_test_01',
        projectId: projectId,
        sourceQuestionSetId: 'qset_full_bank',
        title: 'Đề kiểm tra nhanh 15 phút',
        durationMinutes: 15,
        questionIds: ['q_03', 'q_07', 'q_09'],
        createdAt: now,
      );

      await repo.saveMiniAssessment(assessment);

      // Close and reopen DB
      await db.close();
      db = await openV8Db();
      repo = TeachingSuiteRepository.withDb(db);

      final list = await repo.listMiniAssessments(projectId);
      expect(list.length, equals(1));
      expect(list.first.id, equals('mini_test_01'));
      expect(list.first.title, equals('Đề kiểm tra nhanh 15 phút'));
      expect(list.first.questionIds, equals(['q_03', 'q_07', 'q_09']));

      await db.close();
    });

    test('Export Mini Assessment produces DOCX containing ONLY selected questions, not full bank', () async {
      // Build a bank of 10 questions
      final fullBank = List.generate(
        10,
        (i) => QuestionItem(
          id: 'q_${i + 1}',
          type: QuestionType.multipleChoice,
          prompt: 'Nội dung câu hỏi số ${i + 1} của ngân hàng tổng',
          choices: ['A. Lựa chọn 1', 'B. Lựa chọn 2', 'C. Lựa chọn 3', 'D. Lựa chọn 4'],
          correctAnswer: 'A',
          difficulty: QuestionDifficulty.nhanBiet,
        ),
      );

      // Select exactly 3 questions: question 2, 5, 8
      final selectedQuestions = [fullBank[1], fullBank[4], fullBank[7]];

      final miniResult = MiniAssessmentResult(
        title: 'Đề kiểm tra trắc nghiệm 3 câu',
        durationMinutes: 10,
        questions: selectedQuestions,
        deterministicAnswerKey: {
          1: 'A',
          2: 'A',
          3: 'A',
        },
      );

      final qDocxPath = p.join(tempDir.path, 'mini_exam.docx');
      final aDocxPath = p.join(tempDir.path, 'mini_exam_answers.docx');

      // Export mini assessment
      await TeachingSuiteDocxExporter.exportMiniAssessment(
        result: miniResult,
        outputPath: qDocxPath,
      );

      await TeachingSuiteDocxExporter.exportMiniAssessmentAnswerKey(
        result: miniResult,
        outputPath: aDocxPath,
      );

      expect(File(qDocxPath).existsSync(), isTrue);
      expect(File(aDocxPath).existsSync(), isTrue);

      // Verify that DOCX contains exactly the 3 selected questions and NOT the unselected questions
      final bytes = await File(qDocxPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final docXmlFile = archive.firstWhere((f) => f.name == 'word/document.xml');
      final content = utf8.decode(docXmlFile.content as List<int>);

      // Should contain selected questions:
      expect(content, contains('Nội dung câu hỏi số 2 của ngân hàng tổng'));
      expect(content, contains('Nội dung câu hỏi số 5 của ngân hàng tổng'));
      expect(content, contains('Nội dung câu hỏi số 8 của ngân hàng tổng'));

      // Must NOT contain unselected questions:
      expect(content, isNot(contains('Nội dung câu hỏi số 1 của ngân hàng tổng')));
      expect(content, isNot(contains('Nội dung câu hỏi số 3 của ngân hàng tổng')));
      expect(content, isNot(contains('Nội dung câu hỏi số 10 của ngân hàng tổng')));
    });
  });
}
