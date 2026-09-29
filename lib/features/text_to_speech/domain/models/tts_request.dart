import 'tts_options.dart';
import 'tts_voice.dart';

/// Request parameter object passed to TTS providers.
class TtsRequest {
  final String text;
  final TtsVoice voice;
  final TtsOptions options;
  final int? chunkIndex;
  final String? outputPath;
  final bool isPreview;

  const TtsRequest({
    required this.text,
    required this.voice,
    this.options = const TtsOptions(),
    this.chunkIndex,
    this.outputPath,
    this.isPreview = false,
  });
}
