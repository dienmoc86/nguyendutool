import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import '../../../core/logging/app_logger.dart';
import '../../../core/projects/data/workspace_project_repository.dart';
import '../../../core/projects/domain/artifact_type.dart';
import '../../../core/projects/domain/project_artifact.dart';
import '../../teaching_suite/domain/models/learning_objective.dart';
import '../../teaching_suite/domain/models/question_models.dart';
import '../domain/models/assessment_project_data.dart';
import '../domain/models/exam_answer_key.dart';
import '../domain/models/exam_code.dart';
import '../domain/models/exam_export_result.dart';
import '../domain/models/exam_matrix.dart';
import '../domain/models/exam_paper.dart';
import '../domain/models/exam_specification.dart';
import '../domain/models/question_choice.dart';

/// Professional OpenXML (.docx) exporter for Assessment Studio (Sections 43 to 53).
/// Fully compliant with Vietnamese educational testing standards and Decree 30/2020/NĐ-CP.
class AssessmentDocxExporter {
  // ==========================================
  // INDIVIDUAL DOCUMENT EXPORTERS
  // ==========================================

  /// Exports Exam Matrix (Ma trận đề kiểm tra) as an OpenXML Word table (Section 48).
  static Future<File> exportMatrix({
    required ExamMatrix matrix,
    required List<LearningObjective> objectives,
    required ExamHeaderConfig headerConfig,
    required String outputPath,
  }) async {
    final bodyBuffer = StringBuffer();

    // Administrative Title
    bodyBuffer.write(_makeParagraph(
      headerConfig.schoolName.toUpperCase(),
      fontSize: 22,
      isBold: true,
      align: 'center',
    ));
    bodyBuffer.write(_makeParagraph(
      'MA TRẬN ĐỀ KIỂM TRA ĐỊNH KỲ - MÔN: ${headerConfig.subject.toUpperCase()} LỚP ${headerConfig.grade}',
      fontSize: 26,
      isBold: true,
      align: 'center',
      spaceBefore: 100,
    ));
    bodyBuffer.write(_makeParagraph(
      'Năm học: ${headerConfig.schoolYear} | Thời gian làm bài: ${headerConfig.durationMinutes} phút',
      fontSize: 22,
      isItalic: true,
      align: 'center',
      spaceAfter: 200,
    ));

    // Matrix Table
    final headers = [
      'TT',
      'Yêu cầu cần đạt / Mạch kiến thức',
      'Nhận biết\n(Số câu / Điểm)',
      'Thông hiểu\n(Số câu / Điểm)',
      'Vận dụng\n(Số câu / Điểm)',
      'Vận dụng cao\n(Số câu / Điểm)',
      'Tổng cộng\n(Số câu / Điểm)',
    ];

    final colWidths = [600, 3200, 1400, 1400, 1400, 1400, 1600];
    final List<List<String>> rows = [];

    // Map objectives or general row
    final effectiveObjs = objectives.isNotEmpty
        ? objectives
        : [const LearningObjective(id: 'ALL', projectId: '', code: 'KT_CHUNG', description: 'Nội dung kiến thức chung theo chương trình')];

    int index = 1;
    for (final obj in effectiveObjs) {
      final nbCount = matrix.getCell(obj.id, QuestionDifficulty.nhanBiet)?.questionCount ?? 0;
      final nbScore = matrix.getCell(obj.id, QuestionDifficulty.nhanBiet)?.cellTotalScore ?? 0.0;

      final thCount = matrix.getCell(obj.id, QuestionDifficulty.thongHieu)?.questionCount ?? 0;
      final thScore = matrix.getCell(obj.id, QuestionDifficulty.thongHieu)?.cellTotalScore ?? 0.0;

      final vdCount = matrix.getCell(obj.id, QuestionDifficulty.vanDung)?.questionCount ?? 0;
      final vdScore = matrix.getCell(obj.id, QuestionDifficulty.vanDung)?.cellTotalScore ?? 0.0;

      final vdcCount = matrix.getCell(obj.id, QuestionDifficulty.vanDungCao)?.questionCount ?? 0;
      final vdcScore = matrix.getCell(obj.id, QuestionDifficulty.vanDungCao)?.cellTotalScore ?? 0.0;

      final totalObjCount = nbCount + thCount + vdCount + vdcCount;
      final totalObjScore = nbScore + thScore + vdScore + vdcScore;

      rows.add([
        '$index',
        '[${obj.code}] ${obj.description}',
        '$nbCount câu\n(${nbScore.toStringAsFixed(2)} đ)',
        '$thCount câu\n(${thScore.toStringAsFixed(2)} đ)',
        '$vdCount câu\n(${vdScore.toStringAsFixed(2)} đ)',
        '$vdcCount câu\n(${vdcScore.toStringAsFixed(2)} đ)',
        '$totalObjCount câu\n(${totalObjScore.toStringAsFixed(2)} đ)',
      ]);
      index++;
    }

    // Summary Totals Row
    final totalNbCount = matrix.getQuestionCountByDifficulty(QuestionDifficulty.nhanBiet);
    final totalNbScore = matrix.getScoreByDifficulty(QuestionDifficulty.nhanBiet);
    final totalThCount = matrix.getQuestionCountByDifficulty(QuestionDifficulty.thongHieu);
    final totalThScore = matrix.getScoreByDifficulty(QuestionDifficulty.thongHieu);
    final totalVdCount = matrix.getQuestionCountByDifficulty(QuestionDifficulty.vanDung);
    final totalVdScore = matrix.getScoreByDifficulty(QuestionDifficulty.vanDung);
    final totalVdcCount = matrix.getQuestionCountByDifficulty(QuestionDifficulty.vanDungCao);
    final totalVdcScore = matrix.getScoreByDifficulty(QuestionDifficulty.vanDungCao);

    rows.add([
      'Tổng',
      'Tổng số câu / Tổng điểm',
      '$totalNbCount câu\n(${totalNbScore.toStringAsFixed(2)} đ)',
      '$totalThCount câu\n(${totalThScore.toStringAsFixed(2)} đ)',
      '$totalVdCount câu\n(${totalVdScore.toStringAsFixed(2)} đ)',
      '$totalVdcCount câu\n(${totalVdcScore.toStringAsFixed(2)} đ)',
      '${matrix.totalQuestionCount} câu\n(${matrix.totalScore.toStringAsFixed(2)} đ)',
    ]);

    // Percentage row
    final totalPoints = matrix.totalScore > 0 ? matrix.totalScore : 10.0;
    rows.add([
      'Tỉ lệ',
      'Tỉ lệ phần trăm điểm số',
      '${(totalNbScore / totalPoints * 100).toStringAsFixed(1)}%',
      '${(totalThScore / totalPoints * 100).toStringAsFixed(1)}%',
      '${(totalVdScore / totalPoints * 100).toStringAsFixed(1)}%',
      '${(totalVdcScore / totalPoints * 100).toStringAsFixed(1)}%',
      '100%',
    ]);

    bodyBuffer.write(_makeTable(headers, rows, colWidths: colWidths));
    return _buildDocxArchive(bodyBuffer.toString(), outputPath);
  }

