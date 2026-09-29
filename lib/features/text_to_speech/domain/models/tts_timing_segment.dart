/// Represents a timing segment for subtitles (SRT/VTT) and synchronized playback.
class TtsTimingSegment {
  final int index;
  final int startMs;
  final int endMs;
  final String text;
  final bool isEstimated; // True if calculated from word/char rate rather than exact engine boundary

  const TtsTimingSegment({
    required this.index,
    required this.startMs,
    required this.endMs,
    required this.text,
    this.isEstimated = false,
  });

  int get durationMs => endMs - startMs;

  Map<String, dynamic> toJson() => {
        'index': index,
        'startMs': startMs,
        'endMs': endMs,
        'text': text,
        'isEstimated': isEstimated,
      };

  factory TtsTimingSegment.fromJson(Map<String, dynamic> json) => TtsTimingSegment(
        index: json['index'] as int? ?? 0,
        startMs: json['startMs'] as int? ?? 0,
        endMs: json['endMs'] as int? ?? 0,
        text: json['text'] as String? ?? '',
        isEstimated: json['isEstimated'] as bool? ?? false,
      );
}
