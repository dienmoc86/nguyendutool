import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import '../../../core/logging/app_logger.dart';
import '../domain/models/lesson_plan_document.dart';
import '../domain/models/lesson_project_data.dart';
import '../domain/models/question_models.dart';
import '../domain/models/rubric_models.dart';
import '../domain/models/mini_assessment_model.dart';
import '../domain/models/worksheet_models.dart';

/// Structured result of Export All batch processing.
class ExportAllResult {
  final bool successful;
  final Map<String, String> exportedPaths;
  final List<String> failedFiles;
  final List<String> errors;

  const ExportAllResult({
    required this.successful,
    required this.exportedPaths,
    this.failedFiles = const [],
    this.errors = const [],
  });

  bool get isFullSuccess => successful && failedFiles.isEmpty;
  int get successfulCount => exportedPaths.length;
  int get failedCount => failedFiles.length;
  Map<String, String> get successfulFiles => exportedPaths;
  List<String> get failedErrors => errors;

  /// Map-like index access for backward compatibility.
  String? operator [](String key) => exportedPaths[key];
  int get length => exportedPaths.length;
  Iterable<MapEntry<String, String>> get entries => exportedPaths.entries;
}

/// Comprehensive OpenXML (.docx) exporter for all Teaching Suite educational artifacts.
/// Strictly adheres to Vietnamese administrative and educational typography standards
/// (Decree 30/2020/NĐ-CP & Dispatch 5512/BGDĐT-GDTrH).
class TeachingSuiteDocxExporter {
  // ==========================================
  // EXPORT METHODS
  // ==========================================

