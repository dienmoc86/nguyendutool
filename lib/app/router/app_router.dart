import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/file_library/presentation/file_library_screen.dart';
import '../../features/pdf_converter/presentation/pdf_converter_screen.dart';
import '../../features/scanner/presentation/scanner_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/system_diagnostics_screen.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../../features/shell/presentation/first_run_wizard_screen.dart';
import '../../features/text_to_speech/presentation/text_to_speech_screen.dart';
import '../../features/video_studio/presentation/video_studio_screen.dart';
import '../../core/providers/app_providers.dart';
import 'routes.dart';

/// Factory creating a fresh GoRouter instance.
GoRouter createAppRouter({String initialLocation = AppRoutes.dashboard}) {
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  final shellNavigatorKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.firstRun,
        builder: (context, state) => FirstRunWizardScreen(
          onCompleted: () => context.go(AppRoutes.dashboard),
        ),
      ),
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) {
          return AppShell(child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.pdfConverter,
            builder: (context, state) => const PdfConverterScreen(),
          ),
          GoRoute(
            path: AppRoutes.scanner,
            builder: (context, state) => const ScannerScreen(),
          ),
          GoRoute(
            path: AppRoutes.textToSpeech,
            builder: (context, state) => const TextToSpeechScreen(),
          ),
          GoRoute(
            path: AppRoutes.videoStudio,
            builder: (context, state) => const VideoStudioScreen(),
          ),
          GoRoute(
            path: AppRoutes.fileLibrary,
            builder: (context, state) => const FileLibraryScreen(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: AppRoutes.diagnostics,
            builder: (context, state) => const SystemDiagnosticsScreen(),
          ),
        ],
      ),
    ],
  );
}

/// Riverpod provider for GoRouter.
final appRouterProvider = Provider<GoRouter>((ref) {
  final settings = ref.watch(settingsNotifierProvider);
  final initial = settings.firstRunCompleted ? AppRoutes.dashboard : AppRoutes.firstRun;
  return createAppRouter(initialLocation: initial);
});

/// Backwards compatibility global reference.
final GoRouter appRouter = createAppRouter();
