import '../../../teaching_suite/domain/models/question_models.dart';
import '../models/exam_answer_key.dart';
import '../models/exam_code.dart';
import '../models/exam_matrix.dart';
import '../models/exam_paper.dart';
import '../models/exam_specification.dart';
import '../services/score_precision_handler.dart';
import 'exam_blueprint_validator.dart';
import 'exam_code_verifier.dart';

/// Preflight check result prior to exporting exam package (Sections 12, 13, 69, 70).
class ExamPreflightValidationResult {
  final bool canExport;
  final bool isDraft;
  final bool isStale;
  final List<String> blockingErrors;
  final List<String> warnings;

  const ExamPreflightValidationResult({
    required this.canExport,
    this.isDraft = false,
    this.isStale = false,
    this.blockingErrors = const [],
    this.warnings = const [],
  });

  bool get hasErrors => blockingErrors.isNotEmpty;
}

/// Comprehensive validator run before DOCX export (Sections 12, 13, 69, 70).
class ExamPreflightValidator {
  final ExamBlueprintValidator _blueprintValidator;
  final ExamCodeVerifier _codeVerifier;

  const ExamPreflightValidator({
    ExamBlueprintValidator blueprintValidator = const ExamBlueprintValidator(),
    ExamCodeVerifier codeVerifier = const ExamCodeVerifier(),
  })  : _blueprintValidator = blueprintValidator,
        _codeVerifier = codeVerifier;

