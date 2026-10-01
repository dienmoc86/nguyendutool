import 'package:flutter/material.dart';
import '../../teaching_suite/presentation/teaching_suite_screen.dart';

export '../../teaching_suite/presentation/teaching_suite_screen.dart';

/// Legacy screen wrapper redirecting to TeachingSuiteScreen for backward compatibility.
class LessonPlannerScreen extends StatelessWidget {
  const LessonPlannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TeachingSuiteScreen();
  }
}
