import '../errors/app_exceptions.dart';
import 'base_provider.dart';

/// Contract for AI text & multimodal inference providers.
abstract class AiProvider extends BaseProvider {
  AiProvider({super.isEnabled});

  @override
  ProviderCategory get category => ProviderCategory.ai;

  /// Generate text completion / analysis
  Future<String> generateText(String prompt, {Map<String, dynamic>? options});
}

/// Unimplemented placeholder provider for Google Gemini (Requirements 5 & 6).
/// Explicitly marked notImplemented, unavailable, disabled by default, fails closed.
class GeminiAiProvider extends AiProvider {
  @override
  final String id = 'gemini';
  @override
  final String name = 'Google Gemini (1.5/2.0)';
  @override
  final String description = 'Mô hình đa phương thức xử lý kịch bản nâng cao (Chưa kích hoạt ở phiên bản này).';
  @override
  final bool isLocal = false;

  @override
  ProviderImplementationStatus get implementationStatus => ProviderImplementationStatus.notImplemented;

  @override
  ProviderCapabilityState get capabilityState => ProviderCapabilityState.unavailable;

  GeminiAiProvider() : super(isEnabled: false);

  @override
  Future<bool> checkHealth() async => false;

  @override
  Future<String> generateText(String prompt, {Map<String, dynamic>? options}) async {
    throw const ProviderException(
      'Google Gemini chưa được hỗ trợ trong phiên bản phát hành này. Vui lòng sử dụng tính năng cục bộ.',
      providerId: 'gemini',
    );
  }
}

/// Unimplemented placeholder provider for OpenAI (Requirements 5 & 6).
/// Explicitly marked notImplemented, unavailable, disabled by default, fails closed.
class OpenAiProvider extends AiProvider {
  @override
  final String id = 'openai';
  @override
  final String name = 'OpenAI (GPT-4o)';
  @override
  final String description = 'Hỗ trợ trích xuất cấu trúc văn bản nâng cao (Chưa kích hoạt ở phiên bản này).';
  @override
  final bool isLocal = false;

  @override
  ProviderImplementationStatus get implementationStatus => ProviderImplementationStatus.notImplemented;

  @override
  ProviderCapabilityState get capabilityState => ProviderCapabilityState.unavailable;

  OpenAiProvider() : super(isEnabled: false);

  @override
  Future<bool> checkHealth() async => false;

  @override
  Future<String> generateText(String prompt, {Map<String, dynamic>? options}) async {
    throw const ProviderException(
      'OpenAI chưa được hỗ trợ trong phiên bản phát hành này. Vui lòng sử dụng tính năng cục bộ.',
      providerId: 'openai',
    );
  }
}
