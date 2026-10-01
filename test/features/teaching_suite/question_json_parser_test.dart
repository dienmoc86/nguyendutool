import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/question_models.dart';
import 'package:nguyendu_tool/features/teaching_suite/infrastructure/gemini_ai_text_generation_service.dart';

void main() {
  group('Teaching Suite - Question JSON Parser & Validation Tests', () {
    test('Correctly extracts and parses valid MCQ question JSON array', () {
      const rawAiResponse = '''
```json
[
  {
    "id": "q_101",
    "type": "multipleChoice",
    "prompt": "Từ ngữ nào thể hiện sự trân trọng tuyệt đối vẻ đẹp của Thúy Kiều?",
    "choices": [
      "A. Sắc sảo mặn mà",
      "B. Đoan trang dịu dàng",
      "C. Hoa ghen thua thắm liễu hờn kém xanh",
      "D. Nghiêng nước nghiêng thành"
    ],
    "correctAnswer": "D",
    "explanation": "Thành ngữ 'nghiêng nước nghiêng thành' thể hiện vẻ đẹp vượt bậc làm khuynh đảo tạo hóa.",
    "difficulty": "thongHieu",
    "learningObjective": "M1.2",
    "tags": ["truyen_kieu", "van_hoc_9"]
  }
]
```
''';

      final jsonStr = GeminiAiTextGenerationService.extractJson(rawAiResponse);
      final decoded = jsonDecode(jsonStr) as List;
      expect(decoded.length, equals(1));

      final q = QuestionItem.fromMap(decoded.first as Map<String, dynamic>);
      expect(q.id, equals('q_101'));
      expect(q.type, equals(QuestionType.multipleChoice));
      expect(q.choices.length, equals(4));
      expect(q.correctAnswer, equals('D'));
      expect(q.difficulty, equals(QuestionDifficulty.thongHieu));
      expect(q.isValidMcq, isTrue);
    });

    test('Validates MCQ integrity: detects missing answer or choice out of bounds', () {
      const invalidQ = QuestionItem(
        id: 'q_invalid_1',
        type: QuestionType.multipleChoice,
        prompt: 'Câu hỏi có đáp án ngoài lựa chọn',
        choices: ['A. Lựa chọn 1', 'B. Lựa chọn 2'],
        correctAnswer: 'E', // E is invalid for 2 choices
      );

      expect(invalidQ.isValidMcq, isFalse);
    });

    test('Validates MCQ integrity: detects choice list with fewer than 4 choices', () {
      const singleChoiceQ = QuestionItem(
        id: 'q_invalid_2',
        type: QuestionType.multipleChoice,
        prompt: 'Câu hỏi chỉ có 2 lựa chọn',
        choices: ['A. Duy nhất 1', 'B. Duy nhất 2'],
        correctAnswer: 'A',
      );

      expect(singleChoiceQ.isValidMcq, isFalse);
    });

    test('Handles malformed JSON safely without unhandled crashes', () {
      const brokenJson = 'Đây là văn bản không phải JSON hoặc bị cắt đứt giữa chừng [ {"id": "1", "prompt": ';
      final jsonStr = GeminiAiTextGenerationService.extractJson(brokenJson);
      expect(() => jsonDecode(jsonStr), throwsFormatException);
    });

    test('Correctly falls back in lenient DB deserializer when strings are unrecognized', () {
      final map = {
        'id': 'q_fallback',
        'type': 'non_existent_type',
        'prompt': 'Câu hỏi thử nghiệm',
        'choices': ['A. 1', 'B. 2', 'C. 3', 'D. 4'],
        'correctAnswer': 'A',
        'difficulty': 'unrecognized_difficulty',
      };

      final q = QuestionItem.fromMap(map);
      expect(q.type, equals(QuestionType.multipleChoice));
      expect(q.difficulty, equals(QuestionDifficulty.nhanBiet));
      expect(q.isValidMcq, isTrue);
    });
  });
}
