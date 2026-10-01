import '../../../teaching_suite/domain/models/question_models.dart';
import '../models/exam_answer_key.dart';
import '../models/exam_code.dart';
import '../models/exam_paper.dart';
import '../models/question_choice.dart';

/// Verification result for multi-code equivalence (Sections 38, 39, Findings 10 & 11).
class ExamCodeVerificationResult {
  final bool isEquivalent;
  final List<String> mismatches;

  const ExamCodeVerificationResult({
    required this.isEquivalent,
    this.mismatches = const [],
  });

  bool get hasMismatches => mismatches.isNotEmpty;
}

/// Verification result for answer key consistency (Section 11).
class ExamAnswerKeyVerificationResult {
  final bool isValid;
  final List<String> errors;

  const ExamAnswerKeyVerificationResult({
    required this.isValid,
    this.errors = const [],
  });

  bool get hasErrors => errors.isNotEmpty;
}

/// Verifies equivalence, canonical master alignment, and answer integrity across exam codes (Sections 10, 11).
class ExamCodeVerifier {
  const ExamCodeVerifier();

  ExamCodeVerificationResult verifyCodes(
    List<ExamCode> codes, {
    ExamPaper? canonicalMaster,
  }) {
    final List<String> mismatches = [];

    if (codes.isEmpty) {
      return const ExamCodeVerificationResult(
        isEquivalent: false,
        mismatches: ['NO_CODES: Danh sách mã đề kiểm tra trống.'],
      );
    }

    // 1. Code ID & Student Code Uniqueness
    final codeIds = codes.map((c) => c.id).toSet();
    if (codeIds.length != codes.length) {
      mismatches.add('DUPLICATE_CODE_ID: Tồn tại trùng lặp ID mã đề giữa các bản ghi ExamCode.');
    }

    final studentCodes = codes.map((c) => c.code).toSet();
    if (studentCodes.length != codes.length) {
      mismatches.add('DUPLICATE_STUDENT_CODE: Tồn tại trùng lặp mã đề học sinh (code).');
    }

    // Canonical baseline: use canonicalMaster if supplied, else first code
    final baselineQuestionCount = canonicalMaster != null
        ? canonicalMaster.questions.length
        : codes.first.questionCount;
    final baselineScore = canonicalMaster != null
        ? canonicalMaster.totalScore
        : codes.first.totalScore;
    final baselineQuestionIds = canonicalMaster != null
        ? canonicalMaster.questions.map((q) => q.questionId).toSet()
        : codes.first.questions.map((q) => q.questionId).toSet();

    final masterMap = canonicalMaster != null
        ? {for (final q in canonicalMaster.questions) q.questionId: q}
        : null;

    for (final code in codes) {
      // 2. Master relationship check
      if (canonicalMaster != null && code.examPaperId != canonicalMaster.id) {
        mismatches.add(
          'MASTER_MISMATCH: Mã đề ${code.code} trỏ đến examPaperId=${code.examPaperId} '
          'không khớp với đề gốc canonical=${canonicalMaster.id}.',
        );
      }

      // 3. Question count equivalence
      if (code.questionCount != baselineQuestionCount) {
        mismatches.add(
          'QUESTION_COUNT_MISMATCH: Mã ${code.code} có ${code.questionCount} câu '
          '(khác số câu chuẩn $baselineQuestionCount).',
        );
      }

      // 4. Total score equivalence (0.001 tolerance)
      if ((code.totalScore - baselineScore).abs() > 0.001) {
        mismatches.add(
          'TOTAL_SCORE_MISMATCH: Mã ${code.code} có tổng điểm ${code.totalScore.toStringAsFixed(2)} '
          '(khác tổng điểm chuẩn ${baselineScore.toStringAsFixed(2)} đ).',
        );
      }

      // 5. Duplicate questions within code
      final qIds = code.questions.map((q) => q.questionId).toList();
      if (qIds.toSet().length != qIds.length) {
        mismatches.add('DUPLICATE_QUESTION_IN_CODE: Mã ${code.code} chứa câu hỏi trùng lặp ID.');
      }

      // 6. Multiset of question IDs
      final currentQuestionIds = qIds.toSet();
      final missingFromCode = baselineQuestionIds.difference(currentQuestionIds);
      if (missingFromCode.isNotEmpty) {
        mismatches.add(
          'QUESTION_CONTENT_MISMATCH: Mã ${code.code} thiếu các câu hỏi: ${missingFromCode.join(", ")}.',
        );
      }
      final extraInCode = currentQuestionIds.difference(baselineQuestionIds);
      if (extraInCode.isNotEmpty) {
        mismatches.add(
          'EXTRA_QUESTION_IN_CODE: Mã ${code.code} chứa câu hỏi thừa: ${extraInCode.join(", ")}.',
        );
      }

      // 7. Individual question snapshot comparison against canonical master
      for (final q in code.questions) {
        if (masterMap != null) {
          final masterSnap = masterMap[q.questionId];
          if (masterSnap == null) {
            mismatches.add('UNKNOWN_QUESTION_IN_CODE: Câu ${q.questionId} trong mã ${code.code} không có trong đề gốc.');
            continue;
          }

          if ((q.score - masterSnap.score).abs() > 0.001) {
            mismatches.add(
              'QUESTION_SCORE_MISMATCH: Câu ${q.questionId} trong mã ${code.code} có điểm ${q.score} '
              'khác điểm đề gốc ${masterSnap.score}.',
            );
          }

          if ((q.snapshot.score - masterSnap.score).abs() > 0.001) {
            mismatches.add(
              'QUESTION_SNAPSHOT_SCORE_MISMATCH: Câu ${q.questionId} trong mã ${code.code} có snapshot.score ${q.snapshot.score} '
              'khác điểm đề gốc ${masterSnap.score}.',
            );
          }

          if (q.snapshot.prompt != masterSnap.prompt) {
            mismatches.add(
              'QUESTION_PROMPT_MUTATED: Câu ${q.questionId} trong mã ${code.code} có prompt khác với đề gốc.',
            );
          }

          if (q.snapshot.type != masterSnap.type) {
            mismatches.add(
              'QUESTION_TYPE_MUTATED: Câu ${q.questionId} trong mã ${code.code} có type (${q.snapshot.type}) khác với đề gốc (${masterSnap.type}).',
            );
          }

          if (q.snapshot.difficulty != masterSnap.difficulty) {
            mismatches.add(
              'QUESTION_DIFFICULTY_MUTATED: Câu ${q.questionId} trong mã ${code.code} có difficulty khác với đề gốc.',
            );
          }

          if (q.snapshot.objectiveId != masterSnap.objectiveId) {
            mismatches.add(
              'QUESTION_OBJECTIVE_MUTATED: Câu ${q.questionId} trong mã ${code.code} có objectiveId khác với đề gốc.',
            );
          }

          if (q.snapshot.correctChoiceId != masterSnap.correctChoiceId) {
            mismatches.add(
              'CORRECT_CHOICE_MUTATED: Câu ${q.questionId} trong mã ${code.code} có correctChoiceId '
              'khác với đề gốc (${q.snapshot.correctChoiceId} != ${masterSnap.correctChoiceId}).',
            );
          }

          if (q.snapshot.correctAnswerText != masterSnap.correctAnswerText) {
            mismatches.add(
              'CORRECT_ANSWER_TEXT_MUTATED: Câu ${q.questionId} trong mã ${code.code} có correctAnswerText khác với đề gốc.',
            );
          }

          if (q.snapshot.explanation != masterSnap.explanation) {
            mismatches.add(
              'QUESTION_EXPLANATION_MUTATED: Câu ${q.questionId} trong mã ${code.code} có explanation khác với đề gốc.',
            );
          }

          // Choice content comparison
          if (q.snapshot.choices.length != masterSnap.choices.length) {
            mismatches.add(
              'CHOICE_COUNT_MUTATED: Câu ${q.questionId} trong mã ${code.code} có ${q.snapshot.choices.length} lựa chọn khác đề gốc (${masterSnap.choices.length}).',
            );
          } else {
            for (final mChoice in masterSnap.choices) {
              final snapChoice = q.snapshot.choices.where((c) => c.id == mChoice.id).firstOrNull;
              if (snapChoice == null) {
                mismatches.add(
                  'CHOICE_ID_MISSING: Phương án ${mChoice.id} trong câu ${q.questionId} mã ${code.code} không tìm thấy trong snapshot.',
                );
              } else if (snapChoice.text != mChoice.text) {
                mismatches.add(
                  'CHOICE_TEXT_MUTATED: Phương án ${mChoice.id} trong câu ${q.questionId} mã ${code.code} có nội dung khác đề gốc.',
                );
              }
            }
          }
        }

        // Choice permutation and displayed letter validation for MCQ
        if (q.snapshot.type == QuestionType.multipleChoice && q.snapshot.choices.isNotEmpty) {
          final letter = q.correctDisplayAnswer.trim().toUpperCase();
          if (letter.isEmpty || !['A', 'B', 'C', 'D'].contains(letter)) {
            mismatches.add(
              'INVALID_ANSWER_LETTER: Mã ${code.code} - Câu ${q.orderIndex + 1} '
              'chứa chữ cái đáp án hiển thị không hợp lệ "$letter" (chỉ chấp nhận A, B, C, D).',
            );
            continue;
          }

          final choiceIndex = QuestionChoice.letterToIndex(letter);
          final orderedChoices = q.orderedChoices;

          if (choiceIndex < 0 || choiceIndex >= orderedChoices.length) {
            mismatches.add(
              'INVALID_CORRECT_ANSWER_INDEX: Mã ${code.code} - Câu ${q.orderIndex + 1} '
              'đáp án "$letter" (chỉ số $choiceIndex) vượt quá số lựa chọn (${orderedChoices.length}).',
            );
          } else {
            final activeChoice = orderedChoices[choiceIndex];
            final expectedId = masterMap != null
                ? masterMap[q.questionId]?.correctChoiceId ?? q.snapshot.correctChoiceId
                : q.snapshot.correctChoiceId;

            if (activeChoice.id != expectedId) {
              mismatches.add(
                'SEMANTIC_ANSWER_REMAP_FAILURE: Mã ${code.code} - Câu ${q.orderIndex + 1} '
                'chữ cái "$letter" ứng với phương án "${activeChoice.id}" nhưng đáp án đúng gốc là "$expectedId".',
              );
            }
          }

          // Check that choiceOrder is a valid permutation of master choices (Section 6)
          if (masterMap != null) {
            final masterSnap = masterMap[q.questionId]!;
            final masterChoiceIds = masterSnap.choices.map((c) => c.id).toList();

            // Length check
            if (q.choiceOrder.length != masterChoiceIds.length) {
              mismatches.add(
                'CHOICE_PERMUTATION_CORRUPTED: Các phương án của câu ${q.questionId} trong mã ${code.code} '
                'có độ dài ${q.choiceOrder.length} khác đề gốc (${masterChoiceIds.length}).',
              );
            }

            // Duplicates check (reject e.g. A,A,B,C,D)
            if (q.choiceOrder.toSet().length != q.choiceOrder.length) {
              mismatches.add(
                'CHOICE_PERMUTATION_CORRUPTED: Các phương án của câu ${q.questionId} trong mã ${code.code} '
                'chứa ID trùng lặp (${q.choiceOrder.join(", ")}).',
              );
            }

            // Blank IDs check
            if (q.choiceOrder.any((id) => id.trim().isEmpty)) {
              mismatches.add(
                'CHOICE_PERMUTATION_CORRUPTED: Câu ${q.questionId} trong mã ${code.code} chứa ID phương án rỗng.',
              );
            }

            // Unknown IDs check (reject e.g. A,B,C,X)
            final masterIdSet = masterChoiceIds.toSet();
            final unknownIds = q.choiceOrder.where((id) => !masterIdSet.contains(id)).toList();
            if (unknownIds.isNotEmpty) {
              mismatches.add(
                'CHOICE_PERMUTATION_CORRUPTED: Câu ${q.questionId} trong mã ${code.code} chứa ID lạ: ${unknownIds.join(", ")}.',
              );
            }

            // Missing IDs check
            final currentIdSet = q.choiceOrder.toSet();
            final missingIds = masterChoiceIds.where((id) => !currentIdSet.contains(id)).toList();
            if (missingIds.isNotEmpty) {
              mismatches.add(
                'CHOICE_PERMUTATION_CORRUPTED: Câu ${q.questionId} trong mã ${code.code} thiếu ID phương án: ${missingIds.join(", ")}.',
              );
            }
          }
        }
      }
    }

    return ExamCodeVerificationResult(
      isEquivalent: mismatches.isEmpty,
      mismatches: mismatches,
    );
  }

