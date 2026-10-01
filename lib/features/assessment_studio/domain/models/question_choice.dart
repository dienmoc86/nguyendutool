import 'dart:convert';

/// Represents a stable multiple choice option for an MCQ question (Sections 34 & 35).
/// Preserves choice identity across multi-code permutations and answer remappings.
class QuestionChoice {
  final String id;
  final String text;

  const QuestionChoice({
    required this.id,
    required this.text,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
      };

  factory QuestionChoice.fromMap(Map<String, dynamic> map) => QuestionChoice(
        id: (map['id'] as String?) ?? '',
        text: (map['text'] as String?) ?? '',
      );

  String toJson() => jsonEncode(toMap());

  factory QuestionChoice.fromJson(String source) =>
      QuestionChoice.fromMap(jsonDecode(source) as Map<String, dynamic>);

  /// Converts a simple list of string choices into stable indexed choices:
  /// e.g. ["A. One", "B. Two", "C. Three", "D. Four"] -> [c0, c1, c2, c3]
  static List<QuestionChoice> fromStrings(List<String> rawStrings) {
    final cleanRegex = RegExp(r'^[A-Da-d][\.\:\)]\s*');
    return List.generate(rawStrings.length, (index) {
      final raw = rawStrings[index];
      final text = raw.replaceFirst(cleanRegex, '').trim();
      return QuestionChoice(id: 'c$index', text: text.isNotEmpty ? text : raw.trim());
    });
  }

  /// Maps an index (0, 1, 2, 3) to standard Vietnamese/English choice letters (A, B, C, D)
  static String indexToLetter(int index) {
    switch (index) {
      case 0:
        return 'A';
      case 1:
        return 'B';
      case 2:
        return 'C';
      case 3:
        return 'D';
      default:
        return String.fromCharCode(65 + index);
    }
  }

  /// Maps choice letter (A, B, C, D) to zero-based index
  static int letterToIndex(String letter) {
    final clean = letter.trim().toUpperCase();
    if (clean.isEmpty) return 0;
    final code = clean.codeUnitAt(0);
    if (code >= 65 && code <= 90) {
      return code - 65;
    }
    return 0;
  }
}
