import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilocal_client/ilocal_client.dart';
import 'package:ilocal_protocol/ilocal_protocol.dart';
import 'package:nguyendu_tool/core/ai/ai_model_config.dart';
import 'package:nguyendu_tool/core/providers/ai_provider.dart';
import 'package:nguyendu_tool/core/providers/base_provider.dart';
import 'package:nguyendu_tool/core/providers/provider_registry.dart';
import 'package:nguyendu_tool/features/teaching_suite/application/ai_text_generation_service.dart';
import 'package:nguyendu_tool/features/teaching_suite/application/teaching_suite_providers.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/lesson_project_data.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/worksheet_models.dart';
import 'package:nguyendu_tool/features/teaching_suite/infrastructure/gemini_ai_text_generation_service.dart';
import 'package:nguyendu_tool/features/teaching_suite/infrastructure/ilocal_ai_text_generation_service.dart';

class MockLocalAIClient implements LocalAIClient {
  final bool isHealthy;
  final String? chatResponse;

  MockLocalAIClient({this.isHealthy = true, this.chatResponse});

  @override
  Future<ClientResult<HealthResponse>> health() async {
    if (isHealthy) {
      return ClientSuccess(HealthResponse(
        status: 'ok',
        runtimeReachable: true,
        modelLoaded: true,
        checkedAt: DateTime.now().toIso8601String(),
      ));
    } else {
      return const ClientFailure(
        ErrorResponse(code: 'UNAVAILABLE', message: 'Core is down', timestamp: '2026-10-01T12:00:00Z'),
        503,
      );
    }
  }

  @override
  Future<ClientResult<ChatResponse>> generate(ChatRequest request) async {
    if (chatResponse != null) {
      return ClientSuccess(ChatResponse(
        id: 'mock_chat_1',
        createdAt: DateTime.now().toIso8601String(),
        model: request.model ?? 'qwen2.5-3b-instruct-q4_k_m',
        choices: [
          ChatChoice(
            index: 0,
            content: chatResponse!,
            finishReason: 'stop',
          ),
        ],
      ));
    }
    return const ClientFailure(
      ErrorResponse(code: 'ERROR', message: 'No mock response configured', timestamp: '2026-10-01T12:00:00Z'),
      500,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ILocalAiTextGenerationService Unit Tests', () {
    test('Default properties and identification', () {
      final service = ILocalAiTextGenerationService();
      expect(service.providerName, equals('ilocal'));
      expect(service.currentModel, equals('qwen2.5-3b-instruct-q4_k_m'));
    });

    test('extractJson parses clean JSON, markdown code blocks, and embedded text', () {
      // 1. Raw JSON
      const raw = '{"key": "value"}';
      expect(ILocalAiTextGenerationService.extractJson(raw), equals('{"key": "value"}'));

      // 2. Markdown fenced JSON
      const markdown = '```json\n{"tasks": [1, 2, 3]}\n```';
      expect(ILocalAiTextGenerationService.extractJson(markdown), equals('{"tasks": [1, 2, 3]}'));

      // 3. Surrounded by conversational text
      const conversational = 'Dưới đây là kết quả:\n```json\n{"status": "ok"}\n```\nChúc bạn thành công!';
      expect(ILocalAiTextGenerationService.extractJson(conversational), equals('{"status": "ok"}'));
    });

    test('testConnection returns ok when mock client is healthy', () async {
      final mock = MockLocalAIClient(isHealthy: true);
      final service = ILocalAiTextGenerationService(client: mock);

      final result = await service.testConnection();
      expect(result.status, equals(AiConnectionStatus.ok));
      expect(result.isSuccessful, isTrue);
      expect(result.provider, equals('ilocal'));
    });

    test('testConnection returns networkError when mock client fails', () async {
      final mock = MockLocalAIClient(isHealthy: false);
      final service = ILocalAiTextGenerationService(client: mock);

      final result = await service.testConnection();
      expect(result.status, equals(AiConnectionStatus.networkError));
      expect(result.isSuccessful, isFalse);
    });

    test('generateWorksheet parses mock JSON correctly', () async {
      const mockWsJson = '''
```json
{
  "title": "Phiếu học tập: Đoạn trích Chị em Thúy Kiều",
  "durationMinutes": 20,
  "tasks": [
    {
      "taskNumber": 1,
      "instruction": "Nêu những vẻ đẹp của Thúy Vân và Thúy Kiều",
      "taskType": "shortAnswer",
      "allocatedMinutes": 10,
      "maxScore": 5.0
    }
  ],
  "teacherNotes": "Lưu ý HS so sánh bút pháp ước lệ"
}
```
''';
      final mock = MockLocalAIClient(chatResponse: mockWsJson);
      final service = ILocalAiTextGenerationService(client: mock);

      final project = LessonProjectData(
        lessonTitle: 'Chị em Thúy Kiều',
        subject: 'Ngữ văn',
        grade: '9',
      );

      final ws = await service.generateWorksheet(
        project: project,
        preset: WorksheetPreset.luyenTap,
        taskCount: 1,
      );

      expect(ws.title, contains('Chị em Thúy Kiều'));
      expect(ws.durationMinutes, equals(20));
      expect(ws.tasks.length, equals(1));
      expect(ws.tasks.first.instruction, contains('vẻ đẹp'));
    });
  });

  group('LocalAiCoreProvider & ProviderRegistry Tests', () {
    test('LocalAiCoreProvider has correct properties and is implemented', () {
      final provider = LocalAiCoreProvider();
      expect(provider.id, equals('ilocal'));
      expect(provider.isLocal, isTrue);
      expect(provider.implementationStatus, equals(ProviderImplementationStatus.implemented));
      expect(provider.isEnabled, isTrue);
    });

    test('ProviderRegistry registers LocalAiCoreProvider by default', () {
      final registry = ProviderRegistry();
      final p = registry.getProviderById('ilocal');
      expect(p, isNotNull);
      expect(p, isA<LocalAiCoreProvider>());
      expect(p!.isEnabled, isTrue);
    });
  });

  group('Riverpod Provider Switching Tests', () {
    test('aiTextGenerationServiceProvider provides ILocalAiTextGenerationService by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service = container.read(aiTextGenerationServiceProvider);
      expect(service, isA<ILocalAiTextGenerationService>());
      expect(service.providerName, equals('ilocal'));
    });

    test('aiTextGenerationServiceProvider switches to Gemini when config provider is gemini', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(teachingSuiteAiConfigProvider.notifier).state = const AiModelConfig(
        provider: AiModelConfig.providerGemini,
        model: 'gemini-1.5-flash',
      );

      final service = container.read(aiTextGenerationServiceProvider);
      expect(service, isA<GeminiAiTextGenerationService>());
      expect(service.providerName, equals('gemini'));
    });
  });

  group('Live iLocal AI Daemon Probe (Port 18181)', () {
    test('Probing actual running iLocal AI Core returns healthy and ok', () async {
      final service = ILocalAiTextGenerationService(port: 18181);
      final result = await service.testConnection();

      print('Live testConnection result: \${result.status} - \${result.message} (\${result.latencyMs}ms)');
      expect(result.status, equals(AiConnectionStatus.ok));
      expect(result.isSuccessful, isTrue);
    });
  });
}
