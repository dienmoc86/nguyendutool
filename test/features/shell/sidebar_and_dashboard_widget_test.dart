import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/app/router/routes.dart';
import 'package:nguyendu_tool/core/commands/command_registry.dart';
import 'package:nguyendu_tool/core/modules/module_registry.dart';
import 'package:nguyendu_tool/features/dashboard/presentation/widgets/module_card.dart';
import 'package:nguyendu_tool/features/shell/presentation/command_palette_dialog.dart';
import 'package:nguyendu_tool/features/shell/presentation/sidebar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 6A UI & Widget Tests', () {
    setUp(() {
      CommandRegistry.instance.initializeDefaults();
    });

    testWidgets('AppSidebar renders categories and handles category collapse toggle',
        (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AppSidebar(
                isCollapsed: false,
                currentRoute: AppRoutes.dashboard,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Category Headings
      expect(find.text('GIẢNG DẠY'), findsOneWidget);
      expect(find.text('TÀI LIỆU'), findsOneWidget);
      expect(find.text('MEDIA'), findsOneWidget);
      expect(find.text('HỆ THỐNG'), findsOneWidget);

      // Check Brand elements
      expect(find.text('NguyenDu Tool'), findsOneWidget);
      expect(find.text('Phần mềm hỗ trợ giáo viên'), findsOneWidget);
      expect(find.text('Tác giả: Mr. Điện'), findsOneWidget);

      // Check initial modules in categories
      expect(find.text('Trợ lý giảng dạy'), findsOneWidget);
      expect(find.text('Chuyển đổi PDF'), findsOneWidget);

      // Tap on 'GIẢNG DẠY' to collapse it
      await tester.tap(find.text('GIẢNG DẠY'));
      await tester.pumpAndSettle();

      // 'Trợ lý giảng dạy' should now be collapsed
      expect(find.text('Trợ lý giảng dạy'), findsNothing);

      // Tap 'GIẢNG DẠY' again to expand it
      await tester.tap(find.text('GIẢNG DẠY'));
      await tester.pumpAndSettle();

      expect(find.text('Trợ lý giảng dạy'), findsOneWidget);
    });

    testWidgets('CommandPaletteDialog filters commands and navigates on Enter',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => CommandPaletteDialog.show(context),
                  child: const Text('Mở Command Palette'),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open Command Palette
      await tester.tap(find.text('Mở Command Palette'));
      await tester.pumpAndSettle();

      // Dialog is visible
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Tìm tác vụ, công cụ, giáo án... (nhập từ khóa)'), findsOneWidget);

      // Type "giao an" to search
      await tester.enterText(find.byType(TextField), 'giao an');
      await tester.pumpAndSettle();

      // Should show Lesson Planner command
      expect(find.text('Mở Trợ lý Giáo án'), findsOneWidget);

      // Type unknown query
      await tester.enterText(find.byType(TextField), 'xyznonexistent123');
      await tester.pumpAndSettle();

      expect(find.text('Không tìm thấy kết quả phù hợp'), findsOneWidget);
    });

    testWidgets('ModuleCard handles launchable vs comingSoon state appropriately',
        (tester) async {
      bool stableClicked = false;
      bool comingSoonClicked = false;

      final stableModule = ModuleRegistry.instance.getModule('pdf_converter')!;
      final comingSoonModule = ModuleRegistry.instance.getModule('presentation_studio')!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ModuleCard.fromDefinition(
                  module: stableModule,
                  onTap: () => stableClicked = true,
                ),
                ModuleCard.fromDefinition(
                  module: comingSoonModule,
                  onTap: () => comingSoonClicked = true,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(stableModule.name), findsOneWidget);
      expect(find.text(comingSoonModule.name), findsOneWidget);

      // Stable module has 'Khả dụng' and launch action
      expect(find.text('Khả dụng'), findsOneWidget);
      expect(find.text('Khởi chạy phân hệ'), findsOneWidget);

      // Coming soon module has 'Sắp ra mắt' badge and roadmap label
      expect(find.text('Sắp ra mắt'), findsOneWidget);
      expect(find.text('Kế hoạch mở rộng theo lộ trình'), findsOneWidget);

      // Tap stable module
      await tester.tap(find.text(stableModule.name));
      await tester.pumpAndSettle();
      expect(stableClicked, isTrue);

      // Tap coming soon module (should not trigger callback)
      await tester.tap(find.text(comingSoonModule.name));
      await tester.pumpAndSettle();
      expect(comingSoonClicked, isFalse);
    });
  });
}
