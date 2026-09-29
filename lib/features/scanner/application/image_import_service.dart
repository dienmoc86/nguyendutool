import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/logging/app_logger.dart';
import '../domain/models/document_quad.dart';
import '../domain/models/scan_options.dart';
import '../domain/models/scan_page.dart';
import '../infrastructure/cv_document_processor.dart';

/// Service responsible for importing local image files into a scanning session.
/// Enforces canonical orientation normalization, non-destructive storage, and automatic boundary detection.
class ImageImportService {
  static const Set<String> supportedExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.bmp',
    '.tiff',
    '.tif',
    '.webp',
  };

  /// Imports a list of image files into [ScanPage] objects for [sessionId].
  Future<List<ScanPage>> importImages({
    required List<String> filePaths,
    required String sessionId,
    int startingIndex = 0,
    void Function(double progress, String status)? onProgress,
  }) async {
    final validPaths = filePaths.where((f) {
      final ext = p.extension(f).toLowerCase();
      return supportedExtensions.contains(ext) && File(f).existsSync();
    }).toList();

    if (validPaths.isEmpty) {
      throw const ScanImportException('Không có tệp ảnh hợp lệ nào được chọn để nhập.');
    }

    final tempDir = Directory(p.join(Directory.current.path, 'temp', 'scans', sessionId));
    if (!tempDir.existsSync()) {
      tempDir.createSync(recursive: true);
    }

    final pages = <ScanPage>[];
    for (int i = 0; i < validPaths.length; i++) {
      final sourcePath = validPaths[i];
      final currentIdx = startingIndex + i;
      onProgress?.call((i + 1) / validPaths.length, 'Đang xử lý ảnh ${i + 1}/${validPaths.length}...');

      try {
        final bytes = await File(sourcePath).readAsBytes();
        img.Image? decoded = img.decodeImage(bytes);
        if (decoded == null) {
          AppLogger.warning('Cannot decode image file: $sourcePath');
          continue;
        }

        // Canonical Orientation Normalization:
        // Bake EXIF orientation directly so rotation is 0° upright
        decoded = img.bakeOrientation(decoded);

        // Save original normalized image into session directory
        final pageId = const Uuid().v4();
        final origFileName = 'page_${currentIdx + 1}_orig.png';
        final origPath = p.join(tempDir.path, origFileName);
        await File(origPath).writeAsBytes(img.encodePng(decoded));

        // Auto document boundary detection
        final detectedQuad = CvDocumentProcessor.detectDocumentQuad(decoded);

        // Quality and blank page assessment
        final quality = CvDocumentProcessor.assessQuality(decoded);
        final isBlank = CvDocumentProcessor.detectBlankPage(decoded);
        final dHash = CvDocumentProcessor.calculateDHash(decoded);

        // Generate processed image (perspective warp if plausible, else enhance)
        img.Image processedImg;
        if (detectedQuad.isPlausible(decoded.width.toDouble(), decoded.height.toDouble()) &&
            detectedQuad != DocumentQuad.fullImage(decoded.width.toDouble(), decoded.height.toDouble())) {
          processedImg = CvDocumentProcessor.warpPerspective(decoded, detectedQuad);
        } else {
          processedImg = decoded;
        }

        processedImg = CvDocumentProcessor.enhanceImage(
          processedImg,
          const ScanProcessingOptions(preset: EnhancementPreset.document),
        );

        final procFileName = 'page_${currentIdx + 1}_proc.png';
        final procPath = p.join(tempDir.path, procFileName);
        await File(procPath).writeAsBytes(img.encodePng(processedImg));

        pages.add(
          ScanPage(
            id: pageId,
            sessionId: sessionId,
            pageIndex: currentIdx,
            originalPath: origPath,
            processedPath: procPath,
            rotation: 0, // Canonical: normalized to 0
            detectedQuad: detectedQuad,
            quality: quality,
            isLikelyBlank: isBlank,
            perceptualHash: dHash,
            createdAt: DateTime.now(),
          ),
        );
      } catch (e, st) {
        AppLogger.error('Failed to import image: $sourcePath', e, st);
      }
    }

    return pages;
  }
}
