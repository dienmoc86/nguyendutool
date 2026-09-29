/// Category of external or local engine service.
enum ProviderCategory {
  ai('ai', 'Trí tuệ nhân tạo (AI/LLM)'),
  tts('tts', 'Giọng nói (Text-to-Speech)'),
  video('video', 'Sản xuất Video'),
  ocr('ocr', 'Nhận diện ký tự quang học (OCR)');

  final String value;
  final String label;

  const ProviderCategory(this.value, this.label);
}

/// Implementation status of a provider in the application codebase (Requirements 5 & 6).
enum ProviderImplementationStatus {
  implemented('implemented', 'Đã tích hợp'),
  notImplemented('not_implemented', 'Chưa tích hợp');

  final String value;
  final String label;
  const ProviderImplementationStatus(this.value, this.label);
}

/// Real-time operational state of a provider (Requirements 6 & 7).
enum ProviderCapabilityState {
  available('available', 'Khả dụng'),
  notConfigured('not_configured', 'Chưa cấu hình'),
  unavailable('unavailable', 'Không khả dụng'),
  error('error', 'Lỗi kết nối');

  final String value;
  final String label;
  const ProviderCapabilityState(this.value, this.label);
}

/// Authoritative Base interface for all engine adapters in NguyenDu Tool.
abstract class BaseProvider {
  String get id;
  String get name;
  ProviderCategory get category;
  String get description;
  bool get isLocal;
  bool isEnabled;

  ProviderImplementationStatus get implementationStatus;
  ProviderCapabilityState get capabilityState;

  BaseProvider({
    this.isEnabled = false,
  });

  /// Validates connectivity and configuration readiness with honest status.
  Future<bool> checkHealth();

  Map<String, dynamic> toMetadata() => {
    'id': id,
    'name': name,
    'category': category.value,
    'description': description,
    'is_local': isLocal,
    'is_enabled': isEnabled,
    'implementation_status': implementationStatus.value,
    'capability_state': capabilityState.value,
  };
}
