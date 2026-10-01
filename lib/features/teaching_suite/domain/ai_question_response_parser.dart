import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'models/question_models.dart';

/// Error code constants for Question Validation
class QuestionValidationErrorCodes {
  static const String emptyResponse = 'EMPTY_RESPONSE';
  static const String malformedJson = 'MALFORMED_JSON';
  static const String missingPrompt = 'MISSING_PROMPT';
  static const String invalidType = 'INVALID_TYPE';
  static const String invalidDifficulty = 'INVALID_DIFFICULTY';
  static const String mcqRequires4Choices = 'MCQ_REQUIRES_4_CHOICES';
  static const String duplicateChoice = 'DUPLICATE_CHOICE';
  static const String invalidCorrectAnswer = 'INVALID_CORRECT_ANSWER';
  static const String missingCorrectAnswer = 'MISSING_CORRECT_ANSWER';
  static const String emptyChoice = 'EMPTY_CHOICE';
}

/// Backward compatibility alias
typedef AiQuestionErrorCodes = QuestionValidationErrorCodes;

/// Validation result with detailed error codes and warnings.
class QuestionValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const QuestionValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  static const valid = QuestionValidationResult(isValid: true);

  factory QuestionValidationResult.failure(List<String> errors, [List<String> warnings = const []]) {
    return QuestionValidationResult(
      isValid: false,
      errors: errors,
      warnings: warnings,
    );
  }

  @override
  String toString() => 'QuestionValidationResult(isValid: $isValid, errors: $errors, warnings: $warnings)';
}

/// Strict parser and validator for AI generated questions.
/// Separates strict validation for AI responses from lenient DB deserialization.
class AiQuestionResponseParser {
  static const _uuid = Uuid();

  /// Validates a raw item map strictly.
  static QuestionValidationResult validateRawItem(Map<String, dynamic> raw) {
    final List<String> errors = [];
    final List<String> warnings = [];

    // 1. Prompt check
    final prompt = raw['prompt'] ?? raw['stem'] ?? raw['question'];
    if (prompt == null || prompt.toString().trim().isEmpty) {
      errors.add(QuestionValidationErrorCodes.missingPrompt);
    }

    // 2. Type check - STRICT: no silent fallback
    final rawType = raw['type']?.toString();
    QuestionType? parsedType;
    if (rawType == null || rawType.trim().isEmpty) {
      errors.add(QuestionValidationErrorCodes.invalidType);
    } else {
      for (final t in QuestionType.values) {
        if (t.name == rawType || t.label == rawType) {
          parsedType = t;
          break;
        }
      }
      if (parsedType == null) {
        errors.add(QuestionValidationErrorCodes.invalidType);
      }
    }

    // 3. Difficulty check - STRICT: no silent fallback to nhanBiet
    final rawDiff = raw['difficulty']?.toString();
    QuestionDifficulty? parsedDiff;
    if (rawDiff == null || rawDiff.trim().isEmpty) {
      errors.add(QuestionValidationErrorCodes.invalidDifficulty);
    } else {
      for (final d in QuestionDifficulty.values) {
        if (d.name == rawDiff || d.label == rawDiff) {
          parsedDiff = d;
          break;
        }
      }
      if (parsedDiff == null) {
        errors.add(QuestionValidationErrorCodes.invalidDifficulty);
      }
    }

    // 4. Correct answer check
    final rawCorrect = (raw['correct_answer'] ?? raw['correctAnswer'] ?? raw['answer'])?.toString().trim();
    if (rawCorrect == null || rawCorrect.isEmpty) {
      errors.add(QuestionValidationErrorCodes.missingCorrectAnswer);
    }

    // 5. Choices check for MCQ
    final effectiveType = parsedType ?? QuestionType.multipleChoice;
    if (effectiveType == QuestionType.multipleChoice) {
      final rawChoices = raw['choices'] ?? raw['options'];
      if (rawChoices is! List) {
        errors.add(QuestionValidationErrorCodes.mcqRequires4Choices);
      } else {
        if (rawChoices.length != 4) {
          errors.add(QuestionValidationErrorCodes.mcqRequires4Choices);
        }

        final choiceStrings = <String>[];
        for (final c in rawChoices) {
          final s = c?.toString().trim() ?? '';
          if (s.isEmpty) {
            errors.add(QuestionValidationErrorCodes.emptyChoice);
          }
          choiceStrings.add(s);
        }

        // Distinct check after trim, prefix stripping & lowercase
        String normalizeChoice(String s) {
          final stripped = s.trim().replaceFirst(RegExp(r'^[A-Da-d][\.\:\)]\s*'), '').trim().toLowerCase();
          return stripped.isNotEmpty ? stripped : s.trim().toLowerCase();
        }

        final normalizedSet = choiceStrings.map(normalizeChoice).toSet();
        if (normalizedSet.length != choiceStrings.length && !errors.contains(QuestionValidationErrorCodes.duplicateChoice)) {
          errors.add(QuestionValidationErrorCodes.duplicateChoice);
        }

        // Check if correctAnswer is valid A/B/C/D or matches choice text exactly
        if (rawCorrect != null && rawCorrect.isNotEmpty) {
          final upper = rawCorrect.toUpperCase();
          final isLetter = upper == 'A' || upper == 'B' || upper == 'C' || upper == 'D';
          final matchesChoiceText = choiceStrings.any((c) => c.toLowerCase() == rawCorrect.toLowerCase());
          if (!isLetter && !matchesChoiceText) {
            errors.add(QuestionValidationErrorCodes.invalidCorrectAnswer);
          }
        }
      }
    }

    return errors.isEmpty
        ? QuestionValidationResult(isValid: true, warnings: warnings)
        : QuestionValidationResult.failure(errors, warnings);
  }

