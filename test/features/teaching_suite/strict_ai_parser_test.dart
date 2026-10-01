import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/ai_question_response_parser.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/question_models.dart';

void main() {
  group('Strict AI Question Response Parser Matrix', () {
    test('1. Valid MCQ parses successfully and passes all validations', () {
      const raw = '''
```json
[
  {
    "type": "multipleChoice",
    "prompt": "Văn bản nào thuộc thể loại Truyện thơ Nôm?",
    "choices": [
      "A. Truyện Kiều",
      "B. Hoàng Lê nhất thống chí",
      "C. Nam quốc sơn hà",
      "D. Hịch tướng sĩ"
    ],
    "correctAnswer": "A",
    "difficulty": "nhanBiet"
  }
]
```
''';
      final questions = AiQuestionResponseParser.parseAndValidate(raw);
      expect(questions.length, equals(1));
      expect(questions.first.type, equals(QuestionType.multipleChoice));
      expect(questions.first.correctAnswer, equals('A'));
      expect(questions.first.choices.length, equals(4));
      expect(questions.first.difficulty, equals(QuestionDifficulty.nhanBiet));
    });

    test('2. 3 choices fails with MCQ_REQUIRES_4_CHOICES', () {
      const raw = '''
[
  {
    "type": "multipleChoice",
    "prompt": "Câu hỏi thiếu lựa chọn",
    "choices": ["A. Lựa chọn 1", "B. Lựa chọn 2", "C. Lựa chọn 3"],
    "correctAnswer": "A",
    "difficulty": "nhanBiet"
  }
]
''';
      expect(
        () => AiQuestionResponseParser.parseAndValidate(raw),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains(AiQuestionErrorCodes.mcqRequires4Choices),
        )),
      );
    });

    test('3. 5 choices fails with MCQ_REQUIRES_4_CHOICES', () {
      const raw = '''
[
  {
    "type": "multipleChoice",
    "prompt": "Câu hỏi thừa lựa chọn",
    "choices": ["A. 1", "B. 2", "C. 3", "D. 4", "E. 5"],
    "correctAnswer": "A",
    "difficulty": "nhanBiet"
  }
]
''';
      expect(
        () => AiQuestionResponseParser.parseAndValidate(raw),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains(AiQuestionErrorCodes.mcqRequires4Choices),
        )),
      );
    });

    test('4. Duplicate choice fails with DUPLICATE_CHOICE', () {
      const raw = '''
[
  {
    "type": "multipleChoice",
    "prompt": "Câu hỏi trùng lặp lựa chọn",
    "choices": ["A. Phương án 1", "B. Phương án 1", "C. Phương án 3", "D. Phương án 4"],
    "correctAnswer": "A",
    "difficulty": "nhanBiet"
  }
]
''';
      expect(
        () => AiQuestionResponseParser.parseAndValidate(raw),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains(AiQuestionErrorCodes.duplicateChoice),
        )),
      );
    });

    test('5. Missing correct answer fails with MISSING_CORRECT_ANSWER', () {
      const raw = '''
[
  {
    "type": "multipleChoice",
    "prompt": "Câu hỏi không có đáp án",
    "choices": ["A. 1", "B. 2", "C. 3", "D. 4"],
    "correctAnswer": "",
    "difficulty": "nhanBiet"
  }
]
''';
      expect(
        () => AiQuestionResponseParser.parseAndValidate(raw),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains(AiQuestionErrorCodes.missingCorrectAnswer),
        )),
      );
    });

    test('6. Answer E fails with INVALID_CORRECT_ANSWER', () {
      const raw = '''
[
  {
    "type": "multipleChoice",
    "prompt": "Câu hỏi đáp án E không hợp lệ",
    "choices": ["A. 1", "B. 2", "C. 3", "D. 4"],
    "correctAnswer": "E",
    "difficulty": "nhanBiet"
  }
]
''';
      expect(
        () => AiQuestionResponseParser.parseAndValidate(raw),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains(AiQuestionErrorCodes.invalidCorrectAnswer),
        )),
      );
    });

    test('7. Invalid type fails with INVALID_TYPE', () {
      const raw = '''
[
  {
    "type": "invalid_unknown_type",
    "prompt": "Câu hỏi sai loại",
    "choices": ["A. 1", "B. 2", "C. 3", "D. 4"],
    "correctAnswer": "A",
    "difficulty": "nhanBiet"
  }
]
''';
      expect(
        () => AiQuestionResponseParser.parseAndValidate(raw),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains(AiQuestionErrorCodes.invalidType),
        )),
      );
    });

    test('8. Invalid difficulty fails with INVALID_DIFFICULTY without silent fallback', () {
      const raw = '''
[
  {
    "type": "multipleChoice",
    "prompt": "Câu hỏi sai mức độ nhận thức",
    "choices": ["A. 1", "B. 2", "C. 3", "D. 4"],
    "correctAnswer": "A",
    "difficulty": "unknownDifficulty"
  }
]
''';
      expect(
        () => AiQuestionResponseParser.parseAndValidate(raw),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains(AiQuestionErrorCodes.invalidDifficulty),
        )),
      );
    });

    test('9. Empty prompt fails with MISSING_PROMPT', () {
      const raw = '''
[
  {
    "type": "multipleChoice",
    "prompt": "   ",
    "choices": ["A. 1", "B. 2", "C. 3", "D. 4"],
    "correctAnswer": "A",
    "difficulty": "nhanBiet"
  }
]
''';
      expect(
        () => AiQuestionResponseParser.parseAndValidate(raw),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains(AiQuestionErrorCodes.missingPrompt),
        )),
      );
    });

    test('10. Malformed JSON throws FormatException (fail closed)', () {
      const raw = 'Đây là văn bản hỏng [ { "prompt": "chưa đóng ngoặc ';
      expect(
        () => AiQuestionResponseParser.parseAndValidate(raw),
        throwsA(isA<FormatException>()),
      );
    });

    test('11. Markdown code fence parses cleanly', () {
      const raw = '''
```json
[
  {
    "type": "essay",
    "prompt": "Phân tích tâm trạng Thúy Kiều ở lầu Ngưng Bích.",
    "correctAnswer": "Học sinh nêu được tâm trạng cô đơn, buồn tủi, nhớ thương Kim Trọng và cha mẹ.",
    "difficulty": "vanDungCao"
  }
]
```
''';
      final questions = AiQuestionResponseParser.parseAndValidate(raw);
      expect(questions.length, equals(1));
      expect(questions.first.type, equals(QuestionType.essay));
      expect(questions.first.difficulty, equals(QuestionDifficulty.vanDungCao));
    });

    test('12. Text before and after JSON extracts properly and parses', () {
      const raw = '''
Chào thầy cô, dưới đây là danh sách câu hỏi tạo bởi hệ thống:
```json
[
  {
    "type": "trueFalse",
    "prompt": "Truyện Kiều được viết bằng chữ Nôm.",
    "correctAnswer": "True",
    "difficulty": "nhanBiet"
  }
]
```
Chúc thầy cô có bài giảng hiệu quả!
''';
      final questions = AiQuestionResponseParser.parseAndValidate(raw);
      expect(questions.length, equals(1));
      expect(questions.first.type, equals(QuestionType.trueFalse));
    });
  });
}
