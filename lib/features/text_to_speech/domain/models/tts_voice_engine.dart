/// Explicit synthesis backend engine supporting a voice.
/// Ensures that a user selecting voice A is never silently synthesized on voice B.
enum TtsVoiceEngine {
  /// Windows SAPI 5.4 Desktop voices (e.g. Microsoft Hazel Desktop, Microsoft Zira Desktop)
  sapi,

  /// Windows 10/11 OneCore / Natural voices (e.g. Microsoft George, Microsoft Hazel OneCore)
  oneCore,

  /// Cloud TTS providers (Google Cloud TTS, Microsoft Azure Speech)
  cloud,
}
