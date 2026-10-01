import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/modules/module_category.dart';
import 'package:nguyendu_tool/core/modules/module_registry.dart';
import 'package:nguyendu_tool/core/modules/module_status.dart';

void main() {
  group('ModuleRegistry Architecture Tests (Phase 6A)', () {
    late ModuleRegistry registry;

    setUp(() {
      registry = ModuleRegistry.instance;
    });

    test('Registry validation passes with zero errors', () {
      expect(() => registry.validateRegistry(), returnsNormally);
    });

    test('All stable modules have unique IDs, valid routes, and keywords', () {
      final allModules = registry.getAllModules();
      expect(allModules, isNotEmpty);

      final ids = <String>{};
      for (final module in allModules) {
        expect(ids.contains(module.id), isFalse, reason: 'Duplicate ID: ${module.id}');
        ids.add(module.id);

        if (module.status == ModuleStatus.stable || module.status == ModuleStatus.beta) {
          expect(module.route, isNotNull, reason: '${module.id} must have a route');
          expect(module.route!.startsWith('/'), isTrue, reason: '${module.id} route must start with /');
          expect(module.keywords, isNotEmpty, reason: '${module.id} must have search keywords');
          expect(module.isLaunchable, isTrue);
        }
      }
    });

    test('Core functional modules are registered and present', () {
      final expectedIds = [
        'dashboard',
        'lesson_planner',
        'pdf_converter',
        'scanner',
        'text_to_speech',
        'video_studio',
        'file_library',
        'settings',
      ];

      for (final id in expectedIds) {
        final module = registry.getModule(id);
        expect(module, isNotNull, reason: 'Module $id must be registered');
        expect(module!.id, equals(id));
      }
    });

    test('Lesson Planner is recognized as a first-class teaching module', () {
      final lp = registry.getModule('lesson_planner');
      expect(lp, isNotNull);
      expect(lp!.category, equals(ModuleCategory.teaching));
      expect(lp.status, equals(ModuleStatus.beta));
      expect(lp.route, equals('/lesson-planner'));
      expect(lp.keywords, contains('5512'));
    });

    test('Assessment Studio is recognized as an active teaching module in Phase 7', () {
      final asModule = registry.getModule('assessment_studio');
      expect(asModule, isNotNull);
      expect(asModule!.category, equals(ModuleCategory.teaching));
      expect(asModule.status, equals(ModuleStatus.beta));
      expect(asModule.route, equals('/assessment-studio'));
      expect(asModule.isLaunchable, isTrue);
      expect(asModule.keywords, contains('đề thi'));
    });

    test('Future modules are marked comingSoon and not launchable', () {
      final comingSoon = registry.getComingSoonModules();
      expect(comingSoon, isNotEmpty);

      final comingSoonIds = [
        'presentation_studio',
        'pdf_toolbox',
        'subtitle_studio',
        'ai_assistant',
        'mail_merge',
        'image_tools',
        'qr_tools',
      ];

      for (final id in comingSoonIds) {
        final module = registry.getModule(id);
        expect(module, isNotNull, reason: 'Future module $id must be in roadmap');
        expect(module!.status, equals(ModuleStatus.comingSoon));
        expect(module.isLaunchable, isFalse);
      }
    });

    test('Speech to Text is recognized as an active stable media module', () {
      final stt = registry.getModule('speech_to_text');
      expect(stt, isNotNull);
      expect(stt!.category, equals(ModuleCategory.media));
      expect(stt.status, equals(ModuleStatus.stable));
      expect(stt.route, equals('/speech-to-text'));
      expect(stt.isLaunchable, isTrue);
      expect(stt.keywords, contains('speech to text'));
    });

    test('Grouping by category works as expected', () {
      final grouped = registry.getModulesGroupedByCategory(includeHidden: true);
      expect(grouped.containsKey(ModuleCategory.home), isTrue);
      expect(grouped.containsKey(ModuleCategory.teaching), isTrue);
      expect(grouped.containsKey(ModuleCategory.documents), isTrue);
      expect(grouped.containsKey(ModuleCategory.media), isTrue);
      expect(grouped.containsKey(ModuleCategory.system), isTrue);
    });
  });
}
