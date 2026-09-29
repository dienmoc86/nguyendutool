import '../models/tts_provider_info.dart';
import '../models/tts_request.dart';
import '../models/tts_voice.dart';

/// Abstract contract for a Text-to-Speech synthesis provider engine (Local Windows or Cloud).
abstract class TtsProvider {
  String get id;
  TtsProviderInfo get info;
  bool get isAvailable;

  /// Initializes engine probe and discovers installed/available voices.
  Future<bool> initialize();

  /// Retrieves list of voices supported by this provider.
  Future<List<TtsVoice>> getVoices();

  /// Synthesizes speech for an individual [request] and writes audio to output path.
  /// Returns output audio file path.
  Future<String> synthesize(TtsRequest request);

  /// Cancels any ongoing synthesis task.
  Future<void> cancel();

  /// Disposes resources held by the provider.
  Future<void> dispose();
}
