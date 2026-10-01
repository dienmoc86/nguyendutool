import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/commands/app_command.dart';
import 'package:nguyendu_tool/core/commands/command_registry.dart';

void main() {
  group('CommandRegistry Tests (Phase 6A)', () {
    final registry = CommandRegistry.instance;

    setUp(() {
      registry.clear();
      registry.initializeDefaults();
    });

    test('Default commands are registered and non-empty', () {
      final commands = registry.allCommands;
      expect(commands.isNotEmpty, isTrue);
      expect(commands.length, greaterThanOrEqualTo(10));
    });

    test('All registered commands pass validation (unique IDs, non-empty fields)', () {
      final errors = registry.validate();
      expect(errors, isEmpty, reason: 'Validation errors found: ${errors.join(', ')}');

      final ids = registry.allCommands.map((c) => c.id).toList();
      final uniqueIds = ids.toSet();
      expect(ids.length, equals(uniqueIds.length), reason: 'Duplicate command IDs found');
    });

    test('Search filters correctly by title and keywords', () {
      // Search PDF
      final pdfResults = registry.search('pdf');
      expect(pdfResults.any((c) => c.id == 'nav.pdf_converter'), isTrue);

      // Search Scanner
      final scanResults = registry.search('scan');
      expect(scanResults.any((c) => c.id == 'nav.scanner'), isTrue);

      // Search Giáo án (Vietnamese keyword)
      final lessonResults = registry.search('giao an');
      expect(lessonResults.any((c) => c.id == 'nav.lesson_planner'), isTrue);

      // Search TTS
      final ttsResults = registry.search('giong noi');
      expect(ttsResults.any((c) => c.id == 'nav.tts'), isTrue);
    });

    testWidgets('Custom command registration and execution', (tester) async {
      bool executed = false;
      final customCmd = AppCommand(
        id: 'custom.test',
        title: 'Lệnh thử nghiệm',
        category: 'Thử nghiệm',
        icon: Icons.bug_report,
        keywords: ['test', 'thu nghiem'],
        execute: (context) async {
          executed = true;
        },
      );

      registry.register(customCmd);
      expect(registry.allCommands.any((c) => c.id == 'custom.test'), isTrue);

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => customCmd.execute(context),
              child: const Text('Execute'),
            );
          },
        ),
      ));

      await tester.tap(find.text('Execute'));
      await tester.pump();
      expect(executed, isTrue);
    });

    test('register throws ArgumentError on duplicate command ID (Strict Policy)', () {
      final duplicateCmd = AppCommand(
        id: 'nav.dashboard',
        title: 'Trùng ID',
        category: 'Thử nghiệm',
        icon: Icons.error,
        execute: (context) async {},
      );

      expect(() => registry.register(duplicateCmd), throwsArgumentError);
    });

    test('registerOrReplace overwrites existing command without throwing', () {
      final updatedCmd = AppCommand(
        id: 'nav.dashboard',
        title: 'Trang chủ mới (Updated)',
        category: 'Điều hướng',
        icon: Icons.home,
        execute: (context) async {},
      );

      expect(() => registry.registerOrReplace(updatedCmd), returnsNormally);
      final fetched = registry.allCommands.firstWhere((c) => c.id == 'nav.dashboard');
      expect(fetched.title, equals('Trang chủ mới (Updated)'));
    });

    test('Teaching Suite commands are registered in defaults', () {
      expect(registry.allCommands.any((c) => c.id == 'action.new_teaching_project'), isTrue);
      expect(registry.allCommands.any((c) => c.id == 'action.generate_lesson_plan'), isTrue);
      expect(registry.allCommands.any((c) => c.id == 'action.create_worksheet'), isTrue);
      expect(registry.allCommands.any((c) => c.id == 'action.create_questions'), isTrue);
      expect(registry.allCommands.any((c) => c.id == 'action.create_rubric'), isTrue);
    });
  });
}