  /// Parses and strictly validates AI question response.
  /// Throws FormatException with detailed errors if validation fails (fail-closed).
  static List<QuestionItem> parseAndValidate(
    String rawResponse, {
    String? projectId,
    String? setId,
  }) =>
      parse(rawResponse, projectId: projectId, setId: setId);

  /// Parses and strictly validates AI question response.
  /// Throws FormatException with detailed errors if validation fails (fail-closed).
  static List<QuestionItem> parse(
    String rawResponse, {
    String? projectId,
    String? setId,
  }) {
    if (rawResponse.trim().isEmpty) {
      throw const FormatException('Phản hồi từ AI rỗng (${QuestionValidationErrorCodes.emptyResponse})');
    }

    // Extract JSON payload (strip markdown fences, preambles, and postambles)
    String cleanJson = rawResponse.trim();
    if (cleanJson.contains('```json')) {
      final start = cleanJson.indexOf('```json') + 7;
      final end = cleanJson.indexOf('```', start);
      if (end != -1) {
        cleanJson = cleanJson.substring(start, end).trim();
      } else {
        cleanJson = cleanJson.substring(start).trim();
      }
    } else if (cleanJson.contains('```')) {
      final start = cleanJson.indexOf('```') + 3;
      final end = cleanJson.indexOf('```', start);
      if (end != -1) {
        cleanJson = cleanJson.substring(start, end).trim();
      } else {
        cleanJson = cleanJson.substring(start).trim();
      }
    }

    // If there is still extra text around JSON array
    final arrayStart = cleanJson.indexOf('[');
    final arrayEnd = cleanJson.lastIndexOf(']');
    if (arrayStart != -1 && arrayEnd != -1 && arrayEnd > arrayStart) {
      cleanJson = cleanJson.substring(arrayStart, arrayEnd + 1).trim();
    } else {
      // Check for object with questions field
      final objStart = cleanJson.indexOf('{');
      final objEnd = cleanJson.lastIndexOf('}');
      if (objStart != -1 && objEnd != -1 && objEnd > objStart) {
        cleanJson = cleanJson.substring(objStart, objEnd + 1).trim();
      }
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(cleanJson);
    } catch (e) {
      throw FormatException('JSON không hợp lệ: $e (${QuestionValidationErrorCodes.malformedJson})');
    }

    List<dynamic> itemsList;
    if (decoded is List) {
      itemsList = decoded;
    } else if (decoded is Map && decoded['questions'] is List) {
      itemsList = decoded['questions'] as List;
    } else {
      throw const FormatException('Cấu trúc JSON phản hồi không chứa danh sách câu hỏi (${QuestionValidationErrorCodes.malformedJson})');
    }

    if (itemsList.isEmpty) {
      throw const FormatException('Danh sách câu hỏi từ AI rỗng (${QuestionValidationErrorCodes.emptyResponse})');
    }

    final List<QuestionItem> result = [];
    final List<String> allValidationErrors = [];

    for (int i = 0; i < itemsList.length; i++) {
      final item = itemsList[i];
      if (item is! Map<String, dynamic>) {
        allValidationErrors.add('Câu hỏi #$i: không phải là một đối tượng JSON hợp lệ');
        continue;
      }

      final validation = validateRawItem(item);
      if (!validation.isValid) {
        allValidationErrors.add('Câu hỏi #${i + 1}: ${validation.errors.join(", ")}');
      } else {
        // Build valid QuestionItem
        final rawType = item['type']?.toString();
        final type = QuestionType.values.firstWhere((t) => t.name == rawType || t.label == rawType);

        final rawDiff = item['difficulty']?.toString();
        final diff = QuestionDifficulty.values.firstWhere((d) => d.name == rawDiff || d.label == rawDiff);

        final prompt = (item['prompt'] ?? item['stem'] ?? item['question']).toString().trim();
        final explanation = (item['explanation'] ?? item['explain'])?.toString().trim();
        final objective = (item['learningObjective'] ?? item['objective'])?.toString().trim();

        List<String> choices = [];
        String correctAnswer = (item['correct_answer'] ?? item['correctAnswer'] ?? item['answer']).toString().trim();

        if (type == QuestionType.multipleChoice) {
          final rawChoices = (item['choices'] ?? item['options']) as Iterable?;
          choices = (rawChoices ?? []).map<String>((c) => c.toString().trim()).toList();

          // Normalize answer to letter if matching text
          final upper = correctAnswer.toUpperCase();
          if (upper != 'A' && upper != 'B' && upper != 'C' && upper != 'D') {
            for (int ci = 0; ci < choices.length; ci++) {
              if (choices[ci].toLowerCase() == correctAnswer.toLowerCase()) {
                correctAnswer = String.fromCharCode(65 + ci);
                break;
              }
            }
          }
        } else if (type == QuestionType.trueFalse) {
          choices = const ['A. Đúng', 'B. Sai'];
          final upper = correctAnswer.toUpperCase();
          if (upper == 'TRUE' || upper == 'ĐÚNG' || upper == '1') {
            correctAnswer = 'A';
          } else if (upper == 'FALSE' || upper == 'SAI' || upper == '0') {
            correctAnswer = 'B';
          }
        }

        result.add(QuestionItem(
          id: 'q_${_uuid.v4()}',
          setId: setId,
          type: type,
          prompt: prompt,
          choices: choices,
          correctAnswer: correctAnswer,
          explanation: explanation,
          difficulty: diff,
          learningObjective: objective,
          orderIndex: i,
        ));
      }
    }

    // FAIL-CLOSED: If any item in the batch failed validation, reject the entire response
    if (allValidationErrors.isNotEmpty) {
      throw FormatException(
        'Phản hồi AI bị từ chối do dữ liệu không hợp lệ:\n${allValidationErrors.join("\n")}',
      );
    }

    return result;
  }
}
