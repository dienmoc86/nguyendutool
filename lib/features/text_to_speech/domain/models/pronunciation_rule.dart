/// Pronunciation dictionary mapping rule for replacing acronyms or domain phrases with spoken phonetic text.
class PronunciationRule {
  final String id;
  final String sourcePhrase;
  final String replacementPhrase;
  final bool isCaseSensitive;
  final bool isRegex;
  final String? notes;

  const PronunciationRule({
    required this.id,
    required this.sourcePhrase,
    required this.replacementPhrase,
    this.isCaseSensitive = false,
    this.isRegex = false,
    this.notes,
  });

  /// Applies this replacement rule to [inputText] without modifying other contents.
  String apply(String inputText) {
    if (inputText.isEmpty || sourcePhrase.isEmpty) return inputText;

    if (isRegex) {
      try {
        final reg = RegExp(sourcePhrase, caseSensitive: isCaseSensitive);
        return inputText.replaceAll(reg, replacementPhrase);
      } catch (_) {
        return inputText;
      }
    } else {
      if (isCaseSensitive) {
        return inputText.replaceAll(sourcePhrase, replacementPhrase);
      } else {
        final pattern = RegExp(RegExp.escape(sourcePhrase), caseSensitive: false);
        return inputText.replaceAll(pattern, replacementPhrase);
      }
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'source_phrase': sourcePhrase,
        'replacement_phrase': replacementPhrase,
        'is_case_sensitive': isCaseSensitive ? 1 : 0,
        'is_regex': isRegex ? 1 : 0,
        'notes': notes,
      };

  factory PronunciationRule.fromJson(Map<String, dynamic> json) => PronunciationRule(
        id: json['id'] as String? ?? '',
        sourcePhrase: json['source_phrase'] as String? ?? '',
        replacementPhrase: json['replacement_phrase'] as String? ?? '',
        isCaseSensitive: json['is_case_sensitive'] == 1 || json['is_case_sensitive'] == true,
        isRegex: json['is_regex'] == 1 || json['is_regex'] == true,
        notes: json['notes'] as String?,
      );
}
