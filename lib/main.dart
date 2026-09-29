import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'app/bootstrap/bootstrap.dart';
import 'core/errors/app_exceptions.dart';
import 'core/errors/crash_handler.dart';
import 'core/providers/app_providers.dart';
import 'core/settings/application/settings_notifier.dart';
import 'core/testing/release_self_test_runner.dart';
import 'features/shell/presentation/database_recovery_screen.dart';
import 'features/shell/presentation/diagnostic_screen.dart';

void main(List<String> args) async {
  // Support internal CLI Release Self-Test mode (Requirements 34 & 35)
  if (args.contains('--self-test')) {
    WidgetsFlutterBinding.ensureInitialized();
    final exitCode = await ReleaseSelfTestRunner.runCli();
    exit(exitCode);
  }

  CrashHandler.runGuarded(() {
    runStartup();
  });
}

void runStartup() async {
  try {
    final bootstrap = await AppBootstrap.run();

    runApp(
      ProviderScope(
        overrides: [
          workspaceManagerProvider.overrideWithValue(bootstrap.workspaceManager),
          databaseProvider.overrideWithValue(bootstrap.database),
          settingsRepositoryProvider.overrideWithValue(bootstrap.settingsRepository),
          settingsNotifierProvider.overrideWith(
            (ref) => SettingsNotifier(bootstrap.settingsRepository, bootstrap.initialSettings),
          ),
          providerRegistryProvider.overrideWithValue(bootstrap.providerRegistry),
          secureStorageProvider.overrideWithValue(bootstrap.secureStorage),
        ],
        child: const NguyenDuApp(),
      ),
    );
  } catch (error, stackTrace) {
    // Check if error is database corruption -> present disaster recovery screen (Requirement 28)
    if (error is DatabaseCorruptBootstrapException) {
      runApp(
        DatabaseRecoveryScreen(
          databasePath: error.databasePath,
          errorMessage: error.technicalDetails ?? error.message,
          onRetry: () => runStartup(),
          onRestored: () => runStartup(),
        ),
      );
      return;
    }

    if (error is BootstrapException && error.technicalDetails?.contains('DatabaseCorruptBootstrapException') == true) {
      runApp(
        DatabaseRecoveryScreen(
          databasePath: 'nguyendu_tool.db',
          errorMessage: error.message,
          onRetry: () => runStartup(),
          onRestored: () => runStartup(),
        ),
      );
      return;
    }

    runApp(
      StartupDiagnosticScreen(
        error: error,
        stackTrace: stackTrace,
        onRetry: () => runStartup(),
      ),
    );
  }
}