  /// Exports Exam Specification (Bản đặc tả đề kiểm tra) (Section 49).
  static Future<File> exportSpecification({
    required ExamSpecification specification,
    required ExamMatrix matrix,
    required List<LearningObjective> objectives,
    required ExamHeaderConfig headerConfig,
    required String outputPath,
  }) async {
    final bodyBuffer = StringBuffer();

    bodyBuffer.write(_makeParagraph(
      headerConfig.schoolName.toUpperCase(),
      fontSize: 22,
      isBold: true,
      align: 'center',
    ));
    bodyBuffer.write(_makeParagraph(
      'BẢN ĐẶC TẢ KỸ THUẬT ĐỀ KIỂM TRA ĐỊNH KỲ',
      fontSize: 26,
      isBold: true,
      align: 'center',
      spaceBefore: 100,
    ));
    bodyBuffer.write(_makeParagraph(
      'Môn học: ${specification.subject} - Lớp: ${specification.grade} | Thời gian: ${specification.durationMinutes} phút | Tổng điểm: ${specification.totalScore.toStringAsFixed(1)} đ',
      fontSize: 22,
      isItalic: true,
      align: 'center',
      spaceAfter: 150,
    ));

    if (specification.instructions != null && specification.instructions!.isNotEmpty) {
      bodyBuffer.write(_makeParagraph(
        'Hướng dẫn chung: ${specification.instructions}',
        fontSize: 22,
        spaceAfter: 100,
      ));
    }

    final headers = [
      'TT',
      'Nội dung / Mạch kiến thức',
      'Yêu cầu cần đạt (Mục tiêu)',
      'Mức độ nhận thức',
      'Hình thức câu hỏi',
      'Số câu',
      'Điểm',
    ];
    final colWidths = [500, 2200, 3500, 1500, 1600, 800, 900];
    final List<List<String>> rows = [];

    int index = 1;
    final effectiveObjs = objectives.isNotEmpty
        ? objectives
        : [const LearningObjective(id: 'ALL', projectId: '', code: 'KT_CHUNG', description: 'Nội dung kiến thức chung')];

    for (final obj in effectiveObjs) {
      for (final diff in QuestionDifficulty.values) {
        final cell = matrix.getCell(obj.id, diff);
        if (cell != null && cell.questionCount > 0) {
          rows.add([
            '$index',
            obj.category ?? 'Kiến thức trọng tâm',
            '[${obj.code}] ${obj.description}',
            diff.label,
            'Trắc nghiệm / Tự luận',
            '${cell.questionCount}',
            cell.cellTotalScore.toStringAsFixed(2),
          ]);
          index++;
        }
      }
    }

    bodyBuffer.write(_makeTable(headers, rows, colWidths: colWidths));
    return _buildDocxArchive(bodyBuffer.toString(), outputPath);
  }

