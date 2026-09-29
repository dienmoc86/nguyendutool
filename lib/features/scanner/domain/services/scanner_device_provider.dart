import '../models/scan_profile.dart';
import '../models/scanner_device.dart';

/// Contract for discovering and acquiring images from scanner hardware.
abstract class ScannerDeviceProvider {
  /// Enumerate installed scanner devices. Returns empty list if no scanner found.
  Future<List<ScannerDevice>> getAvailableScanners();

  /// Query detailed hardware capabilities for a specific device.
  Future<ScannerCapability> queryCapabilities(String deviceId);

  /// Acquired page image saved to temporary file path.
  Future<String> acquirePage({
    required String deviceId,
    required ScanProfile profile,
    void Function(double progress)? onProgress,
  });

  /// Cancels any in-progress acquisition.
  Future<void> cancelAcquisition();
}
