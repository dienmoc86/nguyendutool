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
import 'package:nguyendu_tool/features/dashboard/presentation/widgets/module_card.dart';

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

  testWidgets('Dashboard renders 4 core module cards and recent jobs', (tester) async {
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

    // Verify module cards exist for registered active modules
    expect(find.byType(ModuleCard), findsAtLeastNWidgets(5));

    // Verify core modules by widget type and registry names
    expect(find.widgetWithText(ModuleCard, 'Trợ lý Giảng dạy (Teaching Suite)'), findsOneWidget);
    expect(find.widgetWithText(ModuleCard, 'Chuyển đổi PDF & Tài liệu'), findsOneWidget);
    expect(find.widgetWithText(ModuleCard, 'Quét Đề thi & Số hóa Học liệu'), findsOneWidget);
    expect(find.widgetWithText(ModuleCard, 'Đọc văn bản & Lồng tiếng (TTS)'), findsOneWidget);
    expect(find.widgetWithText(ModuleCard, 'Xưởng dựng Video Bài giảng'), findsOneWidget);

    // Verify descriptions from ModuleRegistry
    expect(find.textContaining('Chuyển đổi PDF sang Microsoft Word'), findsOneWidget);
    expect(find.textContaining('Kết nối máy scan WIA'), findsOneWidget);
    expect(find.textContaining('Chuyển văn bản giáo án, bài đọc thành giọng nói'), findsOneWidget);
    expect(find.textContaining('Dựng video clip bài giảng điện tử'), findsOneWidget);

    // Verify Recent Jobs section
    expect(find.textContaining('Tác vụ gần đây'), findsOneWidget);

    // Clean up and drain any pending timers
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });
}
