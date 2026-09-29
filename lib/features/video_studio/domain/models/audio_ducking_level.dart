/// Audio ducking levels to automatically lower background music when voiceover is present.
enum AudioDuckingLevel {
  off(attenuationDb: 0, ratio: 1.0, displayName: 'Tắt (Không giảm nhạc)'),
  light(attenuationDb: -8, ratio: 0.40, displayName: 'Nhẹ (-8 dB)'),
  medium(attenuationDb: -14, ratio: 0.20, displayName: 'Vừa (-14 dB)'),
  strong(attenuationDb: -20, ratio: 0.10, displayName: 'Mạnh (-20 dB)');

  final int attenuationDb;
  final double ratio;
  final String displayName;

  const AudioDuckingLevel({
    required this.attenuationDb,
    required this.ratio,
    required this.displayName,
  });
}
