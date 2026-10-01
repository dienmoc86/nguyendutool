/// Configuration model for AI generation in NguyenDu Tool.
///
/// Supports both local offline inference via iLocal AI and cloud Gemini.
class AiModelConfig {
  static const String providerIlocal = 'ilocal';
  static const String providerGemini = 'gemini';

  static const String defaultProvider = 'ilocal';
  static const String defaultModel = 'gemini-1.5-flash';
  static const String defaultLocalModel = 'qwen2.5-3b-instruct-q4_k_m';

  static const String modelGemini15Flash = 'gemini-1.5-flash';
  static const String modelGemini20Flash = 'gemini-2.0-flash';
  static const String modelGemini25Flash = 'gemini-2.5-flash';
  static const String modelGemini15Pro = 'gemini-1.5-pro';

  static const List<String> supportedModels = [
    modelGemini15Flash,
    modelGemini20Flash,
    modelGemini25Flash,
    modelGemini15Pro,
    'qwen2.5-3b-instruct-q4_k_m',
    'qwen2.5-0.5b-instruct-q4_k_m',
  ];
  static const List<String> availableModels = supportedModels;

  final String provider;
  final String model;
  final int maxOutputTokens;
  final double temperature;
  final double topP;
  final String? systemInstruction;

  const AiModelConfig({
    this.provider = defaultProvider,
    this.model = defaultLocalModel,
    this.maxOutputTokens = 8192,
    this.temperature = 0.7,
    this.topP = 0.95,
    this.systemInstruction,
  });

  /// Default configuration for lesson plan drafting (CV 5512)
  static const AiModelConfig lessonPlannerDefault = AiModelConfig(
    provider: providerIlocal,
    model: defaultLocalModel,
    maxOutputTokens: 8192,
    temperature: 0.6,
  );

  /// Default configuration for quick text extraction & summarization
  static const AiModelConfig generalAssistantDefault = AiModelConfig(
    provider: providerIlocal,
    model: defaultLocalModel,
    maxOutputTokens: 4096,
    temperature: 0.4,
  );

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'model': model,
        'maxOutputTokens': maxOutputTokens,
        'temperature': temperature,
        'topP': topP,
        'systemInstruction': systemInstruction,
      };

  factory AiModelConfig.fromJson(Map<String, dynamic> json) {
    return AiModelConfig(
      provider: json['provider'] as String? ?? defaultProvider,
      model: json['model'] as String? ??
          (json['provider'] == providerGemini ? defaultModel : defaultLocalModel),
      maxOutputTokens: (json['maxOutputTokens'] as num?)?.toInt() ?? 8192,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
      topP: (json['topP'] as num?)?.toDouble() ?? 0.95,
      systemInstruction: json['systemInstruction'] as String?,
    );
  }

  AiModelConfig copyWith({
    String? provider,
    String? model,
    int? maxOutputTokens,
    double? temperature,
    double? topP,
    String? systemInstruction,
  }) {
    return AiModelConfig(
      provider: provider ?? this.provider,
      model: model ?? this.model,
      maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      systemInstruction: systemInstruction ?? this.systemInstruction,
    );
  }
}
