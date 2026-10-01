import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/database/app_database.dart';
import 'package:nguyendu_tool/core/filesystem/workspace_manager.dart';
import 'package:nguyendu_tool/core/providers/app_providers.dart';
import 'package:nguyendu_tool/core/providers/secure_storage_abstraction.dart';
import 'package:nguyendu_tool/features/lesson_planner/presentation/lesson_planner_screen.dart';
import 'package:nguyendu_tool/features/teaching_suite/application/teaching_suite_providers.dart';
import '../features/teaching_suite/support/fake_ai_text_generation_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockSecureStorage implements ISecureStorage {
  final Map<String, String> _storage = {};

  @override
  Future<void> writeSecret(String key, String value) async => _storage[key] = value;

  @override
  Future<String?> readSecret(String key) async => _storage[key];

  @override
  Future<void> deleteSecret(String key) async => _storage.remove(key);

  @override
  Future<bool> hasSecret(String key) async => _storage.containsKey(key);

  @override
  Future<bool> containsSecret(String key) async => _storage.containsKey(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase appDatabase;
  late Directory tempDir;
  late WorkspaceManager workspaceManager;
  late ISecureStorage secureStorage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lesson_planner_test_');
    workspaceManager = WorkspaceManager(tempDir.path);
    await workspaceManager.init();

    appDatabase = AppDatabase(inMemory: true);
    await appDatabase.init();

    secureStorage = MockSecureStorage();
  });

  tearDown(() async {
    await appDatabase.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('LessonPlannerScreen renders onboarding card when unauthenticated', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceManagerProvider.overrideWithValue(workspaceManager),
          secureStorageProvider.overrideWithValue(secureStorage),
          databaseProvider.overrideWithValue(appDatabase),
          aiTextGenerationServiceProvider.overrideWithValue(FakeAiTextGenerationService(isConfigured: false)),
        ],
        child: const MaterialApp(
          home: LessonPlannerScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Teaching Suite header & tabs
    expect(find.textContaining('Trợ lý Giảng dạy (Teaching Suite)'), findsOneWidget);
    expect(find.text('Tổng quan'), findsWidgets);
    expect(find.text('Giáo án'), findsOneWidget);
    expect(find.text('Phiếu học tập'), findsOneWidget);
    expect(find.text('Câu hỏi'), findsOneWidget);
    expect(find.text('Rubric'), findsOneWidget);
    expect(find.text('Sản phẩm'), findsOneWidget);

    // Verify overview form fields
    expect(find.text('Môn học'), findsOneWidget);
    expect(find.text('Khối lớp'), findsOneWidget);
    expect(find.text('Bộ sách giáo khoa'), findsOneWidget);
    expect(find.text('Tên bài dạy / Chủ đề bài học *'), findsOneWidget);
  });

  testWidgets('LessonPlannerScreen allows navigating to Lesson Plan tab and shows CV 5512 actions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceManagerProvider.overrideWithValue(workspaceManager),
          secureStorageProvider.overrideWithValue(secureStorage),
          databaseProvider.overrideWithValue(appDatabase),
          aiTextGenerationServiceProvider.overrideWithValue(FakeAiTextGenerationService(isConfigured: false)),
        ],
        child: const MaterialApp(
          home: LessonPlannerScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Switch to Giáo án (Lesson plan tab)
    await tester.tap(find.text('Giáo án'));
    await tester.pumpAndSettle();

    expect(find.text('Tạo toàn văn bằng AI'), findsOneWidget);
    expect(find.text('Xuất Word (.docx)'), findsOneWidget);
  });
}
