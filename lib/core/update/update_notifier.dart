import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logging/app_logger.dart';
import '../product/product_info.dart';
import 'update_service.dart';

enum UpdateStatus {
  initial,
  checking,
  available,
  upToDate,
  downloading,
  readyToInstall,
  error,
}

class UpdateState {
  final UpdateStatus status;
  final UpdateManifest? manifest;
  final double downloadProgress;
  final int receivedBytes;
  final int totalBytes;
  final String? errorMessage;
  final bool userDismissed;

  const UpdateState({
    this.status = UpdateStatus.initial,
    this.manifest,
    this.downloadProgress = 0.0,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.errorMessage,
    this.userDismissed = false,
  });

  bool get isAvailable => status == UpdateStatus.available && manifest != null;
  bool get isDownloading => status == UpdateStatus.downloading;

  UpdateState copyWith({
    UpdateStatus? status,
    UpdateManifest? manifest,
    double? downloadProgress,
    int? receivedBytes,
    int? totalBytes,
    String? errorMessage,
    bool? userDismissed,
  }) {
    return UpdateState(
      status: status ?? this.status,
      manifest: manifest ?? this.manifest,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      errorMessage: errorMessage ?? this.errorMessage,
      userDismissed: userDismissed ?? this.userDismissed,
    );
  }
}

class UpdateNotifier extends StateNotifier<UpdateState> {
  final UpdateService _updateService;
  final String repository;

  UpdateNotifier(this._updateService, {this.repository = UpdateService.defaultGitHubRepo})
      : super(const UpdateState());

  /// Checks for available updates from GitHub, raw manifest, or custom mirror.
  /// If [silent] is true, only updates state if a new version is found, ignoring non-critical network errors.
  /// If [autoDownload] is true, automatically begins download & installation upon finding a newer version.
  Future<void> checkForUpdates({
    bool silent = false,
    String? targetRepository,
    String? customManifestUrl,
    bool autoDownload = false,
  }) async {
    if (state.isDownloading) return;

    state = state.copyWith(
      status: UpdateStatus.checking,
      errorMessage: null,
      userDismissed: false,
    );

    try {
      final repoToUse = targetRepository ?? repository;
      final result = await _updateService.checkForGitHubRelease(
        repository: repoToUse,
        customManifestUrl: customManifestUrl,
      );

      if (result.isUpdateAvailable && result.manifest != null) {
        state = state.copyWith(
          status: UpdateStatus.available,
          manifest: result.manifest,
          downloadProgress: 0.0,
        );
        AppLogger.info('Found new update on GitHub: v${result.manifest!.version}');

        if (autoDownload) {
          AppLogger.info('Auto-download enabled. Starting update download for v${result.manifest!.version}...');
          downloadAndInstall();
        }
      } else {
        if (result.errorMessage != null && !silent) {
          state = state.copyWith(
            status: UpdateStatus.error,
            errorMessage: result.errorMessage,
          );
        } else {
          state = state.copyWith(
            status: UpdateStatus.upToDate,
            manifest: result.manifest,
          );
        }
      }
    } catch (e) {
      if (!silent) {
        state = state.copyWith(
          status: UpdateStatus.error,
          errorMessage: 'Lỗi kiểm tra cập nhật: $e',
        );
      } else {
        state = state.copyWith(status: UpdateStatus.initial);
      }
    }
  }

  /// Downloads the update package with progress feedback, verifies SHA256,
  /// and silently triggers Inno Setup and relaunch.
  Future<void> downloadAndInstall() async {
    final manifest = state.manifest;
    if (manifest == null) return;

    state = state.copyWith(
      status: UpdateStatus.downloading,
      downloadProgress: 0.0,
      receivedBytes: 0,
      totalBytes: 0,
      errorMessage: null,
    );

    try {
      final downloadResult = await _updateService.downloadAndVerifyInstaller(
        manifest,
        onProgress: (progress, received, total) {
          state = state.copyWith(
            downloadProgress: progress,
            receivedBytes: received,
            totalBytes: total,
          );
        },
      );

      if (!downloadResult.isSuccess || downloadResult.downloadedInstaller == null) {
        state = state.copyWith(
          status: UpdateStatus.error,
          errorMessage: downloadResult.errorMessage ?? 'Không thể tải tệp cài đặt.',
        );
        return;
      }

      state = state.copyWith(
        status: UpdateStatus.readyToInstall,
        downloadProgress: 1.0,
      );

      // Execute update & relaunch
      await _updateService.executeSilentUpdateAndRelaunch(
        installerFile: downloadResult.downloadedInstaller!,
      );
    } catch (e, st) {
      AppLogger.error('Update install error: $e', e, st);
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: 'Lỗi khi cài đặt bản cập nhật: $e',
      );
    }
  }

  void dismiss() {
    state = state.copyWith(userDismissed: true);
  }
}

/// Provider for UpdateService
final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService(currentVersion: ProductInfo.version, currentBuild: ProductInfo.build);
});

/// Reactive StateNotifierProvider for Auto-Update
final updateNotifierProvider = StateNotifierProvider<UpdateNotifier, UpdateState>((ref) {
  final service = ref.watch(updateServiceProvider);
  return UpdateNotifier(service);
});
