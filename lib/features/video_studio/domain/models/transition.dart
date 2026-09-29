/// Scene transition types supported cleanly in FFmpeg.
enum TransitionType {
  none('none', 'Cắt tức thì (None)'),
  fade('fade', 'Mờ dần (Fade)'),
  crossfade('dissolve', 'Hòa tan (Crossfade)'),
  slideLeft('slideleft', 'Trượt sang trái (Slide Left)'),
  slideRight('slideright', 'Trượt sang phải (Slide Right)');

  final String xfadeName;
  final String displayName;

  const TransitionType(this.xfadeName, this.displayName);
}

/// Transition configuration between scenes.
class SceneTransition {
  final TransitionType type;
  final double durationSeconds; // 0.25, 0.5, 1.0

  const SceneTransition({
    this.type = TransitionType.fade,
    this.durationSeconds = 0.5,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'durationSeconds': durationSeconds,
      };

  factory SceneTransition.fromJson(Map<String, dynamic> json) => SceneTransition(
        type: TransitionType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => TransitionType.fade,
        ),
        durationSeconds: (json['durationSeconds'] as num?)?.toDouble() ?? 0.5,
      );
}
