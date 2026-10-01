import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/database/app_database.dart';
import 'package:nguyendu_tool/core/filesystem/workspace_manager.dart';
import 'package:nguyendu_tool/core/providers/app_providers.dart';
import 'package:nguyendu_tool/core/providers/secure_storage_abstraction.dart';
import 'package:nguyendu_tool/features/teaching_suite/application/teaching_suite_providers.dart';
import 'support/fake_ai_text_generation_service.dart';
import 'package:nguyendu_tool/features/teaching_suite/presentation/teaching_suite_screen.dart';
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
  sqfliteFfiInit();

  group('Teaching Suite - UI & Offline Interaction Tests (Phase 6B)', () {
    late AppDatabase appDatabase;
    late Directory tempDir;
    late WorkspaceManager workspaceManager;
    late MockSecureStorage mockSecureStorage;
    late FakeAiTextGenerationService fakeAiService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('teaching_suite_ui_test_');
      workspaceManager = WorkspaceManager(tempDir.path);
      await workspaceManager.init();

      appDatabase = AppDatabase(inMemory: true);
      await appDatabase.init();

      mockSecureStorage = MockSecureStorage();
      fakeAiService = FakeAiTextGenerationService();
    });

    tearDown(() async {
      await appDatabase.close();
      try {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    Widget createTestApp({bool isAiConfigured = true}) {
      fakeAiService = FakeAiTextGenerationService(isConfigured: isAiConfigured);

      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(appDatabase),
          workspaceManagerProvider.overrideWithValue(workspaceManager),
          secureStorageProvider.overrideWithValue(mockSecureStorage),
          aiTextGenerationServiceProvider.overrideWithValue(fakeAiService),
        ],
        child: const MaterialApp(
          home: TeachingSuiteScreen(),
        ),
      );
    }

    testWidgets('Teaching Suite opens, renders navigation rail, and shows offline AI badge when not configured', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      await tester.pumpWidget(createTestApp(isAiConfigured: false));
      await tester.pumpAndSettle();

      // Verify title & toolbar
      expect(find.textContaining('Trợ lý Giảng dạy (Teaching Suite)'), findsOneWidget);

      // Verify 6 sub-navigation rail tabs
      expect(find.text('Tổng quan'), findsWidgets);
      expect(find.text('Giáo án'), findsOneWidget);
      expect(find.text('Phiếu học tập'), findsOneWidget);
      expect(find.text('Câu hỏi'), findsOneWidget);
      expect(find.text('Rubric'), findsOneWidget);
      expect(find.text('Sản phẩm'), findsOneWidget);

      // Offline badge when AI is not configured
      expect(find.text('AI chưa cấu hình'), findsWidgets);
    });

    testWidgets('AI configured state shows ready badge and model name', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      await tester.pumpWidget(createTestApp(isAiConfigured: true));
      await tester.pumpAndSettle();

      expect(find.textContaining('Sẵn sàng'), findsWidgets);
    });

    testWidgets('Sub-navigation tab switching activates panels smoothly without crash', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Switch to Giáo án (Lesson plan)
      await tester.tap(find.text('Giáo án'));
      await tester.pumpAndSettle();
      expect(find.text('Tạo toàn văn bằng AI'), findsOneWidget);
      expect(find.text('Xuất Word (.docx)'), findsOneWidget);

      // Switch to Phiếu học tập (Worksheet)
      await tester.tap(find.text('Phiếu học tập'));
      await tester.pumpAndSettle();
      expect(find.text('Tạo phiếu bằng AI'), findsOneWidget);
      expect(find.text('Thêm bài tập'), findsOneWidget);

      // Switch to Câu hỏi (Question Bank)
      await tester.tap(find.text('Câu hỏi'));
      await tester.pumpAndSettle();
      expect(find.text('Sinh câu hỏi bằng AI'), findsOneWidget);
      expect(find.text('Thêm câu hỏi'), findsOneWidget);
      expect(find.text('Tạo Đề nhanh (Mini Assessment)'), findsOneWidget);

      // Switch to Rubric
      await tester.tap(find.text('Rubric'));
      await tester.pumpAndSettle();
      expect(find.text('Tạo Rubric bằng AI'), findsOneWidget);
      expect(find.text('Thêm tiêu chí'), findsOneWidget);
      expect(find.textContaining('Tổng trọng số:'), findsOneWidget);

      // Switch to Sản phẩm (Artifacts)
      await tester.tap(find.text('Sản phẩm'));
      await tester.pumpAndSettle();
      expect(find.text('Xuất trọn bộ sản phẩm (Export All)'), findsOneWidget);
    });

    testWidgets('Creates new lesson project via modal dialog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Tap New Project button
      await tester.tap(find.byTooltip('Tạo dự án bài dạy mới'));
      await tester.pumpAndSettle();

      expect(find.text('Tạo dự án bài dạy mới'), findsOneWidget);

      // Enter title
      await tester.enterText(find.byType(TextField).last, 'Ngữ văn 9 - Bếp lửa');
      await tester.runAsync(() async {
        await tester.tap(find.text('Tạo dự án'));
        await Future.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();

      // Verify title updated
      expect(find.text('Ngữ văn 9 - Bếp lửa'), findsWidgets);
    });

    testWidgets('Question Bank allows adding manual questions and displays them', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Navigate to Câu hỏi
      await tester.tap(find.text('Câu hỏi'));
      await tester.pumpAndSettle();

      // Tap Thêm câu hỏi
      await tester.runAsync(() async {
        await tester.tap(find.text('Thêm câu hỏi'));
        await Future.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();

      expect(find.text('Câu 1'), findsOneWidget);
      expect(find.text('Phương án A'), findsWidgets);
    });

    testWidgets('Rubric panel displays criteria and weight status', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Navigate to Rubric
      await tester.tap(find.text('Rubric'));
      await tester.pumpAndSettle();

      expect(find.text('Thêm tiêu chí'), findsOneWidget);
      expect(find.textContaining('Tổng trọng số:'), findsOneWidget);
    });
  });
}
