import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../pdf_converter/infrastructure/docx_generator.dart';
import '../../pdf_converter/infrastructure/vietnamese_ocr_engine.dart';
import '../domain/repositories/scan_session_repository.dart';
import '../domain/services/scanner_device_provider.dart';
import '../infrastructure/searchable_pdf_generator.dart';
import '../infrastructure/sqlite_scan_session_repository.dart';
import '../infrastructure/windows_camera_service.dart';
import '../infrastructure/windows_wia_scanner_provider.dart';
import 'image_import_service.dart';
import 'pdf_import_service.dart';
import 'scanner_notifier.dart';
import 'scanner_service.dart';
import 'scanner_state.dart';

final scannerDeviceProvider = Provider<ScannerDeviceProvider>((ref) {
  return WindowsWiaScannerProvider();
});

final windowsCameraServiceProvider = Provider<WindowsCameraService>((ref) {
  return WindowsCameraService();
});

final imageImportServiceProvider = Provider<ImageImportService>((ref) {
  return ImageImportService();
});

final pdfImportServiceProvider = Provider<PdfImportService>((ref) {
  return PdfImportService();
});

final scanSessionRepositoryProvider = Provider<ScanSessionRepository>((ref) {
  final appDb = ref.watch(databaseProvider);
  return SqliteScanSessionRepository(appDatabase: appDb);
});

final searchablePdfGeneratorProvider = Provider<SearchablePdfGenerator>((ref) {
  return SearchablePdfGenerator();
});

final scannerServiceProvider = Provider<ScannerService>((ref) {
  final deviceProvider = ref.watch(scannerDeviceProvider);
  final cameraService = ref.watch(windowsCameraServiceProvider);
  final imageImportService = ref.watch(imageImportServiceProvider);
  final pdfImportService = ref.watch(pdfImportServiceProvider);
  final sessionRepo = ref.watch(scanSessionRepositoryProvider);
  final jobRepo = ref.watch(jobRepositoryProvider);
  final fileRepo = ref.watch(fileRepositoryProvider);

  return ScannerService(
    deviceProvider: deviceProvider,
    cameraService: cameraService,
    imageImportService: imageImportService,
    pdfImportService: pdfImportService,
    ocrEngine: VietnameseOcrEngine(),
    pdfGenerator: ref.watch(searchablePdfGeneratorProvider),
    docxGenerator: DocxGenerator(),
    sessionRepository: sessionRepo,
    jobRepository: jobRepo,
    fileRepository: fileRepo,
  );
});

final scannerNotifierProvider = StateNotifierProvider<ScannerNotifier, ScannerState>((ref) {
  final service = ref.watch(scannerServiceProvider);
  return ScannerNotifier(service);
});
