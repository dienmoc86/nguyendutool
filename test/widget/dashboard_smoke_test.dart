import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/app/app.dart';
import 'package:nguyendu_tool/app/router/app_router.dart';
import 'package:nguyendu_tool/core/database/app_database.dart';
import 'package:nguyendu_tool/core/filesystem/workspace_manager.dart';
import 'package:nguyendu_tool/core/providers/app_providers.dart';
import 'package:nguyendu_tool/core/providers/provider_registry.dart';
import 'package:nguyendu_tool/core/providers/secure_storage_abstraction.dart';
import 'package:nguyendu_tool/core/settings/data/settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late WorkspaceManager workspaceManager;
  late AppDatabase database;
  late SettingsRepository settingsRepository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('widget_test_ws_');
    workspaceManager = WorkspaceManager(tempDir.path);
    await workspaceManager.init();

    database = AppDatabase(inMemory: true);
    await database.init();

    settingsRepository = SettingsRepository(database);
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('Dashboard renders 2 core teacher tools and recent jobs', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final testRouter = createAppRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceManagerProvider.overrideWithValue(workspaceManager),
          databaseProvider.overrideWithValue(database),
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          providerRegistryProvider.overrideWithValue(ProviderRegistry()),
          secureStorageProvider.overrideWithValue(SecureStorageService()),
          appRouterProvider.overrideWithValue(testRouter),
        ],
        child: const ISchoolToolsApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify main welcome title
    expect(find.text('Chào mừng đến với NguyenDu Tool'), findsOneWidget);

    // Verify 3 Core Teacher Tools exist
    expect(find.text('Chuyển đổi File PDF sang Word'), findsOneWidget);
    expect(find.text('Quét & Số hóa (Máy scan / Camera / Điện thoại)'), findsOneWidget);
    expect(find.text('Chuyển Văn bản thành Giọng nói (TTS)'), findsOneWidget);
    expect(find.text('3 Công cụ Trọng tâm Sư phạm'), findsOneWidget);

    // Verify action buttons
    expect(find.text('Mở Chuyển đổi PDF'), findsOneWidget);
    expect(find.text('Mở Quét tài liệu'), findsOneWidget);
    expect(find.text('Mở Đọc văn bản (TTS)'), findsOneWidget);

    // Verify Recent Jobs section
    expect(find.textContaining('Tác vụ gần đây'), findsOneWidget);

    // Clean up and drain any pending timers
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });
}
