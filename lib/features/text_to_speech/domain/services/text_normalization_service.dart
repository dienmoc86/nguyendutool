/// Contract for text normalization service before speech synthesis.
abstract class TextNormalizationService {
  /// Normalizes input text according to language rules and speech requirements.
  /// Preserves meaning without aggressive rewriting.
  String normalize(String rawText, {String language = 'vi-VN'});

  /// Extracts manual pause markers like [pause 500ms] and returns clean text with pause positions.
  List<TextSegmentWithPause> parsePauseMarkers(String text);
}

/// Represents a slice of text with an explicit trailing pause in milliseconds.
class TextSegmentWithPause {
  final String text;
  final int pauseMs;

  const TextSegmentWithPause({
    required this.text,
    this.pauseMs = 0,
  });
}
