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
import 'package:nguyendu_tool/features/pdf_converter/application/pdf_converter_notifier.dart';
import 'package:nguyendu_tool/features/pdf_converter/application/pdf_converter_service.dart';
import '../support/mock_ocr_engine.dart';
import '../support/test_pdf_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late WorkspaceManager workspaceManager;
  late AppDatabase database;
  late SettingsRepository settingsRepository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('router_test_ws_');
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

  testWidgets('Navigation smoke test: Dashboard -> PDF Converter -> Settings', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final testRouter = createAppRouter();

    final testService = PdfConverterService(
      workspaceManager: workspaceManager,
      database: database,
      ocrEngine: MockOcrEngine(),
      renderer: TestPdfRenderer(tempDir: workspaceManager.tempDir),
    );

    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceManagerProvider.overrideWithValue(workspaceManager),
          databaseProvider.overrideWithValue(database),
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          providerRegistryProvider.overrideWithValue(ProviderRegistry()),
          secureStorageProvider.overrideWithValue(SecureStorageService()),
          pdfConverterServiceProvider.overrideWithValue(testService),
          appRouterProvider.overrideWithValue(testRouter),
        ],
        child: const ISchoolToolsApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Tap on PDF Card on Dashboard
    final pdfCard = find.widgetWithText(ModuleCard, 'Chuyển đổi PDF & Tài liệu');
    expect(pdfCard, findsOneWidget);
    await tester.ensureVisible(pdfCard);
    await tester.pumpAndSettle();
    await tester.tap(pdfCard);
    await tester.pumpAndSettle();

    // Verify PDF Converter screen is loaded
    expect(find.text('Chuyển đổi PDF sang Word / Excel'), findsOneWidget);
    expect(find.text('Chọn hoặc kéo thả các tệp PDF vào đây'), findsOneWidget);

    // Tap on Settings in sidebar
    final settingsNav = find.text('Cài đặt');
    expect(settingsNav, findsOneWidget);
    await tester.ensureVisible(settingsNav);
    await tester.pumpAndSettle();
    await tester.tap(settingsNav);
    await tester.pumpAndSettle();

    // Verify Settings screen is loaded
    expect(find.text('Cấu hình chung (General)'), findsOneWidget);
    expect(find.text('Ngôn ngữ giao diện (Language)'), findsOneWidget);

    // Clean up and drain any pending timers
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });
}