  /// Exports Student Exam Paper for a specific Exam Code (Sections 45 & 46).
  /// Strictly guarantees NO teacher hints or answers are visible in the student paper!
  static Future<File> exportExamCode({
    required ExamCode examCode,
    required ExamHeaderConfig headerConfig,
    required String outputPath,
    bool isDraft = false,
  }) async {
    final bodyBuffer = StringBuffer();

    // 1. Two-Column Exam Header Table (Administrative standard)
    bodyBuffer.write(_makeHeaderTable(headerConfig, examCode.code));

    // Draft Watermark Banner if draft mode
    if (isDraft) {
      bodyBuffer.write(_makeParagraph(
        '*** BẢN NHÁP - DRAFT PREVIEW (CHƯA PHÊ DUYỆT CHÍNH THỨC) ***',
        fontSize: 22,
        isBold: true,
        isItalic: true,
        align: 'center',
        spaceBefore: 60,
        spaceAfter: 100,
      ));
    }

    bodyBuffer.write(_makeDivider());

    // Group questions by section
    final mcqQuestions = examCode.questions.where((q) => q.snapshot.sectionIndex == 0).toList();
    final shortQuestions = examCode.questions.where((q) => q.snapshot.sectionIndex == 1).toList();
    final essayQuestions = examCode.questions.where((q) => q.snapshot.sectionIndex == 2).toList();

    // SECTION I: MCQ
    if (mcqQuestions.isNotEmpty) {
      final totalMcqScore = mcqQuestions.fold(0.0, (s, q) => s + q.score);
      bodyBuffer.write(_makeParagraph(
        'PHẦN I. CÂU HỎI TRẮC NGHIỆM NHIỀU PHƯƠNG ÁN LỰA CHỌN '
        '(${mcqQuestions.length} câu, ${totalMcqScore.toStringAsFixed(2)} điểm)',
        fontSize: 24,
        isBold: true,
        spaceBefore: 120,
        spaceAfter: 80,
      ));
      bodyBuffer.write(_makeParagraph(
        'Thí sinh trả lời từ câu 1 đến câu ${mcqQuestions.length}. Mỗi câu hỏi thí sinh chỉ chọn một phương án.',
        fontSize: 22,
        isItalic: true,
        spaceAfter: 100,
      ));

      for (int i = 0; i < mcqQuestions.length; i++) {
        final q = mcqQuestions[i];
        final qNumber = i + 1;

        // Prompt
        bodyBuffer.write(_makeParagraph(
          'Câu $qNumber (${q.score.toStringAsFixed(2)} điểm): ${q.snapshot.prompt}',
          fontSize: 24,
          isBold: true,
          spaceBefore: 60,
          spaceAfter: 40,
        ));

        // Choices (A, B, C, D) in shuffled order
        final choices = q.orderedChoices;
        for (int cIdx = 0; cIdx < choices.length; cIdx++) {
          final letter = QuestionChoice.indexToLetter(cIdx);
          bodyBuffer.write(_makeParagraph(
            '    $letter. ${choices[cIdx].text}',
            fontSize: 24,
            indentLeft: 400,
            spaceAfter: 20,
          ));
        }
      }
    }

    // SECTION II: SHORT ANSWER / TRUE FALSE
    if (shortQuestions.isNotEmpty) {
      final totalShortScore = shortQuestions.fold(0.0, (s, q) => s + q.score);
      final startNum = mcqQuestions.length + 1;
      final endNum = mcqQuestions.length + shortQuestions.length;

      bodyBuffer.write(_makeParagraph(
        'PHẦN II. CÂU HỎI ĐÚNG / SAI HOẶC TRẢ LỜI NGẮN '
        '(${shortQuestions.length} câu, ${totalShortScore.toStringAsFixed(2)} điểm)',
        fontSize: 24,
        isBold: true,
        spaceBefore: 160,
        spaceAfter: 80,
      ));
      bodyBuffer.write(_makeParagraph(
        'Thí sinh trả lời từ câu $startNum đến câu $endNum.',
        fontSize: 22,
        isItalic: true,
        spaceAfter: 100,
      ));

      for (int i = 0; i < shortQuestions.length; i++) {
        final q = shortQuestions[i];
        final qNumber = startNum + i;

        bodyBuffer.write(_makeParagraph(
          'Câu $qNumber (${q.score.toStringAsFixed(2)} điểm): ${q.snapshot.prompt}',
          fontSize: 24,
          isBold: true,
          spaceBefore: 60,
          spaceAfter: 40,
        ));

        bodyBuffer.write(_makeParagraph(
          'Trả lời: ................................................................................................................................',
          fontSize: 22,
          indentLeft: 400,
          spaceAfter: 60,
        ));
      }
    }

    // SECTION III: ESSAY
    if (essayQuestions.isNotEmpty) {
      final totalEssayScore = essayQuestions.fold(0.0, (s, q) => s + q.score);
      final startNum = mcqQuestions.length + shortQuestions.length + 1;
      final endNum = examCode.questions.length;

      bodyBuffer.write(_makeParagraph(
        'PHẦN III. TỰ LUẬN (${essayQuestions.length} câu, ${totalEssayScore.toStringAsFixed(2)} điểm)',
        fontSize: 24,
        isBold: true,
        spaceBefore: 160,
        spaceAfter: 80,
      ));
      bodyBuffer.write(_makeParagraph(
        'Thí sinh trình bày chi tiết bài làm từ câu $startNum đến câu $endNum.',
        fontSize: 22,
        isItalic: true,
        spaceAfter: 100,
      ));

      for (int i = 0; i < essayQuestions.length; i++) {
        final q = essayQuestions[i];
        final qNumber = startNum + i;

        bodyBuffer.write(_makeParagraph(
          'Câu $qNumber (${q.score.toStringAsFixed(2)} điểm): ${q.snapshot.prompt}',
          fontSize: 24,
          isBold: true,
          spaceBefore: 60,
          spaceAfter: 60,
        ));

        // Answer lines for student
        for (int l = 0; l < 4; l++) {
          bodyBuffer.write(_makeParagraph(
            '.....................................................................................................................................................................',
            fontSize: 20,
            spaceAfter: 30,
          ));
        }
      }
    }

    // Standard Examination Footer
    bodyBuffer.write(_makeParagraph(
      '---------------------------------------- HẾT ----------------------------------------',
      fontSize: 22,
      isBold: true,
      align: 'center',
      spaceBefore: 180,
      spaceAfter: 40,
    ));
    bodyBuffer.write(_makeParagraph(
      'Cán bộ coi thi không giải thích gì thêm. Thí sinh không được sử dụng tài liệu.',
      fontSize: 20,
      isItalic: true,
      align: 'center',
      spaceAfter: 100,
    ));

    return _buildDocxArchive(bodyBuffer.toString(), outputPath);
  }

