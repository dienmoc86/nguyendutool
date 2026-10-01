import 'dart:math';
import '../../../teaching_suite/domain/models/question_models.dart';
import '../models/exam_matrix.dart';
import '../models/exam_question_snapshot.dart';
import 'score_precision_handler.dart';

/// Detailed deficit report when Question Bank does not have enough items (Sections 27, Finding 6).
class ExamSelectionShortage {
  final String objectiveId;
  final QuestionDifficulty difficulty;
  final QuestionType? questionType;
  final int requiredCount;
  final int availableCount;

  const ExamSelectionShortage({
    required this.objectiveId,
    required this.difficulty,
    this.questionType,
    required this.requiredCount,
    required this.availableCount,
  });

  int get deficit => requiredCount - availableCount;

  @override
  String toString() {
    final typeStr = questionType != null ? ' - Dạng [${questionType!.label}]' : '';
    return 'Mục tiêu [$objectiveId] - Mức [${difficulty.label}]$typeStr: Yêu cầu $requiredCount câu, ngân hàng có $availableCount câu (thiếu $deficit câu).';
  }
}

/// Result of deterministic matrix question selection (Section 26).
class ExamSelectionResult {
  final bool isSuccess;
  final List<ExamQuestionSnapshot> questions;
  final List<ExamSelectionShortage> shortages;
  final String? errorMessage;

  const ExamSelectionResult({
    required this.isSuccess,
    this.questions = const [],
    this.shortages = const [],
    this.errorMessage,
  });

  factory ExamSelectionResult.success(List<ExamQuestionSnapshot> questions) => ExamSelectionResult(
        isSuccess: true,
        questions: questions,
      );

  factory ExamSelectionResult.failure(List<ExamSelectionShortage> shortages, [String? message]) =>
      ExamSelectionResult(
        isSuccess: false,
        shortages: shortages,
        errorMessage: message ??
            'Ngân hàng câu hỏi không đủ số lượng câu hỏi để thỏa mãn ma trận đề (thiếu ${shortages.fold(0, (s, sh) => s + sh.deficit)} câu).',
      );
}

class _DemandGroup {
  final String objectiveId;
  final QuestionDifficulty difficulty;
  final QuestionType? questionType;
  final int requiredCount;
  final double score;

  const _DemandGroup({
    required this.objectiveId,
    required this.difficulty,
    this.questionType,
    required this.requiredCount,
    required this.score,
  });

  String get key => '${objectiveId}_${difficulty.name}_${questionType?.name ?? "ANY"}';
}

class _SelectionSlot {
  final int index;
  final String objectiveId;
  final QuestionDifficulty difficulty;
  final QuestionType? questionType;
  final double score;
  final String groupKey;

  const _SelectionSlot({
    required this.index,
    required this.objectiveId,
    required this.difficulty,
    this.questionType,
    required this.score,
    required this.groupKey,
  });

  bool matches(QuestionItem q) {
    if (q.difficulty != difficulty) return false;
    if (objectiveId.isNotEmpty && objectiveId != 'ALL') {
      if (q.learningObjective != objectiveId) return false;
    }
    if (questionType != null && q.type != questionType) return false;
    return true;
  }
}

/// Engine to select questions from Question Bank satisfying Exam Matrix (Sections 26-28, Phase 7R.2 Sections 8-10).
/// Uses deterministic constraint-aware allocation (maximum bipartite matching with MRV heuristic)
/// to guarantee finding a valid assignment when feasible and avoid greedy starvation traps.
class ExamQuestionSelector {
  const ExamQuestionSelector();

  /// Validates candidate question integrity (Section 8).
  static bool isValidCandidate(QuestionItem q) {
    if (q.prompt.trim().isEmpty) return false;
    if (q.type == QuestionType.multipleChoice) {
      if (q.choices.length != 4) return false;
      if (q.choices.any((c) => c.trim().isEmpty)) return false;
      final ans = q.correctAnswer.trim().toUpperCase();
      if (ans.isEmpty) return false;
      if (ans == 'A' || ans == 'B' || ans == 'C' || ans == 'D') return true;
      final cleanAns = ans.replaceFirst(RegExp(r'^[A-D][\.\:\)]\s*'), '').trim().toLowerCase();
      final matchCount = q.choices.where((c) => c.trim().toLowerCase() == cleanAns).length;
      if (matchCount != 1) return false;
    }
    return true;
  }

