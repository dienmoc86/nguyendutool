import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/lesson_plan_document.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/lesson_project_data.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/question_models.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/rubric_models.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/worksheet_models.dart';
import 'package:nguyendu_tool/features/teaching_suite/infrastructure/teaching_suite_docx_exporter.dart';

void main() {
  group('Export All E2E & OpenXML Structural Validation Tests (Phase 6B-R)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('nguyendu_export_all_e2e_');
    });

    tearDown(() async {
      try {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    test('Export All produces all FIVE DOCX files and validates OpenXML structure', () async {
      // Setup full data model with special characters to test XML escaping
      const project = LessonProjectData(
        lessonTitle: 'Truyện Kiều & Kim Vân Kiều Truyện <So sánh> "Đặc biệt"',
        subject: 'Ngữ văn',
        grade: '9',
        duration: '1 tiết (45 phút)',
      );

      final lessonPlan = LessonPlanDocument.createDefault5512(
        topic: 'Truyện Kiều & Nguyễn Du',
        grade: '9',
        subject: 'Ngữ văn',
      );

      final worksheet = WorksheetModel(
        id: 'ws_export_test',
        projectId: 'proj_export_test',
        title: 'Phiếu học tập: Phân tích & Đánh giá <Chi tiết>',
        preset: 'critical_thinking',
        durationMinutes: 20,
        tasks: [
          const WorksheetTask(
            id: 't1',
            instruction: 'Tìm các câu thơ có từ "buồn" & "sầu"',
            points: 5.0,
          ),
        ],
      );

      final questionSet = QuestionSet(
        id: 'qset_export_test',
        projectId: 'proj_export_test',
        title: 'Bộ câu hỏi kiểm tra: Truyện Kiều & Cuộc đời',
        items: const [
          QuestionItem(
            id: 'q1',
            type: QuestionType.multipleChoice,
            prompt: 'Nguyễn Du sinh & mất năm nào?',
            choices: ['A. 1765 - 1820', 'B. 1766 - 1821', 'C. 1767 - 1822', 'D. 1768 - 1823'],
            correctAnswer: 'A',
            difficulty: QuestionDifficulty.nhanBiet,
          ),
        ],
      );

      final rubric = RubricModel(
        id: 'rubric_export_test',
        projectId: 'proj_export_test',
        title: 'Rubric đánh giá bài làm <Chuẩn GDPT 2018>',
        totalScore: 10,
        criteria: const [
          RubricCriterion(
            id: 'c1',
            title: 'Kỹ năng đọc hiểu & Cảm thụ',
            maxScore: 10,
            levels: [
              RubricLevel(name: 'Xuất sắc', points: 10, description: 'Phân tích sâu sắc & mạch lạc'),
              RubricLevel(name: 'Đạt', points: 5, description: 'Nắm được ý chính'),
            ],
          ),
        ],
      );

      // Run Export All
      final exportResult = await TeachingSuiteDocxExporter.exportAll(
        outputDirectory: tempDir.path,
        project: project,
        lessonPlan: lessonPlan,
        worksheet: worksheet,
        questionSet: questionSet,
        rubric: rubric,
      );

      // Verify result structure
      expect(exportResult.isFullSuccess, isTrue);
      expect(exportResult.successfulCount, equals(5));
      expect(exportResult.failedCount, equals(0));

      // Expected filenames:
      final expectedKeys = [
        'lessonPlan',
        'worksheet',
        'questionSet',
        'answerKey',
        'rubric',
      ];

      for (final key in expectedKeys) {
        expect(exportResult.successfulFiles.containsKey(key), isTrue);
        final filePath = exportResult.successfulFiles[key]!;
        final file = File(filePath);
        expect(file.existsSync(), isTrue, reason: 'File for $key should physically exist on disk');

        // Structural OpenXML validation
        final bytes = await file.readAsBytes();
        expect(bytes.length, greaterThan(100), reason: 'File $key must not be empty');

        final archive = ZipDecoder().decodeBytes(bytes);
        final fileNames = archive.map((f) => f.name).toSet();

        // 1. [Content_Types].xml must exist
        expect(fileNames.contains('[Content_Types].xml'), isTrue, reason: '$key missing [Content_Types].xml');

        // 2. _rels/.rels must exist
        expect(fileNames.contains('_rels/.rels'), isTrue, reason: '$key missing _rels/.rels');

        // 3. word/document.xml must exist
        expect(fileNames.contains('word/document.xml'), isTrue, reason: '$key missing word/document.xml');

        // 4. word/_rels/document.xml.rels must exist
        expect(fileNames.contains('word/_rels/document.xml.rels'), isTrue, reason: '$key missing word/_rels/document.xml.rels');

        // 5. Verify valid XML and UTF-8 content in document.xml
        final docFile = archive.firstWhere((f) => f.name == 'word/document.xml');
        final xmlContent = String.fromCharCodes(docFile.content as List<int>);

        expect(xmlContent, startsWith('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'));
        expect(xmlContent, endsWith('</w:document>'));

        // Verify special characters were properly XML-escaped (no unescaped raw < or &)
        // An unescaped & would be '& ' rather than '&amp;'
        expect(xmlContent.contains('& '), isFalse);
      }
    });

    test('Export All handles partial failure gracefully and returns structured result', () async {
      // Provide an invalid read-only or invalid character output directory to test error capture
      final result = await TeachingSuiteDocxExporter.exportAll(
        outputDirectory: 'Z:/non_existent_drive/invalid_path',
        project: const LessonProjectData(lessonTitle: 'Test'),
      );

      expect(result.isFullSuccess, isFalse);
      expect(result.failedCount, greaterThan(0));
      expect(result.failedErrors.isNotEmpty, isTrue);
    });
  });
}
