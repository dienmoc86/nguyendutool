import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/file_library/application/file_library_notifier.dart';
import '../../features/file_library/domain/file_entry.dart';
import '../../features/file_library/infrastructure/file_repository.dart';
import '../database/app_database.dart';
import '../filesystem/workspace_manager.dart';
import '../jobs/application/job_service.dart';
import '../jobs/data/job_repository.dart';
import '../jobs/domain/job_model.dart';
import '../settings/application/settings_notifier.dart';
import '../settings/data/settings_repository.dart';
import '../settings/domain/app_settings_model.dart';
import '../security/windows_dpapi_secure_storage.dart';
import 'provider_registry.dart';
import 'secure_storage_abstraction.dart';

/// Workspace manager dependency provider.
final workspaceManagerProvider = Provider<WorkspaceManager>((ref) {
  throw UnimplementedError('workspaceManagerProvider must be initialized in bootstrap');
});

/// SQLite database dependency provider.
final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('databaseProvider must be initialized in bootstrap');
});

/// Settings repository provider.
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SettingsRepository(db);
});

/// Reactive settings state notifier provider.
final settingsNotifierProvider = StateNotifierProvider<SettingsNotifier, AppSettingsModel>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return SettingsNotifier(repo);
});

/// Job repository provider.
final jobRepositoryProvider = Provider<JobRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return JobRepository(db);
});

/// Reactive job state notifier provider.
final jobNotifierProvider = StateNotifierProvider<JobNotifier, AsyncValue<List<JobModel>>>((ref) {
  final repo = ref.watch(jobRepositoryProvider);
  return JobNotifier(repo);
});

/// Central provider registry provider.
final providerRegistryProvider = Provider<ProviderRegistry>((ref) {
  return ProviderRegistry();
});

/// Secure storage abstraction provider (Windows DPAPI).
final secureStorageProvider = Provider<ISecureStorage>((ref) {
  return WindowsDpapiSecureStorage();
});

/// File library repository provider.
final fileRepositoryProvider = Provider<FileRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return FileRepository(db);
});

/// Reactive file library notifier provider.
final fileLibraryNotifierProvider = StateNotifierProvider<FileLibraryNotifier, AsyncValue<List<FileEntry>>>((ref) {
  final repo = ref.watch(fileRepositoryProvider);
  final ws = ref.watch(workspaceManagerProvider);
  return FileLibraryNotifier(repo, ws);
});