  /// Verifies answer key consistency against actual ExamCodeQuestions and Canonical Master (Section 11).
  ExamAnswerKeyVerificationResult verifyAnswerKeys({
    required List<ExamCode> codes,
    required Map<String, ExamAnswerKey> answerKeys,
    ExamPaper? canonicalMaster,
  }) {
    final List<String> errors = [];

    for (final code in codes) {
      final key = answerKeys[code.code];
      if (key == null || key.items.isEmpty) {
        errors.add('MISSING_ANSWER_KEY: Mã đề ${code.code} không có bảng đáp án.');
        continue;
      }

      if (key.items.length != code.questions.length) {
        errors.add(
          'ANSWER_KEY_COUNT_MISMATCH: Bảng đáp án mã ${code.code} có ${key.items.length} câu, '
          'nhưng đề thi có ${code.questions.length} câu.',
        );
      }

      for (int i = 0; i < code.questions.length; i++) {
        final q = code.questions[i];
        final expectedQNum = i + 1;
        final keyItem = key.items.firstWhere(
          (it) => it.questionNumber == expectedQNum,
          orElse: () => const ExamAnswerKeyItem(
            questionNumber: -1,
            correctDisplayAnswer: '',
            score: 0,
            questionId: '',
            promptSnippet: '',
          ),
        );

        if (keyItem.questionNumber == -1) {
          errors.add('MISSING_KEY_ITEM: Bảng đáp án mã ${code.code} thiếu câu số $expectedQNum.');
          continue;
        }

        if (keyItem.questionId != q.questionId) {
          errors.add(
            'KEY_QUESTION_ID_MISMATCH: Mã ${code.code} câu $expectedQNum có questionId=${keyItem.questionId} '
            'khác đề thi=${q.questionId}.',
          );
        }

        if (keyItem.correctDisplayAnswer != q.correctDisplayAnswer) {
          errors.add(
            'KEY_ANSWER_MISMATCH: Mã ${code.code} câu $expectedQNum đáp án trên bảng key (${keyItem.correctDisplayAnswer}) '
            'không khớp với đề thi (${q.correctDisplayAnswer}).',
          );
        }

        if ((keyItem.score - q.score).abs() > 0.001) {
          errors.add(
            'KEY_SCORE_MISMATCH: Mã ${code.code} câu $expectedQNum điểm bảng key (${keyItem.score}) '
            'không khớp điểm câu hỏi (${q.score}).',
          );
        }
      }
    }

    return ExamAnswerKeyVerificationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
}
