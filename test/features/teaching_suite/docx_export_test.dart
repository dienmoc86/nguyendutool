import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/lesson_plan_document.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/lesson_project_data.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/question_models.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/rubric_models.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/worksheet_models.dart';
import 'package:nguyendu_tool/features/teaching_suite/infrastructure/teaching_suite_docx_exporter.dart';
import 'package:path/path.dart' as p;

void main() {
  group('Teaching Suite - DOCX Exporter & OpenXML Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('teaching_suite_docx_test_');
    });

    tearDown(() async {
      try {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    void verifyOpenXmlZip(File file, {List<String> expectedSubstrings = const []}) {
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(500));

      final bytes = file.readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Verify mandatory OpenXML package parts
      final fileNames = archive.files.map((f) => f.name).toSet();
      expect(fileNames, contains('[Content_Types].xml'));
      expect(fileNames, contains('_rels/.rels'));
      expect(fileNames, contains('word/_rels/document.xml.rels'));
      expect(fileNames, contains('word/styles.xml'));
      expect(fileNames, contains('word/document.xml'));

      // Check document.xml content
      final docFile = archive.findFile('word/document.xml');
      expect(docFile, isNotNull);
      final xmlContent = utf8.decode(docFile!.content as List<int>);

      for (final sub in expectedSubstrings) {
        expect(xmlContent, contains(sub));
      }
    }

    test('Exports Lesson Plan DOCX with CV 5512 structure and Vietnamese Unicode', () async {
      const planDoc = LessonPlanDocument(
        title: 'Chị em Thúy Kiều – Nguyễn Du',
        subject: 'Ngữ văn',
        grade: '9',
        duration: '2 tiết (90 phút)',
        bookSeries: 'Kết nối tri thức',
        rawContent: '''
# I. MỤC TIÊU
- Về kiến thức: Nắm vững vẻ đẹp tài sắc vẹn toàn của Thúy Kiều.
- Về năng lực: Năng lực cảm thụ văn học trung đại.

# II. THIẾT BỊ DẠY HỌC
- Tranh ảnh chân dung Truyện Kiều.

# III. TIẾN TRÌNH DẠY HỌC
## Hoạt động 1: Khởi động
Khởi động bằng đoạn ngâm thơ Kiều.
''',
      );

      final outPath = p.join(tempDir.path, '01_Giao_an.docx');
      final file = await TeachingSuiteDocxExporter.exportLessonPlan(
        document: planDoc,
        outputPath: outPath,
      );

      verifyOpenXmlZip(file, expectedSubstrings: [
        'KẾ HOẠCH BÀI DẠY (CÔNG VĂN 5512/BGDĐT-GDTrH)',
        'CHỊ EM THÚY KIỀU – NGUYỄN DU',
        'Ngữ văn',
        'MỤC TIÊU',
      ]);
    });

    test('Exports Worksheet DOCX with student answer lines', () async {
      final worksheet = WorksheetModel(
        id: 'ws_01',
        title: 'Phiếu học tập: Đoạn trích Chị em Thúy Kiều',
        subject: 'Ngữ văn',
        grade: '9',
        tasks: [
          const WorksheetTask(
            id: 't1',
            instruction: 'Điền từ còn thiếu vào chỗ trống',
            content: 'Mai cốt cách, tuyết tinh thần',
            hint: 'Hình tượng hoa mai và tuyết',
            points: 2,
          ),
        ],
      );

      final outPath = p.join(tempDir.path, '02_Phieu_hoc_tap.docx');
      final file = await TeachingSuiteDocxExporter.exportWorksheet(
        worksheet: worksheet,
        outputPath: outPath,
      );

      verifyOpenXmlZip(file, expectedSubstrings: [
        'HỌ VÀ TÊN HỌC SINH',
        'PHIẾU HỌC TẬP',
        'Mai cốt cách, tuyết tinh thần',
        'Bài làm của học sinh:',
      ]);
    });

    test('Exports Question Set & Deterministic Answer Key DOCX', () async {
      final qSet = QuestionSet(
        id: 'qs_01',
        projectId: 'p_kieu',
        title: 'Kiểm tra 15 phút Đoạn trích Chị em Thúy Kiều',
        subject: 'Ngữ văn',
        grade: '9',
        items: const [
          QuestionItem(
            id: 'q1',
            type: QuestionType.multipleChoice,
            prompt: 'Vẻ đẹp của Thúy Vân được miêu tả bằng hình ảnh nào?',
            choices: [
              'A. Khuôn trăng đầy đặn nét ngài nở nang',
              'B. Làn thu thủy nét xuân sơn',
              'C. Sắc sảo mặn mà',
              'D. Cung thương lầu bậc ngũ âm',
            ],
            correctAnswer: 'A',
            explanation: 'Nguyễn Du dùng hình tượng khuôn trăng, nét ngài để tả Thúy Vân.',
            difficulty: QuestionDifficulty.nhanBiet,
          ),
        ],
      );

      // Question set export
      final qPath = p.join(tempDir.path, '03_Cau_hoi.docx');
      final qFile = await TeachingSuiteDocxExporter.exportQuestionSet(
        questionSet: qSet,
        outputPath: qPath,
      );
      verifyOpenXmlZip(qFile, expectedSubstrings: [
        'BÀI KIỂM TRA ĐÁNH GIÁ THƯỜNG XUYÊN',
        'Khuôn trăng đầy đặn nét ngài nở nang',
      ]);

      // Answer key export
      final ansPath = p.join(tempDir.path, '04_Dap_an.docx');
      final ansFile = await TeachingSuiteDocxExporter.exportAnswerKey(
        questionSet: qSet,
        outputPath: ansPath,
      );
      verifyOpenXmlZip(ansFile, expectedSubstrings: [
        'ĐÁP ÁN &amp; HƯỚNG DẪN CHẤM CHI TIẾT',
        'Đáp án chính xác',
        'Nhận biết',
      ]);
    });

    test('Exports Rubric evaluation DOCX with criteria table', () async {
      final rubric = RubricModel(
        id: 'rub_01',
        projectId: 'p_kieu',
        title: 'Rubric đánh giá bài văn phân tích chân dung Thúy Kiều',
        criteria: const [
          RubricCriterion(
            id: 'c1',
            name: 'Kỹ năng phân tích từ ngữ',
            weight: 50.0,
            levels: [
              RubricLevel(name: 'Xuất sắc', score: 4.0, description: 'Chỉ rõ giá trị tu từ đặc sắc.'),
              RubricLevel(name: 'Đạt', score: 2.0, description: 'Nêu được từ ngữ cơ bản.'),
            ],
          ),
          RubricCriterion(
            id: 'c2',
            name: 'Bố cục bài viết',
            weight: 50.0,
            levels: [
              RubricLevel(name: 'Xuất sắc', score: 4.0, description: 'Bố cục 3 phần mạch lạc.'),
              RubricLevel(name: 'Đạt', score: 2.0, description: 'Có đủ 3 phần.'),
            ],
          ),
        ],
      );

      final rPath = p.join(tempDir.path, '05_Rubric.docx');
      final rFile = await TeachingSuiteDocxExporter.exportRubric(
        rubric: rubric,
        outputPath: rPath,
      );

      verifyOpenXmlZip(rFile, expectedSubstrings: [
        'PHIẾU ĐÁNH GIÁ THEO TIÊU CHÍ (RUBRIC)',
        'RUBRIC ĐÁNH GIÁ BÀI VĂN PHÂN TÍCH CHÂN DUNG THÚY KIỀU',
        'Kỹ năng phân tích từ ngữ',
        '50.0%',
      ]);
    });

    test('Batch exportAll generates all 5 files into target project folder', () async {
      const project = LessonProjectData(
        subject: 'Ngữ văn',
        grade: '9',
        bookSeries: 'Kết nối tri thức',
        lessonTitle: 'Truyện Kiều',
      );

      const planDoc = LessonPlanDocument(
        title: 'Truyện Kiều',
        subject: 'Ngữ văn',
        grade: '9',
        rawContent: '# I. MỤC TIÊU\nNắm vững tác phẩm.',
      );

      final worksheet = WorksheetModel(
        id: 'ws_batch',
        title: 'Phiếu học tập',
        subject: 'Ngữ văn',
        grade: '9',
      );

      final qSet = QuestionSet(
        id: 'qs_batch',
        projectId: 'p_batch',
        title: 'Bộ câu hỏi',
        subject: 'Ngữ văn',
        grade: '9',
        items: const [
          QuestionItem(id: 'q1', prompt: 'Ai là tác giả?', correctAnswer: 'Nguyễn Du'),
        ],
      );

      final rubric = RubricModel(
        id: 'rub_batch',
        projectId: 'p_batch',
        title: 'Rubric bài học',
        criteria: const [
          RubricCriterion(id: 'c1', name: 'Tiêu chí 1', weight: 100.0),
        ],
      );

      final batchFolder = p.join(tempDir.path, 'Ngu_van_9_Truyen_Kieu');
      final result = await TeachingSuiteDocxExporter.exportAll(
        outputDirectory: batchFolder,
        project: project,
        lessonPlan: planDoc,
        worksheet: worksheet,
        questionSet: qSet,
        rubric: rubric,
      );

      expect(result.length, equals(5));
      expect(File(result['lessonPlan']!).existsSync(), isTrue);
      expect(File(result['worksheet']!).existsSync(), isTrue);
      expect(File(result['questionSet']!).existsSync(), isTrue);
      expect(File(result['answerKey']!).existsSync(), isTrue);
      expect(File(result['rubric']!).existsSync(), isTrue);
    });
  });
}