  /// Exports CV 5512 Lesson Plan to Word (.docx).
  static Future<File> exportLessonPlan({
    required LessonPlanDocument document,
    required String outputPath,
  }) async {
    final bodyBuffer = StringBuffer();

    // Title Block
    bodyBuffer.write(_makeParagraph(
      'KẾ HOẠCH BÀI DẠY (CÔNG VĂN 5512/BGDĐT-GDTrH)',
      isBold: true,
      fontSize: 28,
      align: 'center',
    ));
    bodyBuffer.write(_makeParagraph(
      'BÀI DẠY: ${document.title.toUpperCase()}',
      isBold: true,
      fontSize: 26,
      align: 'center',
    ));
    bodyBuffer.write(_makeParagraph(
      'Môn học: ${document.subject} - Lớp: ${document.grade} | Thời lượng: ${document.duration}',
      isItalic: true,
      fontSize: 24,
      align: 'center',
    ));
    if (document.bookSeries.isNotEmpty) {
      bodyBuffer.write(_makeParagraph(
        'Bộ sách: ${document.bookSeries}',
        isItalic: true,
        fontSize: 22,
        align: 'center',
      ));
    }
    bodyBuffer.write(_makeDivider());

    // Body content: parse line by line from markdown or formatted sections
    final lines = (document.rawContent.isNotEmpty ? document.rawContent : _formatLessonPlanFallback(document))
        .split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('# ')) {
        bodyBuffer.write(_makeParagraph(trimmed.substring(2), isBold: true, fontSize: 26, spaceBefore: 200, spaceAfter: 80));
      } else if (trimmed.startsWith('## ')) {
        bodyBuffer.write(_makeParagraph(trimmed.substring(3), isBold: true, fontSize: 24, spaceBefore: 160, spaceAfter: 60));
      } else if (trimmed.startsWith('### ')) {
        bodyBuffer.write(_makeParagraph(trimmed.substring(4), isBold: true, fontSize: 22, spaceBefore: 120, spaceAfter: 40));
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        bodyBuffer.write(_makeParagraph('• ${trimmed.substring(2)}', indentLeft: 360, spaceAfter: 40));
      } else {
        bodyBuffer.write(_makeParagraph(trimmed, spaceAfter: 60));
      }
    }

    return _packageDocx(bodyBuffer.toString(), outputPath);
  }

  /// Exports Student Worksheet to Word (.docx).
  static Future<File> exportWorksheet({
    required WorksheetModel worksheet,
    required String outputPath,
  }) async {
    final bodyBuffer = StringBuffer();

    // School Header Box
    bodyBuffer.write(_makeParagraph('TRƯỜNG: ........................................', isBold: true, fontSize: 22));
    bodyBuffer.write(_makeParagraph('LỚP: ..............................................', isBold: true, fontSize: 22));
    bodyBuffer.write(_makeParagraph('HỌ VÀ TÊN HỌC SINH: ................................................................', isBold: true, fontSize: 22));
    bodyBuffer.write(_makeDivider());

    // Worksheet Title
    bodyBuffer.write(_makeParagraph(
      worksheet.title.toUpperCase(),
      isBold: true,
      fontSize: 28,
      align: 'center',
      spaceBefore: 100,
    ));
    bodyBuffer.write(_makeParagraph(
      'Môn: ${worksheet.subject} - Lớp: ${worksheet.grade} | Thời gian làm bài: ${worksheet.durationMinutes} phút',
      isItalic: true,
      fontSize: 24,
      align: 'center',
      spaceAfter: 200,
    ));

    // Tasks
    for (int i = 0; i < worksheet.tasks.length; i++) {
      final task = worksheet.tasks[i];
      bodyBuffer.write(_makeParagraph(
        'Nhiệm vụ ${i + 1} (${task.points} điểm) - [${task.taskType.label}]: ${task.instruction}',
        isBold: true,
        fontSize: 24,
        spaceBefore: 160,
        spaceAfter: 60,
      ));

      if (task.content.isNotEmpty) {
        bodyBuffer.write(_makeParagraph(task.content, indentLeft: 360, spaceAfter: 60));
      }

      if (task.hint != null && task.hint!.isNotEmpty) {
        bodyBuffer.write(_makeParagraph('Gợi ý: ${task.hint!}', isItalic: true, indentLeft: 360, spaceAfter: 60));
      }

      // Answer Lines for students
      bodyBuffer.write(_makeParagraph('Bài làm của học sinh:', isItalic: true, indentLeft: 360, spaceBefore: 60));
      bodyBuffer.write(_makeParagraph('................................................................................................................................................', indentLeft: 360));
      bodyBuffer.write(_makeParagraph('................................................................................................................................................', indentLeft: 360));
      bodyBuffer.write(_makeParagraph('................................................................................................................................................', indentLeft: 360, spaceAfter: 120));
    }

    if (worksheet.teacherNotes != null && worksheet.teacherNotes!.isNotEmpty) {
      bodyBuffer.write(_makeDivider());
      bodyBuffer.write(_makeParagraph('Lưu ý sư phạm: ${worksheet.teacherNotes!}', isItalic: true, fontSize: 20));
    }

    return _packageDocx(bodyBuffer.toString(), outputPath);
  }

  /// Exports Question Set (Test Sheet) to Word (.docx).
  static Future<File> exportQuestionSet({
    required QuestionSet questionSet,
    required String outputPath,
  }) async {
    final bodyBuffer = StringBuffer();

    // Test Header
    bodyBuffer.write(_makeParagraph(
      'BÀI KIỂM TRA ĐÁNH GIÁ THƯỜNG XUYÊN',
      isBold: true,
      fontSize: 26,
      align: 'center',
    ));
    bodyBuffer.write(_makeParagraph(
      questionSet.title.toUpperCase(),
      isBold: true,
      fontSize: 24,
      align: 'center',
    ));
    bodyBuffer.write(_makeParagraph(
      'Môn học: ${questionSet.subject} - Lớp: ${questionSet.grade} | Tổng số câu hỏi: ${questionSet.items.length}',
      isItalic: true,
      fontSize: 22,
      align: 'center',
      spaceAfter: 160,
    ));
    bodyBuffer.write(_makeDivider());

    for (int i = 0; i < questionSet.items.length; i++) {
      final q = questionSet.items[i];
      final diffTag = '[${q.difficulty.label}]';

      bodyBuffer.write(_makeParagraph(
        'Câu ${i + 1} $diffTag: ${q.prompt}',
        isBold: true,
        fontSize: 24,
        spaceBefore: 120,
        spaceAfter: 60,
      ));

      if (q.type == QuestionType.multipleChoice) {
        for (final choice in q.choices) {
          bodyBuffer.write(_makeParagraph(choice, indentLeft: 360, spaceAfter: 40));
        }
      } else if (q.type == QuestionType.trueFalse) {
        bodyBuffer.write(_makeParagraph('A. Đúng                       B. Sai', indentLeft: 360, spaceAfter: 60));
      } else {
        bodyBuffer.write(_makeParagraph('Trả lời: ................................................................................................................................................', indentLeft: 360, spaceAfter: 60));
      }
    }

    return _packageDocx(bodyBuffer.toString(), outputPath);
  }

  /// Exports deterministic Answer Key & Scoring Guide to Word (.docx).
  static Future<File> exportAnswerKey({
    required QuestionSet questionSet,
    required String outputPath,
  }) async {
    final bodyBuffer = StringBuffer();

    bodyBuffer.write(_makeParagraph(
      'ĐÁP ÁN & HƯỚNG DẪN CHẤM CHI TIẾT',
      isBold: true,
      fontSize: 26,
      align: 'center',
    ));
    bodyBuffer.write(_makeParagraph(
      questionSet.title.toUpperCase(),
      isBold: true,
      fontSize: 24,
      align: 'center',
    ));
    bodyBuffer.write(_makeParagraph(
      'Môn: ${questionSet.subject} - Lớp: ${questionSet.grade}',
      isItalic: true,
      fontSize: 22,
      align: 'center',
      spaceAfter: 160,
    ));
    bodyBuffer.write(_makeDivider());

    // Create table of answers
    final headers = ['Câu', 'Đáp án chính xác', 'Mức độ', 'Hướng dẫn giải thích'];
    final rows = <List<String>>[];

    for (int i = 0; i < questionSet.items.length; i++) {
      final q = questionSet.items[i];
      rows.add([
        '${i + 1}',
        q.correctAnswer,
        q.difficulty.label,
        q.explanation ?? 'Theo chuẩn kiến thức kỹ năng SGK.',
      ]);
    }

    bodyBuffer.write(_makeTable(headers, rows, colWidths: [800, 1600, 1600, 5000]));

    return _packageDocx(bodyBuffer.toString(), outputPath);
  }

  /// Exports Rubric evaluation table to Word (.docx).
  static Future<File> exportRubric({
    required RubricModel rubric,
    required String outputPath,
  }) async {
    final bodyBuffer = StringBuffer();

    bodyBuffer.write(_makeParagraph(
      'PHIẾU ĐÁNH GIÁ THEO TIÊU CHÍ (RUBRIC)',
      isBold: true,
      fontSize: 26,
      align: 'center',
    ));
    bodyBuffer.write(_makeParagraph(
      rubric.title.toUpperCase(),
      isBold: true,
      fontSize: 24,
      align: 'center',
    ));
    bodyBuffer.write(_makeParagraph(
      'Tổng trọng số: ${rubric.totalWeight.toStringAsFixed(1)}% ${rubric.isWeightValid ? "(Đạt chuẩn 100%)" : "(Cảnh báo: Chưa đạt 100%)"}',
      isItalic: true,
      fontSize: 22,
      align: 'center',
      spaceAfter: 160,
    ));
    bodyBuffer.write(_makeDivider());

    final headers = ['Tiêu chí', 'Trọng số', 'Mức 4 (Xuất sắc)', 'Mức 3 (Tốt)', 'Mức 2 (Đạt)', 'Mức 1 (Cần cố gắng)'];
    final rows = <List<String>>[];

    for (final crit in rubric.criteria) {
      final desc4 = crit.levels.isNotEmpty ? crit.levels[0].description : '';
      final desc3 = crit.levels.length > 1 ? crit.levels[1].description : '';
      final desc2 = crit.levels.length > 2 ? crit.levels[2].description : '';
      final desc1 = crit.levels.length > 3 ? crit.levels[3].description : '';

      rows.add([
        crit.name,
        '${crit.weight}%',
        desc4,
        desc3,
        desc2,
        desc1,
      ]);
    }

    bodyBuffer.write(_makeTable(headers, rows, colWidths: [1800, 900, 1600, 1600, 1600, 1600]));

    return _packageDocx(bodyBuffer.toString(), outputPath);
  }

  /// Exports MiniAssessment questions sheet to Word (.docx) with EXACTLY the selected questions.
  static Future<File> exportMiniAssessment({
    MiniAssessment? assessment,
    MiniAssessmentResult? result,
    required String outputPath,
  }) async {
    final effective = assessment ??
        (result != null
            ? MiniAssessment(
                id: 'temp',
                projectId: '',
                title: result.title,
                durationMinutes: result.durationMinutes,
                questions: result.questions,
              )
            : throw ArgumentError('Must provide either assessment or result'));

    final bodyBuffer = StringBuffer();
    bodyBuffer.write(_makeParagraph('BÀI KIỂM TRA ĐÁNH GIÁ NHANH (MINI-ASSESSMENT)', isBold: true, fontSize: 26, align: 'center'));
    bodyBuffer.write(_makeParagraph(effective.title.toUpperCase(), isBold: true, fontSize: 24, align: 'center'));
    bodyBuffer.write(_makeParagraph('Thời gian làm bài: ${effective.durationMinutes} phút | Số lượng: ${effective.questions.length} câu', isItalic: true, fontSize: 22, align: 'center'));
    bodyBuffer.write(_makeDivider());

    for (int i = 0; i < effective.questions.length; i++) {
      final q = effective.questions[i];
      final qNum = i + 1;
      bodyBuffer.write(_makeParagraph('Câu $qNum (${q.difficulty.label}): ${q.prompt}', isBold: true, fontSize: 24, spaceBefore: 120, spaceAfter: 60));
      if (q.type == QuestionType.multipleChoice || q.type == QuestionType.trueFalse) {
        for (final choice in q.choices) {
          bodyBuffer.write(_makeParagraph('    $choice', fontSize: 22, spaceAfter: 40));
        }
      } else {
        bodyBuffer.write(_makeParagraph('    ................................................................................................................................', fontSize: 22, spaceAfter: 60));
      }
    }
    return _packageDocx(bodyBuffer.toString(), outputPath);
  }

  /// Exports MiniAssessment answer key to Word (.docx) with EXACTLY the selected questions.
  static Future<File> exportMiniAssessmentAnswerKey({
    MiniAssessment? assessment,
    MiniAssessmentResult? result,
    required String outputPath,
  }) async {
    final effective = assessment ??
        (result != null
            ? MiniAssessment(
                id: 'temp',
                projectId: '',
                title: result.title,
                durationMinutes: result.durationMinutes,
                questions: result.questions,
              )
            : throw ArgumentError('Must provide either assessment or result'));

    final bodyBuffer = StringBuffer();
    bodyBuffer.write(_makeParagraph('ĐÁP ÁN VÀ HƯỚNG DẪN CHẤM BÀI KIỂM TRA NHANH', isBold: true, fontSize: 26, align: 'center'));
    bodyBuffer.write(_makeParagraph(effective.title.toUpperCase(), isBold: true, fontSize: 24, align: 'center'));
    bodyBuffer.write(_makeDivider());

    final headers = ['Câu', 'Dạng câu hỏi', 'Đáp án đúng', 'Hướng dẫn giải thích'];
    final rows = <List<String>>[];
    for (int i = 0; i < effective.questions.length; i++) {
      final q = effective.questions[i];
      rows.add([
        '${i + 1}',
        q.type.label,
        q.correctAnswer,
        q.explanation ?? 'Xem SGK / tài liệu học tập',
      ]);
    }
    bodyBuffer.write(_makeTable(headers, rows, colWidths: [800, 1600, 1600, 5000]));
    return _packageDocx(bodyBuffer.toString(), outputPath);
  }

  /// Batch exports all 5 core teaching artifacts into a dedicated project folder.
  /// Guarantees that 01_Giao_an, 02_Phieu_hoc_tap, 03_Cau_hoi, 04_Dap_an, and 05_Rubric are generated.
  static Future<ExportAllResult> exportAll({
    required String outputDirectory,
    required LessonProjectData project,
    LessonPlanDocument? lessonPlan,
    WorksheetModel? worksheet,
    QuestionSet? questionSet,
    RubricModel? rubric,
  }) async {
    final dir = Directory(outputDirectory);
    try {
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
    } catch (e) {
      AppLogger.error('Failed to create export directory $outputDirectory: $e');
      return ExportAllResult(
        successful: false,
        exportedPaths: const {},
        failedFiles: const [
          '01_Giao_an.docx',
          '02_Phieu_hoc_tap.docx',
          '03_Cau_hoi.docx',
          '04_Dap_an.docx',
          '05_Rubric.docx',
        ],
        errors: [
          '01_Giao_an.docx: $e',
          '02_Phieu_hoc_tap.docx: $e',
          '03_Cau_hoi.docx: $e',
          '04_Dap_an.docx: $e',
          '05_Rubric.docx: $e',
        ],
      );
    }

    final Map<String, String> exportedPaths = {};
    final List<String> failedFiles = [];
    final List<String> errors = [];

    // Fallbacks if some data is not explicitly provided so ALL 5 FILES are generated
    final effectivePlan = lessonPlan ??
        LessonPlanDocument.parseFromMarkdown(
          title: project.lessonTitle,
          subject: project.subject,
          grade: project.grade,
          duration: project.duration,
          bookSeries: project.bookSeries,
          markdown: '# KẾ HOẠCH BÀI DẠY: ${project.lessonTitle}\n\n## I. MỤC TIÊU\nNắm vững kiến thức trọng tâm bài học.\n\n## II. THIẾT BỊ DẠY HỌC\nSách giáo khoa, máy chiếu, học liệu số.\n\n## III. TIẾN TRÌNH DẠY HỌC\n### Hoạt động 1: Khởi động\nNhận diện vấn đề.\n\n### Hoạt động 2: Hình thành kiến thức\nKhám phá bài học.\n\n### Hoạt động 3: Luyện tập\nThực hành bài tập.\n\n### Hoạt động 4: Vận dụng\nLiên hệ thực tiễn.\n\n## IV. ĐÁNH GIÁ\nĐánh giá theo chuẩn đầu ra GDPT 2018.',
        );

    final effectiveWorksheet = worksheet ??
        WorksheetModel(
          id: 'ws_export_all',
          title: 'Phiếu học tập: ${project.lessonTitle}',
          subject: project.subject,
          grade: project.grade,
          tasks: const [
            WorksheetTask(
              id: 't_exp_1',
              instruction: 'Tìm hiểu và trả lời câu hỏi bài học',
              content: 'Tóm tắt nội dung trọng tâm bài học vào phiếu.',
              points: 5,
            ),
          ],
        );

    final effectiveQuestionSet = (questionSet != null && questionSet.items.isNotEmpty)
        ? questionSet
        : QuestionSet(
            id: 'qs_export_all',
            projectId: '',
            title: 'Bộ câu hỏi: ${project.lessonTitle}',
            subject: project.subject,
            grade: project.grade,
            items: const [
              QuestionItem(
                id: 'q_exp_1',
                prompt: 'Nội dung cốt lõi của bài học là gì?',
                choices: ['A. Nội dung A', 'B. Nội dung B', 'C. Nội dung C', 'D. Nội dung D'],
                correctAnswer: 'A',
                difficulty: QuestionDifficulty.nhanBiet,
              ),
            ],
          );

    final effectiveRubric = (rubric != null && rubric.criteria.isNotEmpty)
        ? rubric
        : RubricModel(
            id: 'rub_export_all',
            projectId: '',
            title: 'Rubric đánh giá: ${project.lessonTitle}',
            criteria: const [
              RubricCriterion(
                id: 'c_exp_1',
                name: 'Mức độ nắm vững bài học',
                weight: 50.0,
                levels: [
                  RubricLevel(name: 'Xuất sắc', score: 4.0, description: 'Nắm vững toàn diện.'),
                  RubricLevel(name: 'Tốt', score: 3.0, description: 'Nắm vững cơ bản.'),
                  RubricLevel(name: 'Đạt', score: 2.0, description: 'Nhớ nội dung chính.'),
                  RubricLevel(name: 'Cần cố gắng', score: 1.0, description: 'Chưa đạt yêu cầu.'),
                ],
              ),
              RubricCriterion(
                id: 'c_exp_2',
                name: 'Thái độ và kỹ năng thực hành',
                weight: 50.0,
                levels: [
                  RubricLevel(name: 'Xuất sắc', score: 4.0, description: 'Chủ động, tích cực.'),
                  RubricLevel(name: 'Tốt', score: 3.0, description: 'Hoàn thành nhiệm vụ.'),
                  RubricLevel(name: 'Đạt', score: 2.0, description: 'Tham gia chưa đều.'),
                  RubricLevel(name: 'Cần cố gắng', score: 1.0, description: 'Chưa hoàn thành.'),
                ],
              ),
            ],
          );

    // 1. 01_Giao_an.docx
    try {
      final p1 = p.join(outputDirectory, '01_Giao_an.docx');
      await exportLessonPlan(document: effectivePlan, outputPath: p1);
      exportedPaths['lessonPlan'] = p1;
    } catch (e) {
      failedFiles.add('01_Giao_an.docx');
      errors.add('Lỗi xuất 01_Giao_an.docx: $e');
    }

    // 2. 02_Phieu_hoc_tap.docx
    try {
      final p2 = p.join(outputDirectory, '02_Phieu_hoc_tap.docx');
      await exportWorksheet(worksheet: effectiveWorksheet, outputPath: p2);
      exportedPaths['worksheet'] = p2;
    } catch (e) {
      failedFiles.add('02_Phieu_hoc_tap.docx');
      errors.add('Lỗi xuất 02_Phieu_hoc_tap.docx: $e');
    }

    // 3. 03_Cau_hoi.docx
    try {
      final p3 = p.join(outputDirectory, '03_Cau_hoi.docx');
      await exportQuestionSet(questionSet: effectiveQuestionSet, outputPath: p3);
      exportedPaths['questionSet'] = p3;
    } catch (e) {
      failedFiles.add('03_Cau_hoi.docx');
      errors.add('Lỗi xuất 03_Cau_hoi.docx: $e');
    }

    // 4. 04_Dap_an.docx
    try {
      final p4 = p.join(outputDirectory, '04_Dap_an.docx');
      await exportAnswerKey(questionSet: effectiveQuestionSet, outputPath: p4);
      exportedPaths['answerKey'] = p4;
    } catch (e) {
      failedFiles.add('04_Dap_an.docx');
      errors.add('Lỗi xuất 04_Dap_an.docx: $e');
    }

    // 5. 05_Rubric.docx
    try {
      final p5 = p.join(outputDirectory, '05_Rubric.docx');
      await exportRubric(rubric: effectiveRubric, outputPath: p5);
      exportedPaths['rubric'] = p5;
    } catch (e) {
      failedFiles.add('05_Rubric.docx');
      errors.add('Lỗi xuất 05_Rubric.docx: $e');
    }

    final isAllSuccess = failedFiles.isEmpty && exportedPaths.length == 5;
    AppLogger.info('Batch exported ${exportedPaths.length}/5 Teaching Suite artifacts to: $outputDirectory');
    return ExportAllResult(
      successful: isAllSuccess,
      exportedPaths: exportedPaths,
      failedFiles: failedFiles,
      errors: errors,
    );
  }

  // ==========================================
  // OPENXML PACKAGING & HELPERS
  // ==========================================

  static String _formatLessonPlanFallback(LessonPlanDocument doc) {
    return '''
# I. MỤC TIÊU
${doc.objectives}

# II. THIẾT BỊ DẠY HỌC VÀ HỌC LIỆU
${doc.equipment}

# III. TIẾN TRÌNH DẠY HỌC
${doc.activities.map((a) => "## ${a.title}\n${a.content}").join("\n\n")}

# IV. ĐÁNH GIÁ
${doc.assessment}
''';
  }

  static Future<File> _packageDocx(String bodyContentXml, String outputPath) async {
    final archive = Archive();

    // 1. [Content_Types].xml
    const contentTypesXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\n'
        '  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\n'
        '  <Default Extension="xml" ContentType="application/xml"/>\n'
        '  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>\n'
        '  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>\n'
        '</Types>';
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesXml.length, utf8.encode(contentTypesXml)));

    // 2. _rels/.rels
    const globalRelsXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>\n'
        '</Relationships>';
    archive.addFile(ArchiveFile('_rels/.rels', globalRelsXml.length, utf8.encode(globalRelsXml)));

    // 3. word/_rels/document.xml.rels
    const docRelsXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>\n'
        '</Relationships>';
    archive.addFile(ArchiveFile('word/_rels/document.xml.rels', docRelsXml.length, utf8.encode(docRelsXml)));

    // 4. word/styles.xml
    const stylesXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">\n'
        '  <w:docDefaults>\n'
        '    <w:rPrDefault>\n'
        '      <w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:cs="Times New Roman"/>\n'
        '      <w:sz w:val="26"/>\n'
        '      <w:lang w:val="vi-VN"/>\n'
        '    </w:rPrDefault>\n'
        '  </w:docDefaults>\n'
        '</w:styles>';
    archive.addFile(ArchiveFile('word/styles.xml', stylesXml.length, utf8.encode(stylesXml)));

    // 5. word/document.xml
    final docBuffer = StringBuffer();
    docBuffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    docBuffer.write('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">\n');
    docBuffer.write('  <w:body>\n');
    docBuffer.write(bodyContentXml);
    // Standard A4 Margins: Top 2cm, Bottom 2cm, Left 3cm, Right 1.5cm
    docBuffer.write('    <w:sectPr>\n');
    docBuffer.write('      <w:pgMar w:top="1134" w:right="850" w:bottom="1134" w:left="1701" w:header="708" w:footer="708" w:gutter="0"/>\n');
    docBuffer.write('    </w:sectPr>\n');
    docBuffer.write('  </w:body>\n');
    docBuffer.write('</w:document>');

    final docBytes = utf8.encode(docBuffer.toString());
    archive.addFile(ArchiveFile('word/document.xml', docBytes.length, docBytes));

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw const FormatException('Không thể mã hóa tệp OpenXML (.docx).');
    }

    final file = File(outputPath);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    await file.writeAsBytes(zipBytes);
    return file;
  }

  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _makeParagraph(
    String text, {
    bool isBold = false,
    bool isItalic = false,
    int fontSize = 26, // 13pt default
    String align = 'left',
    int spaceBefore = 0,
    int spaceAfter = 100,
    int indentLeft = 0,
  }) {
    final sb = StringBuffer();
    sb.write('    <w:p>\n');
    sb.write('      <w:pPr>\n');
    if (align != 'left') {
      sb.write('        <w:jc w:val="$align"/>\n');
    }
    if (spaceBefore > 0 || spaceAfter > 0) {
      sb.write('        <w:spacing w:before="$spaceBefore" w:after="$spaceAfter"/>\n');
    }
    if (indentLeft > 0) {
      sb.write('        <w:ind w:left="$indentLeft"/>\n');
    }
    sb.write('      </w:pPr>\n');

    sb.write('      <w:r>\n');
    sb.write('        <w:rPr>\n');
    if (isBold) sb.write('          <w:b/>\n');
    if (isItalic) sb.write('          <w:i/>\n');
    sb.write('          <w:sz w:val="$fontSize"/>\n');
    sb.write('        </w:rPr>\n');
    sb.write('        <w:t xml:space="preserve">${_escapeXml(text)}</w:t>\n');
    sb.write('      </w:r>\n');
    sb.write('    </w:p>\n');
    return sb.toString();
  }

  static String _makeDivider() {
    return _makeParagraph('____________________________________________________', align: 'center', spaceAfter: 140);
  }

  static String _makeTable(List<String> headers, List<List<String>> rows, {List<int>? colWidths}) {
    final sb = StringBuffer();
    sb.write('    <w:tbl>\n');
    sb.write('      <w:tblPr>\n');
    sb.write('        <w:tblW w:w="0" w:type="auto"/>\n');
    sb.write('        <w:tblBorders>\n');
    sb.write('          <w:top w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>\n');
    sb.write('          <w:left w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>\n');
    sb.write('          <w:bottom w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>\n');
    sb.write('          <w:right w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>\n');
    sb.write('          <w:insideH w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>\n');
    sb.write('          <w:insideV w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>\n');
    sb.write('        </w:tblBorders>\n');
    sb.write('      </w:tblPr>\n');

    // Header row
    sb.write('      <w:tr>\n');
    for (int i = 0; i < headers.length; i++) {
      final width = (colWidths != null && i < colWidths.length) ? colWidths[i] : 2000;
      sb.write('        <w:tc>\n');
      sb.write('          <w:tcPr>\n');
      sb.write('            <w:tcW w:w="$width" w:type="dxa"/>\n');
      sb.write('            <w:shd w:val="clear" w:color="auto" w:fill="EFEFEF"/>\n');
      sb.write('          </w:tcPr>\n');
      sb.write(_makeParagraph(headers[i], isBold: true, fontSize: 22, align: 'center', spaceAfter: 60));
      sb.write('        </w:tc>\n');
    }
    sb.write('      </w:tr>\n');

    // Data rows
    for (final row in rows) {
      sb.write('      <w:tr>\n');
      for (int i = 0; i < row.length; i++) {
        final width = (colWidths != null && i < colWidths.length) ? colWidths[i] : 2000;
        sb.write('        <w:tc>\n');
        sb.write('          <w:tcPr>\n');
        sb.write('            <w:tcW w:w="$width" w:type="dxa"/>\n');
        sb.write('          </w:tcPr>\n');
        sb.write(_makeParagraph(row[i], fontSize: 22, spaceAfter: 40));
        sb.write('        </w:tc>\n');
      }
      sb.write('      </w:tr>\n');
    }

    sb.write('    </w:tbl>\n');
    return sb.toString();
  }
}
