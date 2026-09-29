import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import '../../../core/logging/app_logger.dart';

/// Result of image preprocessing prior to OCR.
class PreprocessingResult {
  final String processedImagePath;
  final double estimatedSkewAngle;
  final bool appliedDeskew;
  final bool appliedEnhance;
  final int durationMs;

  const PreprocessingResult({
    required this.processedImagePath,
    this.estimatedSkewAngle = 0.0,
    this.appliedDeskew = false,
    this.appliedEnhance = false,
    this.durationMs = 0,
  });
}

/// Preprocesses page images for optimal OCR accuracy (grayscale, contrast, binarization, deskew, rotation).
/// Fully connected to the production OCR conversion pipeline.
class ImagePreprocessor {
  /// Processes an image file on disk according to configuration and writes the enhanced raster image.
  static Future<PreprocessingResult> processImageFile({
    required String inputPath,
    required String outputDir,
    bool autoDeskew = true,
    bool autoEnhance = true,
    int rotationDegrees = 0,
  }) async {
    final stopwatch = Stopwatch()..start();
    final inputFile = File(inputPath);
    if (!inputFile.existsSync()) {
      return PreprocessingResult(processedImagePath: inputPath);
    }

    try {
      final bytes = await inputFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image == null) {
        return PreprocessingResult(processedImagePath: inputPath);
      }

      bool appliedEnhance = false;
      bool appliedDeskew = false;
      double skewAngle = 0.0;

      // 1. Explicit rotation correction if needed
      if (rotationDegrees == 90) {
        image = img.copyRotate(image, angle: 90);
      } else if (rotationDegrees == 180) {
        image = img.copyRotate(image, angle: 180);
      } else if (rotationDegrees == 270) {
        image = img.copyRotate(image, angle: 270);
      }

      // 2. Grayscale & Contrast / Brightness normalization
      if (autoEnhance) {
        image = img.grayscale(image);
        image = img.adjustColor(image, contrast: 1.15, brightness: 1.05);
        appliedEnhance = true;
      }

      // 3. Deskew estimation and correction
      if (autoDeskew) {
        skewAngle = estimateImageSkew(image);
        if (skewAngle.abs() >= 0.5 && skewAngle.abs() <= 8.0) {
          image = img.copyRotate(image, angle: -skewAngle);
          appliedDeskew = true;
        }
      }

      final outDirObj = Directory(outputDir);
      if (!outDirObj.existsSync()) {
        outDirObj.createSync(recursive: true);
      }

      final outFilename = '${p.basenameWithoutExtension(inputPath)}_preprocessed.png';
      final outPath = p.join(outputDir, outFilename);
      final encodedPng = img.encodePng(image);
      await File(outPath).writeAsBytes(encodedPng);

      stopwatch.stop();
      return PreprocessingResult(
        processedImagePath: outPath,
        estimatedSkewAngle: skewAngle,
        appliedDeskew: appliedDeskew,
        appliedEnhance: appliedEnhance,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e, st) {
      AppLogger.warning('Image preprocessing exception: $e. Falling back to original image.', e, st);
      stopwatch.stop();
      return PreprocessingResult(
        processedImagePath: inputPath,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  /// Estimates skew angle from an [img.Image] using projection variance analysis.
  static double estimateImageSkew(img.Image image) {
    final w = image.width;
    final h = image.height;
    if (w <= 10 || h <= 10) return 0.0;

    // Convert sample to grayscale luminance buffer
    final int stepX = math.max(1, w ~/ 200).toInt();
    final int stepY = math.max(1, h ~/ 200).toInt();
    final sampledW = w ~/ stepX;
    final sampledH = h ~/ stepY;

    final lumBuffer = Uint8List(sampledW * sampledH);
    for (int sy = 0; sy < sampledH; sy++) {
      for (int sx = 0; sx < sampledW; sx++) {
        final pixel = image.getPixel(sx * stepX, sy * stepY);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        final lum = (0.299 * r + 0.587 * g + 0.114 * b).round();
        lumBuffer[sy * sampledW + sx] = lum < 128 ? 0 : 255;
      }
    }

    final buffer = ImageBuffer(width: sampledW, height: sampledH, data: lumBuffer);
    return estimateSkewAngle(buffer);
  }

  /// Simple 8-bit grayscale image representation for processing.
  static ImageBuffer toGrayscale(int width, int height, Uint8List rgbaBytes) {
    final grayBytes = Uint8List(width * height);
    for (int i = 0, j = 0; i < rgbaBytes.length; i += 4, j++) {
      final r = rgbaBytes[i];
      final g = rgbaBytes[i + 1];
      final b = rgbaBytes[i + 2];
      grayBytes[j] = (0.299 * r + 0.587 * g + 0.114 * b).round().clamp(0, 255);
    }
    return ImageBuffer(width: width, height: height, data: grayBytes);
  }

  /// Calculates Otsu's optimal binarization threshold.
  static int calculateOtsuThreshold(ImageBuffer gray) {
    final histogram = List<int>.filled(256, 0);
    for (final pixel in gray.data) {
      histogram[pixel]++;
    }

    final total = gray.data.length;
    double sum = 0;
    for (int t = 0; t < 256; t++) {
      sum += t * histogram[t];
    }

    double sumB = 0;
    int wB = 0;
    double varMax = 0;
    int threshold = 128;

    for (int t = 0; t < 256; t++) {
      wB += histogram[t];
      if (wB == 0) continue;
      final wF = total - wB;
      if (wF == 0) break;

      sumB += t * histogram[t];
      final mB = sumB / wB;
      final mF = (sum - sumB) / wF;

      final varBetween = wB.toDouble() * wF.toDouble() * (mB - mF) * (mB - mF);
      if (varBetween > varMax) {
        varMax = varBetween;
        threshold = t;
      }
    }
    return threshold;
  }

  /// Binarizes the grayscale image using threshold.
  static ImageBuffer binarize(ImageBuffer gray, int threshold) {
    final binData = Uint8List(gray.data.length);
    for (int i = 0; i < gray.data.length; i++) {
      binData[i] = gray.data[i] < threshold ? 0 : 255;
    }
    return ImageBuffer(width: gray.width, height: gray.height, data: binData);
  }

  /// Estimates document skew angle using projection profile analysis.
  static double estimateSkewAngle(ImageBuffer binary) {
    double bestVariance = 0;
    double bestAngle = 0.0;

    for (double angle = -4.0; angle <= 4.0; angle += 0.5) {
      final variance = _computeProjectionVariance(binary, angle);
      if (variance > bestVariance) {
        bestVariance = variance;
        bestAngle = angle;
      }
    }

    return bestAngle;
  }

  static double _computeProjectionVariance(ImageBuffer binary, double angle) {
    final rad = angle * math.pi / 180.0;
    final sinA = math.sin(rad);
    final cosA = math.cos(rad);

    final h = binary.height;
    final w = binary.width;
    final projections = List<int>.filled(h, 0);

    final step = math.max(1, h ~/ 200);
    for (int y = 0; y < h; y += step) {
      for (int x = 0; x < w; x += step) {
        if (binary.getPixel(x, y) == 0) {
          final rotatedY = (-x * sinA + y * cosA).round();
          if (rotatedY >= 0 && rotatedY < h) {
            projections[rotatedY]++;
          }
        }
      }
    }

    double sum = 0;
    for (final p in projections) {
      sum += p;
    }
    final mean = sum / h;
    double variance = 0;
    for (final p in projections) {
      variance += (p - mean) * (p - mean);
    }
    return variance;
  }

  /// Denoises single isolated black/white pixels (median filter 3x3).
  static ImageBuffer denoise(ImageBuffer binary) {
    final output = Uint8List(binary.data.length);
    final w = binary.width;
    final h = binary.height;

    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        int blackCount = 0;
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            if (binary.getPixel(x + dx, y + dy) == 0) blackCount++;
          }
        }
        output[y * w + x] = blackCount >= 5 ? 0 : 255;
      }
    }

    return ImageBuffer(width: w, height: h, data: output);
  }
}

/// In-memory representation of an 8-bit image buffer.
class ImageBuffer {
  final int width;
  final int height;
  final Uint8List data;

  const ImageBuffer({
    required this.width,
    required this.height,
    required this.data,
  });

  int getPixel(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) return 255;
    return data[y * width + x];
  }
}
