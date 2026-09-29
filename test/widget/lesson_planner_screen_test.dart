import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/ai/google_auth_service.dart';
import 'package:nguyendu_tool/core/filesystem/workspace_manager.dart';
import 'package:nguyendu_tool/core/providers/app_providers.dart';
import 'package:nguyendu_tool/core/providers/secure_storage_abstraction.dart';
import 'package:nguyendu_tool/features/lesson_planner/application/lesson_planner_notifier.dart';
import 'package:nguyendu_tool/features/lesson_planner/presentation/lesson_planner_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late WorkspaceManager workspaceManager;
  late ISecureStorage secureStorage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lesson_planner_test_');
    workspaceManager = WorkspaceManager(tempDir.path);
    await workspaceManager.init();
    secureStorage = SecureStorageService();
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('LessonPlannerScreen renders onboarding card when unauthenticated', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceManagerProvider.overrideWithValue(workspaceManager),
          secureStorageProvider.overrideWithValue(secureStorage),
        ],
        child: const MaterialApp(
          home: LessonPlannerScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify header and 5512 title
    expect(find.text('Soạn Giáo án AI Chuẩn Công văn 5512/BGDĐT-GDTrH'), findsOneWidget);

    // Verify Google connection prompt
    expect(find.text('Kết nối Google Gemini AI để bắt đầu soạn giáo án'), findsOneWidget);
    expect(find.text('1. Mở trang Google lấy khóa miễn phí'), findsOneWidget);

    // Verify form fields
    expect(find.text('Môn học'), findsOneWidget);
    expect(find.text('Khối lớp'), findsOneWidget);
    expect(find.text('Bộ sách giáo khoa'), findsOneWidget);
    expect(find.text('Tên bài học / Tiết dạy *'), findsOneWidget);
    expect(find.text('Soạn Giáo án AI chuẩn 5512'), findsOneWidget);

    await tester.pump();
  });

  testWidgets('LessonPlannerScreen validates required title before generating', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceManagerProvider.overrideWithValue(workspaceManager),
          secureStorageProvider.overrideWithValue(secureStorage),
        ],
        child: const MaterialApp(
          home: LessonPlannerScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap generate without entering title
    final generateBtn = find.text('Soạn Giáo án AI chuẩn 5512');
    await tester.tap(generateBtn);
    await tester.pumpAndSettle();

    // Validation error must appear
    expect(find.text('Vui lòng nhập tên bài dạy.'), findsOneWidget);
  });
}
