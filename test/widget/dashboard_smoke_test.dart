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

    // Verify exactly 5 module cards exist
    expect(find.byType(ModuleCard), findsNWidgets(5));

    // Verify each specific card by widget type and text
    expect(find.widgetWithText(ModuleCard, 'Soạn Giáo án AI (5512)'), findsOneWidget);
    expect(find.widgetWithText(ModuleCard, 'PDF → Word / Excel'), findsOneWidget);
    expect(find.widgetWithText(ModuleCard, 'Document Scanner'), findsOneWidget);
    expect(find.widgetWithText(ModuleCard, 'Text to Speech'), findsOneWidget);
    expect(find.widgetWithText(ModuleCard, 'Video Studio'), findsOneWidget);

    // Verify subtitles
    expect(find.textContaining('Chuyển đổi PDF, nhận diện tài liệu scan'), findsOneWidget);
    expect(find.textContaining('Scan, làm sạch tài liệu và tạo PDF searchable'), findsOneWidget);
    expect(find.textContaining('Chuyển văn bản thành giọng nói và xuất MP3/WAV'), findsOneWidget);
    expect(find.textContaining('Tạo video từ nội dung, giọng đọc, hình ảnh'), findsOneWidget);

    // Verify Recent Jobs section
    expect(find.textContaining('Tác vụ gần đây'), findsOneWidget);

    // Clean up and drain any pending timers
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });
}