  /// Exports Answer Key and Grading Guide (Hướng dẫn chấm và Đáp án) (Section 37).
  static Future<File> exportAnswerKey({
    required ExamAnswerKey answerKey,
    required ExamHeaderConfig headerConfig,
    required String outputPath,
  }) async {
    final bodyBuffer = StringBuffer();

    bodyBuffer.write(_makeParagraph(
      headerConfig.schoolName.toUpperCase(),
      fontSize: 22,
      isBold: true,
      align: 'center',
    ));
    bodyBuffer.write(_makeParagraph(
      'HƯỚNG DẪN CHẤM & ĐÁP ÁN ĐỀ KIỂM TRA ĐỊNH KỲ',
      fontSize: 26,
      isBold: true,
      align: 'center',
      spaceBefore: 80,
    ));
    bodyBuffer.write(_makeParagraph(
      'MÔN: ${headerConfig.subject.toUpperCase()} - LỚP ${headerConfig.grade} | MÃ ĐỀ: ${answerKey.examCode}',
      fontSize: 24,
      isBold: true,
      align: 'center',
      spaceBefore: 40,
      spaceAfter: 160,
    ));

    // MCQ Answer Table
    final mcqItems = answerKey.items.where((i) => i.type == QuestionType.multipleChoice).toList();
    if (mcqItems.isNotEmpty) {
      bodyBuffer.write(_makeParagraph(
        'I. BẢNG ĐÁP ÁN TRẮC NGHIỆM',
        fontSize: 24,
        isBold: true,
        spaceAfter: 80,
      ));

      final headers = ['Câu', 'Đáp án', 'Điểm', 'Nội dung vắn tắt / Hướng dẫn giải'];
      final colWidths = [800, 1000, 900, 7300];
      final List<List<String>> rows = [];

      for (final item in mcqItems) {
        rows.add([
          'Câu ${item.questionNumber}',
          item.correctDisplayAnswer,
          item.score.toStringAsFixed(2),
          item.explanation ?? item.promptSnippet,
        ]);
      }
      bodyBuffer.write(_makeTable(headers, rows, colWidths: colWidths));
    }

    // Non-MCQ Rubric / Expected Answer
    final otherItems = answerKey.items.where((i) => i.type != QuestionType.multipleChoice).toList();
    if (otherItems.isNotEmpty) {
      bodyBuffer.write(_makeParagraph(
        'II. HƯỚNG DẪN CHẤM TỰ LUẬN & ĐIỀN KHUYẾT',
        fontSize: 24,
        isBold: true,
        spaceBefore: 160,
        spaceAfter: 80,
      ));

      final headers = ['Câu', 'Yêu cầu cần đạt / Đáp án', 'Điểm'];
      final colWidths = [1000, 7800, 1200];
      final List<List<String>> rows = [];

      for (final item in otherItems) {
        rows.add([
          'Câu ${item.questionNumber}',
          '${item.promptSnippet}\n- Hướng dẫn chấm: ${item.correctDisplayAnswer}\n${item.explanation ?? ""}',
          item.score.toStringAsFixed(2),
        ]);
      }
      bodyBuffer.write(_makeTable(headers, rows, colWidths: colWidths));
    }

    return _buildDocxArchive(bodyBuffer.toString(), outputPath);
  }

