import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/assessment_project_data.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/exam_answer_key.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/exam_code.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/exam_matrix.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/exam_question_snapshot.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/exam_specification.dart';
import 'package:nguyendu_tool/features/assessment_studio/domain/models/question_choice.dart';
import 'package:nguyendu_tool/features/assessment_studio/infrastructure/assessment_docx_exporter.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/learning_objective.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/question_models.dart';

void main() {
  group('Assessment Studio - OpenXML DOCX Export Validation Tests (Section 43-46, 88)', () {
    late Directory tempDir;
    const String projectId = 'proj_docx_test';
    const String specId = 'spec_docx_test';

    const headerConfig = ExamHeaderConfig(
      schoolName: 'TRƯỜNG THCS NGUYỄN DU',
      examTitle: 'ĐỀ KIỂM TRA ĐỊNH KỲ GIỮA HỌC KỲ I',
      subject: 'Ngữ văn',
      grade: '9',
      schoolYear: '2026 - 2027',
      semester: 'Học kỳ I',
      durationMinutes: 90,
    );

    final objectives = [
      const LearningObjective(
        id: 'obj_1',
        projectId: projectId,
        code: 'NL_DOC_01',
        description: 'Nhận biết các biện pháp tu từ so sánh & nhân hóa <đặc biệt>',
        category: 'Đọc hiểu',
      ),
      const LearningObjective(
        id: 'obj_2',
        projectId: projectId,
        code: 'NL_VIET_01',
        description: 'Viết đoạn văn ghi lại cảm xúc về một bài thơ & tác giả',
        category: 'Viết',
      ),
    ];

    final spec = ExamSpecification(
      id: specId,
      projectId: projectId,
      title: 'Đặc tả đề kiểm tra môn Ngữ văn 9',
      subject: 'Ngữ văn',
      grade: '9',
      durationMinutes: 90,
      totalScore: 10.0,
      questionCount: 4,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    const matrix = ExamMatrix(
      specificationId: specId,
      cells: [
        ExamMatrixCell(
          id: 'c1',
          specificationId: specId,
          objectiveId: 'obj_1',
          difficulty: QuestionDifficulty.nhanBiet,
          questionCount: 2,
          scorePerQuestion: 2.0,
        ),
        ExamMatrixCell(
          id: 'c2',
          specificationId: specId,
          objectiveId: 'obj_2',
          difficulty: QuestionDifficulty.vanDung,
          questionCount: 2,
          scorePerQuestion: 3.0,
        ),
      ],
    );

    final questions = [
      const ExamQuestionSnapshot(
        questionId: 'q1',
        prompt: 'Biện pháp tu từ nào được sử dụng trong câu "Mặt trời xuống biển như hòn lửa"?',
        choices: [
          QuestionChoice(id: 'c1_1', text: 'So sánh & nhân hóa'),
          QuestionChoice(id: 'c1_2', text: 'Ẩn dụ <chuyển đổi>'),
          QuestionChoice(id: 'c1_3', text: 'Hoán dụ'),
          QuestionChoice(id: 'c1_4', text: 'Nói quá'),
        ],
        correctChoiceId: 'c1_1',
        correctAnswerText: 'A',
        type: QuestionType.multipleChoice,
        difficulty: QuestionDifficulty.nhanBiet,
        score: 2.0,
        sectionIndex: 0,
      ),
      const ExamQuestionSnapshot(
        questionId: 'q2',
        prompt: 'Viết đoạn văn ngắn (7 - 9 câu) nêu cảm nhận của em về bài thơ.',
        choices: [],
        correctChoiceId: '',
        correctAnswerText: 'Dàn ý và hướng dẫn chấm đoạn văn cảm nhận...',
        type: QuestionType.essay,
        difficulty: QuestionDifficulty.vanDung,
        score: 3.0,
        sectionIndex: 2,
      ),
    ];

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('assessment_docx_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    /// Helper to validate standard OpenXML PK archive structure and extract document.xml
    String validateAndExtractDocx(File file) {
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(100));

      final bytes = file.readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Verify mandatory OpenXML package parts
      final contentTypes = archive.findFile('[Content_Types].xml');
      expect(contentTypes, isNotNull, reason: '[Content_Types].xml must be present');

      final rels = archive.findFile('_rels/.rels');
      expect(rels, isNotNull, reason: '_rels/.rels must be present');

      final docXml = archive.findFile('word/document.xml');
      expect(docXml, isNotNull, reason: 'word/document.xml must be present');

      return utf8.decode(docXml!.content as List<int>);
    }

    test('Exam Matrix DOCX export contains valid table, totals, and Vietnamese text (Section 48, 88)', () async {
      final outPath = '${tempDir.path}/01_Ma_tran.docx';
      final file = await AssessmentDocxExporter.exportMatrix(
        matrix: matrix,
        objectives: objectives,
        headerConfig: headerConfig,
        outputPath: outPath,
      );

      final xml = validateAndExtractDocx(file);
      expect(xml, contains('MA TRẬN ĐỀ KIỂM TRA'));
      expect(xml, contains('TRƯỜNG THCS NGUYỄN DU'));
      expect(xml, contains('Nhận biết các biện pháp tu từ'));
      expect(xml, contains('w:tbl')); // OpenXML table element
    });

    test('Exam Specification DOCX export contains blueprint details and allowed types (Section 49, 88)', () async {
      final outPath = '${tempDir.path}/02_Dac_ta.docx';
      final file = await AssessmentDocxExporter.exportSpecification(
        specification: spec,
        matrix: matrix,
        objectives: objectives,
        headerConfig: headerConfig,
        outputPath: outPath,
      );

      final xml = validateAndExtractDocx(file);
      expect(xml, contains('BẢN ĐẶC TẢ KỸ THUẬT ĐỀ KIỂM TRA'));
      expect(xml, contains('Ngữ văn'));
      expect(xml, contains('90 phút'));
    });

    test('Student Exam DOCX export never leaks correct answers or answer metadata (Section 45, 46, 88)', () async {
      final codeQuestions = [
        ExamCodeQuestion(
          id: 'ecq_101_1',
          examCodeId: 'ec_101',
          questionId: 'q1',
          orderIndex: 0,
          score: 2.0,
          correctDisplayAnswer: 'A', // Should NOT be in student doc
          choiceOrder: ['c1_1', 'c1_2', 'c1_3', 'c1_4'],
          snapshot: questions[0],
        ),
      ];

      final examCode = ExamCode(
        id: 'ec_101',
        examPaperId: 'paper_master',
        code: '101',
        questions: codeQuestions,
        createdAt: DateTime.now(),
      );

      final outPath = '${tempDir.path}/De_101.docx';
      final file = await AssessmentDocxExporter.exportExamCode(
        examCode: examCode,
        headerConfig: headerConfig,
        outputPath: outPath,
      );

      final xml = validateAndExtractDocx(file);
      expect(xml, contains('MÃ ĐỀ THI: 101'));
      expect(xml, contains('Mặt trời xuống biển như hòn lửa'));
      expect(xml, contains('A. So sánh &amp; nhân hóa')); // XML special char correctly escaped

      // CRITICAL SECTION 46 CHECK: Student exam must NOT reveal correct answers
      expect(xml, isNot(contains('Đáp án đúng:')));
      expect(xml, isNot(contains('Dàn ý và hướng dẫn chấm')));
    });

    test('Teacher Answer Key DOCX export contains answers, points, and explanations (Section 37, 74, 88)', () async {
      const answerKey = ExamAnswerKey(
        examCode: '101',
        items: [
          ExamAnswerKeyItem(
            questionNumber: 1,
            correctDisplayAnswer: 'A',
            score: 2.0,
            questionId: 'q1',
            promptSnippet: 'Mặt trời xuống biển...',
            explanation: 'Sử dụng từ so sánh "như" liên kết hai vế.',
            type: QuestionType.multipleChoice,
          ),
          ExamAnswerKeyItem(
            questionNumber: 2,
            correctDisplayAnswer: 'Dàn ý và hướng dẫn chấm đoạn văn',
            score: 3.0,
            questionId: 'q2',
            promptSnippet: 'Viết đoạn văn ngắn...',
            explanation: 'Đạt yêu cầu cấu trúc, dung lượng và nội dung.',
            type: QuestionType.essay,
          ),
        ],
      );

      final outPath = '${tempDir.path}/Dap_an_101.docx';
      final file = await AssessmentDocxExporter.exportAnswerKey(
        answerKey: answerKey,
        headerConfig: headerConfig,
        outputPath: outPath,
      );

      final xml = validateAndExtractDocx(file);
      expect(xml, contains('HƯỚNG DẪN CHẤM &amp; ĐÁP ÁN'));
      expect(xml, contains('101'));
      expect(xml, contains('Sử dụng từ so sánh &quot;như&quot; liên kết hai vế.'));
      expect(xml, contains('Dàn ý và hướng dẫn chấm'));
    });
  });
}
