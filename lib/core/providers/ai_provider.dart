import 'package:ilocal_client/ilocal_client.dart';
import 'package:ilocal_protocol/ilocal_protocol.dart';

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

/// Implemented local offline AI provider connected to iLocal AI Shared Core.
class LocalAiCoreProvider extends AiProvider {
  final LocalAIClient _client;

  @override
  final String id = 'ilocal';
  @override
  final String name = 'iLocal AI Core (Offline Qwen 2.5 3B)';
  @override
  final String description = 'Hệ thống AI Core cục bộ chạy ngoại tuyến, tăng tốc qua GPU NVIDIA, phục vụ soạn bài và RAG.';
  @override
  final bool isLocal = true;

  @override
  ProviderImplementationStatus get implementationStatus => ProviderImplementationStatus.implemented;

  ProviderCapabilityState _capabilityState = ProviderCapabilityState.available;

  @override
  ProviderCapabilityState get capabilityState => _capabilityState;

  LocalAiCoreProvider({LocalAIClient? client, super.isEnabled = true})
      : _client = client ?? LocalAIClient(port: 18181);

  @override
  Future<bool> checkHealth() async {
    try {
      final res = await _client.health();
      final ok = res.isSuccess && res.value.isReady;
      _capabilityState = ok ? ProviderCapabilityState.available : ProviderCapabilityState.unavailable;
      return ok;
    } catch (_) {
      _capabilityState = ProviderCapabilityState.unavailable;
      return false;
    }
  }

  @override
  Future<String> generateText(String prompt, {Map<String, dynamic>? options}) async {
    try {
      final res = await _client.generate(ChatRequest(
        model: options?['model'] as String? ?? 'qwen2.5-3b-instruct-q4_k_m',
        messages: [ChatMessage.user(prompt)],
      ));
      if (res.isSuccess) {
        return res.value.text;
      }
      throw ProviderException('Lỗi iLocal AI Core: ${res.error.message}', providerId: id);
    } catch (e) {
      throw ProviderException('Không thể sinh văn bản từ iLocal AI: $e', providerId: id);
    }
  }
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