  /// Exports Cross-Code Summary Matrix (Bảng đáp án tổng hợp các mã đề) (Section 43).
  static Future<File> exportSummaryAnswerSheet({
    required List<ExamCode> codes,
    required Map<String, ExamAnswerKey> answerKeys,
    required ExamHeaderConfig headerConfig,
    required String outputPath,
  }) async {
    final bodyBuffer = StringBuffer();

    bodyBuffer.write(_makeParagraph(
      headerConfig.schoolName.toUpperCase(),
      fontSize: 22,
      isBold: true,
      align: 'center',
    ));
    bodyBuffer.write(_makeParagraph(
      'BẢNG ĐÁP ÁN TỔNG HỢP CÁC MÃ ĐỀ THI',
      fontSize: 26,
      isBold: true,
      align: 'center',
      spaceBefore: 80,
      spaceAfter: 160,
    ));

    final bool hasUniformScores = codes.every((c) =>
        c.questions.every((q) => (q.score - c.questions.first.score).abs() < 0.001));

    final codeList = codes.map((c) => c.code).toList();
    List<String> headers;
    if (hasUniformScores) {
      headers = ['Câu hỏi', ...codeList.map((c) => 'Mã $c'), 'Thang điểm'];
    } else {
      headers = [
        'Câu hỏi',
        ...codeList.map((c) => 'Mã $c (Đáp án / Điểm)'),
      ];
    }

    final int maxQuestions = codes.isNotEmpty ? codes.first.questionCount : 0;
    final List<List<String>> rows = [];

    for (int q = 1; q <= maxQuestions; q++) {
      final List<String> row = ['Câu $q'];

      for (final code in codeList) {
        final key = answerKeys[code];
        final item = key?.items.firstWhere(
          (it) => it.questionNumber == q,
          orElse: () => ExamAnswerKeyItem(
            questionNumber: q,
            correctDisplayAnswer: '-',
            score: 0.0,
            questionId: '',
            promptSnippet: '',
          ),
        );
        final ans = item?.correctDisplayAnswer ?? '-';
        if (hasUniformScores) {
          row.add(ans);
        } else {
          final sc = item != null ? item.score.toStringAsFixed(2) : '0.00';
          row.add('$ans ($sc đ)');
        }
      }

      if (hasUniformScores) {
        final sampleScore = codes.isNotEmpty && codes.first.questions.isNotEmpty
            ? codes.first.questions.first.score
            : 0.25;
        row.add(sampleScore.toStringAsFixed(2));
      }
      rows.add(row);
    }

    bodyBuffer.write(_makeTable(headers, rows));
    return _buildDocxArchive(bodyBuffer.toString(), outputPath);
  }