  ExamPreflightValidationResult validate({
    required ExamSpecification specification,
    required ExamMatrix matrix,
    required ExamPaper masterPaper,
    required List<ExamCode> codes,
    required Map<String, ExamAnswerKey> answerKeys,
  }) {
    final List<String> blockingErrors = [];
    final List<String> warnings = [];
    bool isStale = false;

    // 1. Matrix and Blueprint validation
    final bpResult = _blueprintValidator.validate(
      specification: specification,
      matrix: matrix,
    );
    if (!bpResult.isValid) {
      blockingErrors.addAll(bpResult.errors);
    }
    warnings.addAll(bpResult.warnings);

    // 2. Strict ID linkage checks (Section 12)
    if (specification.projectId != masterPaper.assessmentProjectId) {
      blockingErrors.add(
        'PROJECT_ID_MISMATCH: Bản đặc tả thuộc dự án [${specification.projectId}], '
        'nhưng đề thi gốc thuộc dự án [${masterPaper.assessmentProjectId}].',
      );
    }

    if (matrix.specificationId != specification.id) {
      blockingErrors.add(
        'MATRIX_SPEC_MISMATCH: Ma trận đề thi [${matrix.specificationId}] '
        'không liên kết với bản đặc tả [${specification.id}].',
      );
    }

    if (masterPaper.specificationId != specification.id) {
      blockingErrors.add(
        'MASTER_SPEC_MISMATCH: Đề thi gốc [${masterPaper.specificationId}] '
        'không liên kết với bản đặc tả [${specification.id}].',
      );
    }

    // 3. Question Count & Total Score alignment
    if (masterPaper.questions.length != matrix.totalQuestions) {
      blockingErrors.add(
        'QUESTION_COUNT_MISMATCH: Đề thi gốc có ${masterPaper.questions.length} câu, '
        'nhưng ma trận yêu cầu ${matrix.totalQuestions} câu.',
      );
    }

    if ((masterPaper.totalScore - specification.totalScore).abs() > 0.01) {
      blockingErrors.add(
        'TOTAL_SCORE_MISMATCH: Tổng điểm đề thi gốc (${masterPaper.totalScore.toStringAsFixed(2)}) '
        'không khớp với tổng điểm bản đặc tả (${specification.totalScore.toStringAsFixed(2)}).',
      );
    }

    // 4. Duplicate Question IDs in Master Paper
    final masterIds = masterPaper.questions.map((q) => q.questionId).toList();
    if (masterIds.toSet().length != masterIds.length) {
      blockingErrors.add('DUPLICATE_QUESTION_ID: Đề thi gốc chứa các câu hỏi bị trùng lặp ID.');
    }

    // 5. Objective, Difficulty, QuestionType and Score distribution bipartite reconciliation (Section 8)
    final activeCells = matrix.cells.where((c) => c.questionCount > 0).toList();
    final List<_PreflightSlot> demandSlots = [];

    for (final cell in activeCells) {
      final normalizedScore = ScorePrecisionHandler.isValidScore(cell.scorePerQuestion)
          ? ScorePrecisionHandler.fromHundredths(ScorePrecisionHandler.toHundredths(cell.scorePerQuestion))
          : cell.scorePerQuestion;

      if (cell.questionTypeDistribution.isNotEmpty) {
        for (final entry in cell.questionTypeDistribution.entries) {
          final count = entry.value;
          for (int i = 0; i < count; i++) {
            demandSlots.add(_PreflightSlot(
              objectiveId: cell.objectiveId,
              difficulty: cell.difficulty,
              questionType: entry.key,
              score: normalizedScore,
            ));
          }
        }
      } else {
        for (int i = 0; i < cell.questionCount; i++) {
          demandSlots.add(_PreflightSlot(
            objectiveId: cell.objectiveId,
            difficulty: cell.difficulty,
            questionType: null,
            score: normalizedScore,
          ));
        }
      }
    }

    if (masterPaper.questions.length != demandSlots.length) {
      blockingErrors.add(
        'QUESTION_COUNT_MISMATCH: Đề thi gốc có ${masterPaper.questions.length} câu, '
        'nhưng ma trận yêu cầu ${demandSlots.length} câu.',
      );
    } else {
      // Build bipartite matching between demandSlots and masterPaper.questions
      final candidateIndicesPerSlot = List<List<int>>.generate(demandSlots.length, (sIdx) {
        final slot = demandSlots[sIdx];
        final list = <int>[];
        for (int qIdx = 0; qIdx < masterPaper.questions.length; qIdx++) {
          final q = masterPaper.questions[qIdx];
          if (q.difficulty != slot.difficulty) continue;
          if (slot.objectiveId.isNotEmpty && slot.objectiveId != 'ALL') {
            if (q.objectiveId != slot.objectiveId) continue;
          }
          if (slot.questionType != null && q.type != slot.questionType) continue;
          if ((q.score - slot.score).abs() > 0.01) continue;
          list.add(qIdx);
        }
        return list;
      });

      final matchSlotToQ = <int, int>{};
      final matchQToSlot = <int, int>{};

      bool dfsMatch(int slotIdx, Set<int> visited) {
        if (visited.contains(slotIdx)) return false;
        visited.add(slotIdx);

        for (final qIdx in candidateIndicesPerSlot[slotIdx]) {
          final owner = matchQToSlot[qIdx];
          if (owner == null || dfsMatch(owner, visited)) {
            matchSlotToQ[slotIdx] = qIdx;
            matchQToSlot[qIdx] = slotIdx;
            return true;
          }
        }
        return false;
      }

      int matchedCount = 0;
      for (int sIdx = 0; sIdx < demandSlots.length; sIdx++) {
        if (dfsMatch(sIdx, <int>{})) {
          matchedCount++;
        }
      }

      if (matchedCount < demandSlots.length) {
        blockingErrors.add(
          'MATRIX_RECONCILIATION_FAILURE: Các câu hỏi trong đề gốc không thỏa mãn đầy đủ cấu trúc ma trận '
          '(chỉ khớp $matchedCount/${demandSlots.length} vị trí yêu cầu theo mục tiêu, mức độ nhận thức, dạng câu và thang điểm).',
        );
      }
    }

    // 6. Master Paper emptiness & prompt sanity
    if (masterPaper.questions.isEmpty) {
      blockingErrors.add('EMPTY_MASTER_PAPER: Đề thi gốc chưa có câu hỏi nào.');
    } else {
      for (final q in masterPaper.questions) {
        if (q.prompt.trim().isEmpty) {
          blockingErrors.add('EMPTY_PROMPT: Tồn tại câu hỏi trống nội dung trong đề gốc.');
          break;
        }
      }
    }

    if (!masterPaper.isFinalized) {
      warnings.add(
        'EXAM_NOT_FINALIZED: Đề thi đang ở trạng thái Bản nháp (chưa chốt duyệt). '
        'Bản xuất sẽ được gắn dấu BẢN NHÁP.',
      );
    }

    // 7. Multi-code verification against canonical master (Section 12, 13)
    if (codes.isEmpty) {
      blockingErrors.add('NO_EXAM_CODES: Chưa sinh danh sách mã đề cho học sinh.');
    } else {
      // Check stale status: every code must belong to masterPaper.id
      for (final code in codes) {
        if (code.examPaperId != masterPaper.id) {
          isStale = true;
          blockingErrors.add(
            'STALE_EXAM_CODE: Mã đề ${code.code} thuộc bản đề gốc [${code.examPaperId}], '
            'không khớp với đề gốc hiện tại [${masterPaper.id}]. Trạng thái: REGENERATE_REQUIRED.',
          );
        }
      }

      // Hardened code verifier comparing against canonical master
      final codeResult = _codeVerifier.verifyCodes(codes, canonicalMaster: masterPaper);
      if (!codeResult.isEquivalent) {
        blockingErrors.addAll(codeResult.mismatches);
      }

      // 8. Answer key verification against code questions and canonical master
      final keyResult = _codeVerifier.verifyAnswerKeys(
        codes: codes,
        answerKeys: answerKeys,
        canonicalMaster: masterPaper,
      );
      if (!keyResult.isValid) {
        blockingErrors.addAll(keyResult.errors);
      }
    }

    final canExport = blockingErrors.isEmpty;
    final isDraft = !masterPaper.isFinalized;

    return ExamPreflightValidationResult(
      canExport: canExport,
      isDraft: isDraft,
      isStale: isStale,
      blockingErrors: blockingErrors,
      warnings: warnings,
    );
  }
}

class _PreflightSlot {
  final String objectiveId;
  final QuestionDifficulty difficulty;
  final QuestionType? questionType;
  final double score;

  const _PreflightSlot({
    required this.objectiveId,
    required this.difficulty,
    this.questionType,
    required this.score,
  });
}

