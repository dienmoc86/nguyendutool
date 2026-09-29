import '../../features/text_to_speech/domain/models/tts_options.dart';
import '../../features/text_to_speech/domain/models/tts_request.dart';
import '../../features/text_to_speech/domain/models/tts_voice.dart';
import '../../features/text_to_speech/infrastructure/azure_speech_provider.dart';
import '../../features/text_to_speech/infrastructure/google_cloud_tts_provider.dart';
import '../../features/text_to_speech/infrastructure/windows_speech_synthesizer_provider.dart';
import '../errors/app_exceptions.dart';
import '../security/credential_service.dart';
import 'base_provider.dart';

/// Contract for Text-to-Speech audio generation engines in the unified provider registry.
abstract class TtsProvider extends BaseProvider {
  TtsProvider({super.isEnabled});

  @override
  ProviderCategory get category => ProviderCategory.tts;

  /// Synthesizes text into audio file at outputPath.
  Future<String> synthesizeToAudio(
    String text, {
    required String outputPath,
    String? voiceCode,
    double speed = 1.0,
  });

  /// Lists supported voice profiles.
  Future<List<String>> getAvailableVoices();
}

/// Local offline Windows SAPI / OneCore TTS provider.
class LocalWindowsTtsProvider extends TtsProvider {
  final WindowsSpeechSynthesizerProvider _delegate;

  @override
  final String id = 'windows_local';
  @override
  final String name = 'Giọng đọc Windows Cục bộ (SAPI / OneCore)';
  @override
  final String description = 'Tổng hợp giọng đọc offline tiếng Việt và tiếng Anh chuẩn Windows, không cần internet.';
  @override
  final bool isLocal = true;

  @override
  ProviderImplementationStatus get implementationStatus => ProviderImplementationStatus.implemented;

  @override
  ProviderCapabilityState get capabilityState =>
      _delegate.isAvailable ? ProviderCapabilityState.available : ProviderCapabilityState.unavailable;

  LocalWindowsTtsProvider({WindowsSpeechSynthesizerProvider? delegate})
      : _delegate = delegate ?? WindowsSpeechSynthesizerProvider(),
        super(isEnabled: true);

  WindowsSpeechSynthesizerProvider get delegate => _delegate;

  @override
  Future<bool> checkHealth() async {
    return await _delegate.initialize();
  }

  @override
  Future<String> synthesizeToAudio(
    String text, {
    required String outputPath,
    String? voiceCode,
    double speed = 1.0,
  }) async {
    final voice = voiceCode != null
        ? _delegate.voices.firstWhere(
            (v) => v.id == voiceCode || v.name == voiceCode,
            orElse: () => _delegate.voices.isNotEmpty
                ? _delegate.voices.first
                : const TtsVoice(
                    id: 'default',
                    name: 'Default Voice',
                    language: 'vi-VN',
                    locale: 'vi-VN',
                    providerId: 'windows_local',
                  ),
          )
        : (_delegate.voices.isNotEmpty
            ? _delegate.voices.first
            : const TtsVoice(
                id: 'default',
                name: 'Default Voice',
                language: 'vi-VN',
                locale: 'vi-VN',
                providerId: 'windows_local',
              ));

    final request = TtsRequest(
      text: text,
      voice: voice,
      outputPath: outputPath,
      options: TtsOptions(
        speed: speed,
        format: TtsAudioFormat.wav,
      ),
    );
    return await _delegate.synthesize(request);
  }

  @override
  Future<List<String>> getAvailableVoices() async {
    await _delegate.initialize();
    return _delegate.voices.map((v) => v.name).toList();
  }
}

/// Unified Google Cloud TTS Provider (Requirements 5, 6, 7, 46, 47).
/// Defaults to disabled / notConfigured until API key is explicitly configured in secure storage.
class GoogleTtsProvider extends TtsProvider {
  final GoogleCloudTtsProvider _delegate;
  final CredentialService _credentialService;

  @override
  final String id = 'google_tts';
  @override
  final String name = 'Google Cloud Text-to-Speech';
  @override
  final String description = 'Giọng đọc WaveNet & Neural2 chuẩn tiếng Việt đám mây (Yêu cầu Google Cloud API Key).';
  @override
  final bool isLocal = false;

  @override
  ProviderImplementationStatus get implementationStatus => ProviderImplementationStatus.implemented;

  @override
  ProviderCapabilityState get capabilityState {
    if (_delegate.info.isConfigured) {
      return isEnabled ? ProviderCapabilityState.available : ProviderCapabilityState.notConfigured;
    }
    return ProviderCapabilityState.notConfigured;
  }

  GoogleTtsProvider({
    GoogleCloudTtsProvider? delegate,
    CredentialService? credentialService,
  })  : _delegate = delegate ?? GoogleCloudTtsProvider(),
        _credentialService = credentialService ?? CredentialService(),
        super(isEnabled: false);

  GoogleCloudTtsProvider get delegate => _delegate;

  /// Loads credentials from secure DPAPI storage on startup or configure.
  Future<void> reloadCredentials() async {
    final apiKey = await _credentialService.getGoogleTtsApiKey();
    _delegate.configureApiKey(apiKey);
    isEnabled = apiKey != null && apiKey.trim().isNotEmpty;
  }

  @override
  Future<bool> checkHealth() async {
    await reloadCredentials();
    if (!_delegate.info.isConfigured) return false;
    return await _delegate.initialize();
  }