  ExamSelectionResult selectQuestions({
    required ExamMatrix matrix,
    required List<QuestionItem> questionBank,
    int? randomSeed,
  }) {
    // Filter only cells that require at least 1 question
    final activeCells = matrix.cells.where((c) => c.questionCount > 0).toList();

    // Section 10: Validate score precision and matrix consistency
    for (final cell in activeCells) {
      if (!ScorePrecisionHandler.isValidScore(cell.scorePerQuestion)) {
        return ExamSelectionResult.failure(
          [],
          'Thang điểm từng câu không hợp lệ hoặc vượt quá 2 chữ số thập phân tại mục tiêu ${cell.objectiveId}.',
        );
      }

      if (cell.questionTypeDistribution.isNotEmpty) {
        final distTotal = cell.questionTypeDistribution.values.fold(0, (sum, count) => sum + count);
        if (distTotal != cell.questionCount) {
          return ExamSelectionResult.failure(
            [
              ExamSelectionShortage(
                objectiveId: cell.objectiveId.isNotEmpty ? cell.objectiveId : 'Chung',
                difficulty: cell.difficulty,
                requiredCount: cell.questionCount,
                availableCount: distTotal,
              ),
            ],
            'Cấu hình phân bố dạng câu hỏi ($distTotal) không khớp với số lượng câu (${cell.questionCount}) ở mục tiêu [${cell.objectiveId}] mức [${cell.difficulty.label}].',
          );
        }
      }
    }

    // Build structured demand groups
    final List<_DemandGroup> demandGroups = [];
    for (final cell in activeCells) {
      final normalizedScore = ScorePrecisionHandler.fromHundredths(
        ScorePrecisionHandler.toHundredths(cell.scorePerQuestion),
      );

      if (cell.questionTypeDistribution.isNotEmpty) {
        for (final entry in cell.questionTypeDistribution.entries) {
          if (entry.value > 0) {
            demandGroups.add(_DemandGroup(
              objectiveId: cell.objectiveId,
              difficulty: cell.difficulty,
              questionType: entry.key,
              requiredCount: entry.value,
              score: normalizedScore,
            ));
          }
        }
      } else {
        demandGroups.add(_DemandGroup(
          objectiveId: cell.objectiveId,
          difficulty: cell.difficulty,
          questionType: null,
          requiredCount: cell.questionCount,
          score: normalizedScore,
        ));
      }
    }

    // Filter valid question bank candidates
    final validBank = questionBank.where(isValidCandidate).toList();

    // Check direct shortages per demand group
    final Map<String, Set<int>> candidatesPerGroup = {};
    final List<ExamSelectionShortage> directShortages = [];

    for (final group in demandGroups) {
      final eligible = <int>{};
      for (int bIdx = 0; bIdx < validBank.length; bIdx++) {
        final q = validBank[bIdx];
        if (q.difficulty != group.difficulty) continue;
        if (group.objectiveId.isNotEmpty && group.objectiveId != 'ALL') {
          if (q.learningObjective != group.objectiveId) continue;
        }
        if (group.questionType != null && q.type != group.questionType) continue;
        eligible.add(bIdx);
      }
      candidatesPerGroup[group.key] = eligible;

      if (eligible.length < group.requiredCount) {
        directShortages.add(ExamSelectionShortage(
          objectiveId: group.objectiveId.isNotEmpty ? group.objectiveId : 'Chung',
          difficulty: group.difficulty,
          questionType: group.questionType,
          requiredCount: group.requiredCount,
          availableCount: eligible.length,
        ));
      }
    }

    if (directShortages.isNotEmpty) {
      return ExamSelectionResult.failure(directShortages);
    }

    // Expand demand slots from groups
    final List<_SelectionSlot> slots = [];
    for (final group in demandGroups) {
      for (int i = 0; i < group.requiredCount; i++) {
        slots.add(_SelectionSlot(
          index: slots.length,
          objectiveId: group.objectiveId,
          difficulty: group.difficulty,
          questionType: group.questionType,
          score: group.score,
          groupKey: group.key,
        ));
      }
    }

    // Map each slot to eligible bank question indices
    final List<List<int>> candidateIndicesPerSlot = List.generate(slots.length, (sIdx) {
      final slot = slots[sIdx];
      final eligible = candidatesPerGroup[slot.groupKey]?.toList() ?? [];

      // Shuffle candidate indices deterministically based on randomSeed and slot
      final seed = randomSeed != null ? randomSeed + (sIdx * 317) : null;
      final rng = seed != null ? Random(seed) : Random();
      final shuffled = List<int>.from(eligible)..shuffle(rng);

      return shuffled;
    });

    // Maximum Bipartite Matching (Augmenting Paths) to find valid injective assignment
    final Map<int, int> matchSlotToBank = {};
    final Map<int, int> matchBankToSlot = {};

    bool findAugmentingPath(int slotIdx, Set<int> visitedSlots) {
      if (visitedSlots.contains(slotIdx)) return false;
      visitedSlots.add(slotIdx);

      for (final bankIdx in candidateIndicesPerSlot[slotIdx]) {
        final currentOwner = matchBankToSlot[bankIdx];
        if (currentOwner == null || findAugmentingPath(currentOwner, visitedSlots)) {
          matchSlotToBank[slotIdx] = bankIdx;
          matchBankToSlot[bankIdx] = slotIdx;
          return true;
        }
      }
      return false;
    }

    // Minimum Remaining Values (MRV): Sort slot matching order by candidate count ascending
    final sortedSlotIndices = List<int>.generate(slots.length, (i) => i);
    sortedSlotIndices.sort((a, b) => candidateIndicesPerSlot[a].length.compareTo(candidateIndicesPerSlot[b].length));

    final List<int> unmatchedSlotIndices = [];
    for (final sIdx in sortedSlotIndices) {
      final visited = <int>{};
      if (!findAugmentingPath(sIdx, visited)) {
        unmatchedSlotIndices.add(sIdx);
      }
    }

    if (unmatchedSlotIndices.isNotEmpty) {
      // Build detailed shortage report based on unmatched demand groups
      final Set<String> failedGroupKeys = unmatchedSlotIndices.map((idx) => slots[idx].groupKey).toSet();
      final List<ExamSelectionShortage> shortages = [];

      for (final group in demandGroups) {
        if (failedGroupKeys.contains(group.key)) {
          shortages.add(ExamSelectionShortage(
            objectiveId: group.objectiveId.isNotEmpty ? group.objectiveId : 'Chung',
            difficulty: group.difficulty,
            questionType: group.questionType,
            requiredCount: group.requiredCount,
            availableCount: candidatesPerGroup[group.key]?.length ?? 0,
          ));
        }
      }
      return ExamSelectionResult.failure(shortages);
    }

    // Materialize snapshots for all matched slots
    final List<ExamQuestionSnapshot> selectedSnapshots = [];
    for (int sIdx = 0; sIdx < slots.length; sIdx++) {
      final slot = slots[sIdx];
      final bankIdx = matchSlotToBank[sIdx]!;
      final item = validBank[bankIdx];

      int sectionIndex = 0;
      if (item.type == QuestionType.trueFalse || item.type == QuestionType.shortAnswer) {
        sectionIndex = 1;
      } else if (item.type == QuestionType.essay) {
        sectionIndex = 2;
      }

      selectedSnapshots.add(
        ExamQuestionSnapshot.fromQuestionItem(
          item,
          score: slot.score,
          sectionIndex: sectionIndex,
        ),
      );
    }

    // Sort snapshots logically: Section 0 (MCQ) -> Section 1 (TF/Short) -> Section 2 (Essay)
    selectedSnapshots.sort((a, b) {
      if (a.sectionIndex != b.sectionIndex) {
        return a.sectionIndex.compareTo(b.sectionIndex);
      }
      return 0;
    });

    return ExamSelectionResult.success(selectedSnapshots);
  }
}