  // ==========================================
  // BATCH EXPORT PACKAGE (Section 50)
  // ==========================================

  /// Exports full examination suite into a versioned folder and registers ProjectArtifacts.
  static Future<ExamExportResult> exportPackage({
    required AssessmentProjectData project,
    required ExamSpecification specification,
    required ExamMatrix matrix,
    required List<LearningObjective> objectives,
    required ExamPaper masterPaper,
    required List<ExamCode> codes,
    required Map<String, ExamAnswerKey> answerKeys,
    required String baseExportDir,
    WorkspaceProjectRepository? projectRepository,
  }) async {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final safeName = project.name
        .replaceAll(RegExp(r'[^\w\s\u00C0-\u1EF9]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');

    final exportFolder = Directory(p.join(baseExportDir, 'Assessment', safeName, timestamp));
    try {
      if (!exportFolder.existsSync()) {
        exportFolder.createSync(recursive: true);
      }
    } catch (e) {
      AppLogger.error('Failed to create assessment export directory: $e');
      return ExamExportResult(
        successful: false,
        exportDirectory: exportFolder.path,
        errors: ['Lỗi tạo thư mục xuất tệp: $e'],
      );
    }

    final List<String> successfulFiles = [];
    final List<String> failedFiles = [];
    final List<String> errors = [];

    // Helper to run individual export safely
    Future<void> runStep(
      String fileBasename,
      String artifactSubtype,
      Future<File> Function(String path) exporter, {
      String? specificExamCode,
    }) async {
      final outPath = p.join(exportFolder.path, fileBasename);
      try {
        final file = await exporter(outPath);
        if (file.existsSync()) {
          successfulFiles.add(file.path);

          // Register ProjectArtifact with exact metadata (Section 20)
          if (projectRepository != null) {
            try {
              final artifactCode = specificExamCode ?? masterPaper.examCode;
              final artifact = ProjectArtifact(
                id: 'art_${project.id}_${artifactSubtype}_${fileBasename.replaceAll('.', '_')}_${DateTime.now().millisecondsSinceEpoch}',
                projectId: project.id,
                artifactType: ArtifactType.docx,
                filePath: file.path,
                createdAt: DateTime.now(),
                metadataJson: jsonEncode({
                  'assessmentProjectId': project.id,
                  'examId': masterPaper.id,
                  'masterPaperId': masterPaper.id,
                  'examCode': artifactCode,
                  'artifactSubtype': artifactSubtype,
                  'revision': masterPaper.revisionNumber,
                  'revisionNumber': masterPaper.revisionNumber,
                  'exportTimestamp': timestamp,
                  'file_name': fileBasename,
                  'file_size': file.lengthSync(),
                }),
              );
              await projectRepository.attachArtifact(artifact);
            } catch (artErr) {
              AppLogger.warning('Failed to register ProjectArtifact for $fileBasename: $artErr');
              failedFiles.add(fileBasename);
              errors.add('Lỗi đăng ký ProjectArtifact cho $fileBasename: $artErr');
            }
          }
        } else {
          failedFiles.add(fileBasename);
          errors.add('Tệp $fileBasename không tồn tại sau khi xuất.');
        }
      } catch (e) {
        failedFiles.add(fileBasename);
        errors.add('Lỗi xuất $fileBasename: $e');
        AppLogger.error('Export error on $fileBasename: $e');
      }
    }

    // 1. Ma trận đề
    await runStep(
      '01_Ma_tran_de.docx',
      'exam_matrix',
      (path) => exportMatrix(
        matrix: matrix,
        objectives: objectives,
        headerConfig: project.headerConfig,
        outputPath: path,
      ),
      specificExamCode: 'MATRIX',
    );

    // 2. Bản đặc tả đề
    await runStep(
      '02_Ban_dac_ta.docx',
      'exam_specification',
      (path) => exportSpecification(
        specification: specification,
        matrix: matrix,
        objectives: objectives,
        headerConfig: project.headerConfig,
        outputPath: path,
      ),
      specificExamCode: 'SPEC',
    );

    // 3. Đề thi gốc MASTER
    await runStep(
      '03_De_Goc_MASTER.docx',
      'exam_paper',
      (path) {
        final masterCode = ExamCode(
          id: 'ec_${masterPaper.id}_MASTER',
          examPaperId: masterPaper.id,
          code: 'MASTER',
          questions: masterPaper.questions.asMap().entries.map((e) {
            return ExamCodeQuestion(
              id: 'ecq_m_${e.key}',
              examCodeId: 'ec_${masterPaper.id}_MASTER',
              questionId: e.value.questionId,
              orderIndex: e.key,
              score: e.value.score,
              correctDisplayAnswer: e.value.correctAnswerText,
              snapshot: e.value,
            );
          }).toList(),
          createdAt: DateTime.now(),
        );
        return exportExamCode(
          examCode: masterCode,
          headerConfig: project.headerConfig,
          outputPath: path,
          isDraft: !masterPaper.isFinalized,
        );
      },
      specificExamCode: 'MASTER',
    );

    // 4. Các mã đề thi học sinh (De_101.docx, De_102.docx...)
    for (final code in codes) {
      await runStep(
        'De_${code.code}.docx',
        'student_exam',
        (path) => exportExamCode(
          examCode: code,
          headerConfig: project.headerConfig,
          outputPath: path,
          isDraft: !masterPaper.isFinalized,
        ),
        specificExamCode: code.code,
      );
    }

    // 5. Bảng đáp án từng mã đề (Dap_an_101.docx...)
    for (final code in codes) {
      final key = answerKeys[code.code];
      if (key != null) {
        await runStep(
          'Dap_an_${code.code}.docx',
          'answer_key',
          (path) => exportAnswerKey(
            answerKey: key,
            headerConfig: project.headerConfig,
            outputPath: path,
          ),
          specificExamCode: code.code,
        );
      }
    }

    // 6. Bảng đáp án tổng hợp
    if (codes.isNotEmpty) {
      await runStep(
        'Bang_Dap_an_Tong_hop.docx',
        'summary_answer_sheet',
        (path) => exportSummaryAnswerSheet(
          codes: codes,
          answerKeys: answerKeys,
          headerConfig: project.headerConfig,
          outputPath: path,
        ),
        specificExamCode: 'ALL_CODES',
      );
    }

    final isOverallSuccess = failedFiles.isEmpty && successfulFiles.isNotEmpty;
    return ExamExportResult(
      successful: isOverallSuccess,
      exportDirectory: exportFolder.path,
      successfulFiles: successfulFiles,
      failedFiles: failedFiles,
      errors: errors,
    );
  }

  // ==========================================
  // OPENXML PACKAGING HELPERS
  // ==========================================

  static Future<File> _buildDocxArchive(String bodyXml, String outputPath) async {
    final archive = Archive();

    // 1. [Content_Types].xml
    const contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>''';
    final ctBytes = utf8.encode(contentTypesXml);
    archive.addFile(ArchiveFile('[Content_Types].xml', ctBytes.length, ctBytes));

    // 2. _rels/.rels
    const rootRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
    final relsBytes = utf8.encode(rootRelsXml);
    archive.addFile(ArchiveFile('_rels/.rels', relsBytes.length, relsBytes));

    // 3. word/_rels/document.xml.rels
    const docRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';
    final docRelsBytes = utf8.encode(docRelsXml);
    archive.addFile(ArchiveFile('word/_rels/document.xml.rels', docRelsBytes.length, docRelsBytes));

    // 4. word/styles.xml
    const stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:cs="Times New Roman"/>
        <w:sz w:val="26"/>
        <w:szCs w:val="26"/>
        <w:lang w:val="vi-VN"/>
      </w:rPr>
    </w:rPrDefault>
    <w:pPrDefault>
      <w:pPr>
        <w:spacing w:line="276" w:lineRule="auto" w:after="100"/>
      </w:pPr>
    </w:pPrDefault>
  </w:docDefaults>
</w:styles>''';
    final stylesBytes = utf8.encode(stylesXml);
    archive.addFile(ArchiveFile('word/styles.xml', stylesBytes.length, stylesBytes));

    // 5. word/document.xml
    final docBuffer = StringBuffer();
    docBuffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    docBuffer.write('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">\n');
    docBuffer.write('  <w:body>\n');
    docBuffer.write(bodyXml);
    docBuffer.write('    <w:sectPr>\n');
    docBuffer.write('      <w:pgSz w:w="11906" w:h="16838"/>\n'); // A4 Portrait
    docBuffer.write('      <w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1418"/>\n'); // Decree 30 margins
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
    int fontSize = 26, // 13pt
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

  static String _makeHeaderTable(ExamHeaderConfig headerConfig, String examCode) {
    final sb = StringBuffer();
    sb.write('    <w:tbl>\n');
    sb.write('      <w:tblPr>\n');
    sb.write('        <w:tblW w:w="0" w:type="auto"/>\n');
    sb.write('        <w:tblBorders>\n');
    sb.write('          <w:top w:val="none"/>\n');
    sb.write('          <w:left w:val="none"/>\n');
    sb.write('          <w:bottom w:val="none"/>\n');
    sb.write('          <w:right w:val="none"/>\n');
    sb.write('          <w:insideH w:val="none"/>\n');
    sb.write('          <w:insideV w:val="none"/>\n');
    sb.write('        </w:tblBorders>\n');
    sb.write('      </w:tblPr>\n');

    sb.write('      <w:tr>\n');
    // Left column: School and Exam
    sb.write('        <w:tc>\n');
    sb.write('          <w:tcPr><w:tcW w:w="5800" w:type="dxa"/></w:tcPr>\n');
    sb.write(_makeParagraph(headerConfig.schoolName.toUpperCase(), isBold: true, fontSize: 22, align: 'center', spaceAfter: 20));
    sb.write(_makeParagraph('${headerConfig.examTitle.toUpperCase()} - ${headerConfig.semester.toUpperCase()}', isBold: true, fontSize: 24, align: 'center', spaceAfter: 20));
    sb.write(_makeParagraph('NĂM HỌC: ${headerConfig.schoolYear}', fontSize: 20, isItalic: true, align: 'center', spaceAfter: 20));
    sb.write(_makeParagraph('Môn: ${headerConfig.subject} - Lớp: ${headerConfig.grade}', isBold: true, fontSize: 22, align: 'center', spaceAfter: 20));
    sb.write(_makeParagraph('Thời gian: ${headerConfig.durationMinutes} phút (không kể phát đề)', isItalic: true, fontSize: 20, align: 'center', spaceAfter: 60));
    sb.write('        </w:tc>\n');

    // Right column: Student info & Code Box
    sb.write('        <w:tc>\n');
    sb.write('          <w:tcPr><w:tcW w:w="4800" w:type="dxa"/></w:tcPr>\n');
    sb.write(_makeParagraph('MÃ ĐỀ THI: $examCode', isBold: true, fontSize: 26, align: 'center', spaceBefore: 20, spaceAfter: 60));
    sb.write(_makeParagraph(headerConfig.studentNameLine, fontSize: 20, spaceAfter: 30));
    sb.write(_makeParagraph(headerConfig.classLine, fontSize: 20, spaceAfter: 30));
    sb.write(_makeParagraph('Chữ ký CB coi thi 1: ......... CB coi thi 2: .........', fontSize: 18, isItalic: true, spaceAfter: 60));
    sb.write('        </w:tc>\n');
    sb.write('      </w:tr>\n');

    sb.write('    </w:tbl>\n');
    return sb.toString();
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

    // Headers
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

    // Rows
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
