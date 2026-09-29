import '../errors/app_exceptions.dart';
import '../logging/app_logger.dart';
import 'ai_provider.dart';
import 'base_provider.dart';
import 'ocr_provider.dart';
import 'tts_provider.dart';
import 'video_provider.dart';

/// Central authoritative registry managing all AI, TTS, OCR, and Video providers (Requirements 5, 6, 7).
class ProviderRegistry {
  final Map<String, BaseProvider> _providers = {};

  ProviderRegistry() {
    _registerDefaults();
  }

  void _registerDefaults() {
    // 1. Local / Built-in Implemented Engines (Enabled by default after runtime discovery)
    register(LocalWindowsOcrProvider());
    register(NaturalVietnameseCoreTtsProvider());
    register(LocalWindowsTtsProvider());
    register(LocalTemplateVideoProvider());

    // 2. Cloud Implemented Engines (Disabled by default, requires explicit user configuration via DPAPI)
    register(GoogleTtsProvider());
    register(AzureTtsProvider());

    // 3. Explicitly Unimplemented AI & Video Placeholders (Disabled, Unavailable, Fails Closed)
    register(GeminiAiProvider());
    register(OpenAiProvider());
    register(VeoVideoProvider());
  }

  /// Registers a new provider into the system.
  void register(BaseProvider provider) {
    _providers[provider.id] = provider;
    AppLogger.info('Registered provider: [${provider.id}] ${provider.name} '
        '(${provider.category.label}) [${provider.implementationStatus.label} / ${provider.capabilityState.label}]');
  }

  /// Enables a provider by ID if implemented and configured.
  void enableProvider(String id) {
    final p = _providers[id];
    if (p == null) {
      throw ProviderException('Không tìm thấy provider với ID: $id', providerId: id);
    }
    if (p.implementationStatus == ProviderImplementationStatus.notImplemented) {
      throw ProviderException('Không thể kích hoạt nhà cung cấp chưa được tích hợp: ${p.name}', providerId: id);
    }
    p.isEnabled = true;
    AppLogger.info('Enabled provider: [$id]');
  }

  /// Disables a provider by ID.
  void disableProvider(String id) {
    final p = _providers[id];
    if (p == null) {
      throw ProviderException('Không tìm thấy provider với ID: $id', providerId: id);
    }
    p.isEnabled = false;
    AppLogger.info('Disabled provider: [$id]');
  }

  /// Initializes provider credentials from DPAPI secure storage.
  Future<void> loadSavedCredentials() async {
    for (final p in _providers.values) {
      if (p is GoogleTtsProvider) {
        await p.reloadCredentials();
      } else if (p is AzureTtsProvider) {
        await p.reloadCredentials();
      }
    }
  }

  /// Retrieves a provider by its unique identifier.
  BaseProvider? getProviderById(String id) => _providers[id];

  /// Returns all registered providers.
  List<BaseProvider> listProviders() => _providers.values.toList();

  /// Returns registered providers filtered by category.
  List<T> getProvidersByCategory<T extends BaseProvider>(ProviderCategory category) {
    return _providers.values
        .where((p) => p.category == category)
        .whereType<T>()
        .toList();
  }

  /// Returns only active (enabled) providers for a category.
  List<T> getActiveProvidersByCategory<T extends BaseProvider>(ProviderCategory category) {
    return getProvidersByCategory<T>(category)
        .where((p) => p.isEnabled)
        .toList();
  }
}