  @override
  Future<String> synthesizeToAudio(
    String text, {
    required String outputPath,
    String? voiceCode,
    double speed = 1.0,
  }) async {
    await reloadCredentials();
    if (!_delegate.info.isConfigured) {
      throw const TtsProviderAuthException(
        'Google Cloud TTS chưa được cấu hình API Key. Vui lòng thiết lập khóa trong Cài đặt > Nhà cung cấp.',
        providerId: 'google_tts',
      );
    }

    final voices = await _delegate.getVoices();
    final voice = voiceCode != null
        ? voices.firstWhere(
            (v) => v.id == voiceCode || v.name == voiceCode,
            orElse: () => voices.isNotEmpty
                ? voices.first
                : const TtsVoice(
                    id: 'vi-VN-Standard-A',
                    name: 'vi-VN-Standard-A',
                    language: 'vi-VN',
                    locale: 'vi-VN',
                    providerId: 'google_cloud',
                    isOffline: false,
                  ),
          )
        : (voices.isNotEmpty
            ? voices.first
            : const TtsVoice(
                id: 'vi-VN-Standard-A',
                name: 'vi-VN-Standard-A',
                language: 'vi-VN',
                locale: 'vi-VN',
                providerId: 'google_cloud',
                isOffline: false,
              ));

    final request = TtsRequest(
      text: text,
      voice: voice,
      outputPath: outputPath,
      options: TtsOptions(
        speed: speed,
        format: TtsAudioFormat.mp3,
      ),
    );
    return await _delegate.synthesize(request);
  }

  @override
  Future<List<String>> getAvailableVoices() async {
    await reloadCredentials();
    if (!_delegate.info.isConfigured) return const [];
    final voices = await _delegate.getVoices();
    return voices.map((v) => v.name).toList();
  }
}

/// Unified Microsoft Azure Speech Provider (Requirements 5, 6, 7, 46, 47).
/// Defaults to disabled / notConfigured until subscription key is saved in secure storage.
class AzureTtsProvider extends TtsProvider {
  final AzureSpeechProvider _delegate;
  final CredentialService _credentialService;

  @override
  final String id = 'azure_tts';
  @override
  final String name = 'Microsoft Azure Speech Service';
  @override
  final String description = 'Giọng đọc thần kinh Microsoft Azure Neural tiếng Việt (Yêu cầu Khóa đăng ký Azure).';
  @override
  final bool isLocal = false;

  @override
  ProviderImplementationStatus get implementationStatus => ProviderImplementationStatus.implemented;

  @override
  ProviderCapabilityState get capabilityState {
    if (_delegate.info.isConfigured) {
      return isEnabled ? ProviderCapabilityState.available : ProviderCapabilityState.notConfigured;
    }
    return ProviderCapabilityState.notConfigured;
  }

  AzureTtsProvider({
    AzureSpeechProvider? delegate,
    CredentialService? credentialService,
  })  : _delegate = delegate ?? AzureSpeechProvider(),
        _credentialService = credentialService ?? CredentialService(),
        super(isEnabled: false);

  AzureSpeechProvider get delegate => _delegate;

  /// Loads credentials from secure DPAPI storage on startup or configure.
  Future<void> reloadCredentials() async {
    final key = await _credentialService.getAzureSpeechKey();
    final region = await _credentialService.getAzureSpeechRegion() ?? 'southeastasia';
    _delegate.configure(subscriptionKey: key, region: region);
    isEnabled = key != null && key.trim().isNotEmpty;
  }

  @override
  Future<bool> checkHealth() async {
    await reloadCredentials();
    if (!_delegate.info.isConfigured) return false;
    return await _delegate.initialize();
  }

  @override
  Future<String> synthesizeToAudio(
    String text, {
    required String outputPath,
    String? voiceCode,
    double speed = 1.0,
  }) async {
    await reloadCredentials();
    if (!_delegate.info.isConfigured) {
      throw const TtsProviderAuthException(
        'Azure Speech chưa được cấu hình Subscription Key. Vui lòng thiết lập khóa trong Cài đặt > Nhà cung cấp.',
        providerId: 'azure_tts',
      );
    }

    final voices = await _delegate.getVoices();
    final voice = voiceCode != null
        ? voices.firstWhere(
            (v) => v.id == voiceCode || v.name == voiceCode,
            orElse: () => voices.isNotEmpty
                ? voices.first
                : const TtsVoice(
                    id: 'vi-VN-HoaiMyNeural',
                    name: 'vi-VN-HoaiMyNeural',
                    language: 'vi-VN',
                    locale: 'vi-VN',
                    providerId: 'azure_speech',
                    isOffline: false,
                  ),
          )
        : (voices.isNotEmpty
            ? voices.first
            : const TtsVoice(
                id: 'vi-VN-HoaiMyNeural',
                name: 'vi-VN-HoaiMyNeural',
                language: 'vi-VN',
                locale: 'vi-VN',
                providerId: 'azure_speech',
                isOffline: false,
              ));

    final request = TtsRequest(
      text: text,
      voice: voice,
      outputPath: outputPath,
      options: TtsOptions(
        speed: speed,
        format: TtsAudioFormat.mp3,
      ),
    );
    return await _delegate.synthesize(request);
  }

  @override
  Future<List<String>> getAvailableVoices() async {
    await reloadCredentials();
    if (!_delegate.info.isConfigured) return const [];
    final voices = await _delegate.getVoices();
    return voices.map((v) => v.name).toList();
  }
}
