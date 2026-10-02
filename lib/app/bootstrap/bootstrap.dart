import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../core/database/app_database.dart';
import '../../core/database/database_backup_service.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/errors/crash_handler.dart';
import '../../core/filesystem/workspace_manager.dart';
import '../../core/logging/app_logger.dart';
import '../../core/platform/single_instance_guard.dart';
import '../../core/providers/provider_registry.dart';
import '../../core/providers/secure_storage_abstraction.dart';
import '../../core/recovery/crash_recovery_service.dart';
import '../../core/security/windows_dpapi_secure_storage.dart';
import '../../core/settings/data/settings_repository.dart';
import '../../core/settings/domain/app_settings_model.dart';

/// Container holding initialized platform singletons passed to Riverpod.
class AppBootstrapResult {
  final WorkspaceManager workspaceManager;
  final AppDatabase database;
  final SettingsRepository settingsRepository;
  final AppSettingsModel initialSettings;
  final ProviderRegistry providerRegistry;
  final ISecureStorage secureStorage;

  AppBootstrapResult({
    required this.workspaceManager,
    required this.database,
    required this.settingsRepository,
    required this.initialSettings,
    required this.providerRegistry,
    required this.secureStorage,
  });
}

/// Orchestrates the startup sequence of NguyenDu Tool.
class AppBootstrap {
  static Future<AppBootstrapResult> run({bool enforceSingleInstance = true}) async {
    String currentStep = 'init_bindings';

    try {
      // 1. Flutter Widgets Binding
      currentStep = 'widgets_binding';
      WidgetsFlutterBinding.ensureInitialized();

      // 2. Initialize Workspace Manager & Folders
      currentStep = 'workspace_init';
      final workspaceManager = WorkspaceManager();
      await workspaceManager.init();

      // 3. Centralized Logger & Crash Handler Initialization
      currentStep = 'logger_init';
      AppLogger.init(logDirectory: workspaceManager.logsDir);
      CrashHandler.init(logsDirectory: workspaceManager.logsDir);
      AppLogger.info('Starting NguyenDu Tool bootstrap sequence...');

      // 4. Single-Instance Guard (Requirements 24 & 25)
      if (enforceSingleInstance) {
        currentStep = 'single_instance_guard';
        final isExclusive = await SingleInstanceGuard.acquireLock(workspaceManager.rootPath);
        if (!isExclusive) {
          throw const SingleInstanceLockException(
            'Một phiên bản khác của NguyenDu Tool đang chạy trên máy tính này. '
            'Để bảo vệ an toàn toàn vẹn cơ sở dữ liệu, ứng dụng chỉ được phép chạy một tiến trình duy nhất.',
          );
        }
      }

      // 5. Initialize Local SQLite Database
      currentStep = 'database_init';
      final dbPath = p.join(workspaceManager.projectsDir.path, AppDatabase.databaseFileName);
      final database = AppDatabase(customPath: dbPath);
      try {
        await database.init();
      } catch (dbErr, dbSt) {
        AppLogger.error('Failed to initialize primary database at: $dbPath', dbErr, dbSt);
        throw DatabaseCorruptBootstrapException(
          'Không thể khởi động cơ sở dữ liệu SQLite do tệp bị hỏng hoặc cấu trúc không tương thích.',
          databasePath: dbPath,
          technicalDetails: dbErr.toString(),
          stackTrace: dbSt,
        );
      }

      // 6. Automatic Database Rolling Backup (Section 34)
      currentStep = 'database_backup';
      try {
        final backupService = DatabaseBackupService(
          databaseFile: File(dbPath),
          backupsDirectory: Directory(p.join(workspaceManager.rootPath, 'backups')),
          activeDb: database.db,
        );
        await backupService.createBackup(reason: 'auto_startup');
      } catch (e) {
        AppLogger.warning('Database auto-backup notice (non-fatal): $e');
      }

      // 7. Safe Stale Temp Cleanup (Section 41)
      currentStep = 'temp_cleanup';
      try {
        final recoveryService = CrashRecoveryService(workspaceManager: workspaceManager);
        await recoveryService.cleanStaleTempFiles();
      } catch (e) {
        AppLogger.warning('Temp cleanup notice (non-fatal): $e');
      }

      // 8. Load Settings
      currentStep = 'settings_load';
      final settingsRepository = SettingsRepository(database);
      final initialSettings = await settingsRepository.loadSettings();

      // 9. Providers & Security Vault Initialization (Windows DPAPI)
      currentStep = 'providers_init';
      final providerRegistry = ProviderRegistry();
      final secureStorage = WindowsDpapiSecureStorage();
      try {
        await providerRegistry.loadSavedCredentials();
      } catch (e) {
        AppLogger.warning('Provider credentials load notice: $e');
      }

      AppLogger.info('Bootstrap sequence completed successfully.');

      return AppBootstrapResult(
        workspaceManager: workspaceManager,
        database: database,
        settingsRepository: settingsRepository,
        initialSettings: initialSettings,
        providerRegistry: providerRegistry,
        secureStorage: secureStorage,
      );
    } catch (e, st) {
      AppLogger.error('Bootstrap failed at step: $currentStep', e, st);
      throw BootstrapException(
        'Khởi tạo ứng dụng thất bại.',
        failedStep: currentStep,
        technicalDetails: e.toString(),
        stackTrace: st,
      );
    }
  }
}
