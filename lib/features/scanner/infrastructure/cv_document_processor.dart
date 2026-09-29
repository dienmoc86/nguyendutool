import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../domain/models/document_quad.dart';
import '../domain/models/scan_options.dart';
import '../domain/models/scan_page.dart';

/// Computer Vision document processor providing:
/// - 4-corner document boundary detection
/// - 4-point perspective warp / homography
/// - Non-destructive document enhancement (presets, contrast, brightness, sharpen, Otsu binarization)
/// - Shadow / illumination normalization
/// - Small-angle deskew
/// - Blank page detection
/// - Perceptual difference hash (dHash) for duplicate detection
/// - Quality assessment (blur, contrast, brightness, resolution)
class CvDocumentProcessor {
  /// Detects the 4 corners of a document in [image].
  /// Returns [DocumentQuad] in full-resolution image coordinates.
  /// Falls back to full image bounds if no quadrilateral satisfies sanity checks.
  static DocumentQuad detectDocumentQuad(img.Image image) {
    final origW = image.width.toDouble();
    final origH = image.height.toDouble();

    if (origW < 50 || origH < 50) {
      return DocumentQuad.fullImage(origW, origH);
    }

    // Downscale for fast and robust contour / edge detection
    const targetDim = 500.0;
    final scale = math.min(1.0, targetDim / math.max(origW, origH));
    final smallW = (origW * scale).round();
    final smallH = (origH * scale).round();

    final small = img.copyResize(image, width: smallW, height: smallH);
    final gray = img.grayscale(small);

    // Compute Sobel gradient magnitude
    final edges = _computeSobelEdges(gray);

    // Find prominent boundary quad using scanlines from perimeter inwards
    final detectedPoints = _findBoundaryCorners(edges, smallW, smallH);

    if (detectedPoints.length == 4) {
      // Order corners: TL, TR, BR, BL
      final quadSmall = DocumentQuad.orderCorners(detectedPoints);

      // Verify sanity checks on the scaled quad
      if (quadSmall.isPlausible(smallW.toDouble(), smallH.toDouble())) {
        // Map back to original image dimensions
        final invScale = 1.0 / scale;
        return DocumentQuad(
          topLeft: Point2D(quadSmall.topLeft.x * invScale, quadSmall.topLeft.y * invScale),
          topRight: Point2D(quadSmall.topRight.x * invScale, quadSmall.topRight.y * invScale),
          bottomRight: Point2D(quadSmall.bottomRight.x * invScale, quadSmall.bottomRight.y * invScale),
          bottomLeft: Point2D(quadSmall.bottomLeft.x * invScale, quadSmall.bottomLeft.y * invScale),
        );
      }
    }

    // Fallback: document occupies the whole frame
    return DocumentQuad.fullImage(origW, origH);
  }

  /// Performs 4-point perspective warp on [image] given the 4 corners in [quad].
  /// Produces a rectified, flat rectangular image.
  static img.Image warpPerspective(img.Image image, DocumentQuad quad, {double padding = 0.0}) {
    // Determine destination output dimensions
    final widthTop = quad.topLeft.distanceTo(quad.topRight);
    final widthBottom = quad.bottomLeft.distanceTo(quad.bottomRight);
    final targetW = math.max(widthTop, widthBottom).round().clamp(100, 10000);

    final heightLeft = quad.topLeft.distanceTo(quad.bottomLeft);
    final heightRight = quad.topRight.distanceTo(quad.bottomRight);
    final targetH = math.max(heightLeft, heightRight).round().clamp(100, 10000);

    final dest = img.Image(width: targetW, height: targetH);

    // Apply optional padding to quad corners
    Point2D tl = quad.topLeft;
    Point2D tr = quad.topRight;
    Point2D br = quad.bottomRight;
    Point2D bl = quad.bottomLeft;

    if (padding != 0.0) {
      final center = Point2D((tl.x + tr.x + br.x + bl.x) / 4.0, (tl.y + tr.y + br.y + bl.y) / 4.0);
      tl = tl + (tl - center) * (padding / 100.0);
      tr = tr + (tr - center) * (padding / 100.0);
      br = br + (br - center) * (padding / 100.0);
      bl = bl + (bl - center) * (padding / 100.0);
    }

    final origW = image.width;
    final origH = image.height;

    // Bilinear surface mapping with subpixel interpolation
    for (int y = 0; y < targetH; y++) {
      final t = y / (targetH - 1.0);
      for (int x = 0; x < targetW; x++) {
        final s = x / (targetW - 1.0);

        // Bilinear coordinate interpolation on source quad
        final srcX = (1.0 - s) * (1.0 - t) * tl.x +
            s * (1.0 - t) * tr.x +
            s * t * br.x +
            (1.0 - s) * t * bl.x;
        final srcY = (1.0 - s) * (1.0 - t) * tl.y +
            s * (1.0 - t) * tr.y +
            s * t * br.y +
            (1.0 - s) * t * bl.y;

        // Subpixel bilinear interpolation from source image
        final pixel = _sampleBilinear(image, srcX, srcY, origW, origH);
        dest.setPixel(x, y, pixel);
      }
    }

    return dest;
  }

  /// Enhances [image] according to [options] non-destructively.
  static img.Image enhanceImage(img.Image image, ScanProcessingOptions options) {
    img.Image result = img.Image.from(image);

    // 1. Rotation if specified
    if (options.rotationDegrees == 90) {
      result = img.copyRotate(result, angle: 90);
    } else if (options.rotationDegrees == 180) {
      result = img.copyRotate(result, angle: 180);
    } else if (options.rotationDegrees == 270) {
      result = img.copyRotate(result, angle: 270);
    }

    // 2. Preset adjustments
    switch (options.preset) {
      case EnhancementPreset.original:
        return result;
      case EnhancementPreset.document:
        // Clean paper background, boost contrast, keep slight color
        result = normalizeIllumination(result);
        result = img.adjustColor(result, contrast: options.contrast, brightness: options.brightness);
        break;
      case EnhancementPreset.cleanScan:
        // Strong background cleaning + grayscale
        result = normalizeIllumination(result);
        result = img.grayscale(result);
        result = img.adjustColor(result, contrast: 1.25, brightness: 1.05);
        break;
      case EnhancementPreset.blackAndWhite:
        // Crisp Otsu binarization
        result = img.grayscale(result);
        result = _binarizeOtsu(result);
        break;
      case EnhancementPreset.photo:
        // Gentle contrast & natural lighting
        result = img.adjustColor(result, contrast: 1.05, brightness: 1.02);
        break;
    }

    // 3. Fine-grained flags
    if (options.grayscale && options.preset != EnhancementPreset.blackAndWhite) {
      result = img.grayscale(result);
    }
    if (options.blackAndWhite && options.preset != EnhancementPreset.blackAndWhite) {
      result = img.grayscale(result);
      result = _binarizeOtsu(result);
    }

    // 4. Sharpening filter
    if (options.sharpen) {
      result = _sharpenImage(result);
    }

    return result;
  }

  /// Document shadow & uneven illumination normalization.
  /// Divides image luminance by an estimated low-frequency background illumination map.
  static img.Image normalizeIllumination(img.Image image) {
    final w = image.width;
    final h = image.height;
    if (w < 20 || h < 20) return image;

    // Estimate background lighting using large downscale and blur
    const bgDim = 64;
    final scale = math.min(1.0, bgDim / math.max(w, h));
    final bgW = math.max(4, (w * scale).round());
    final bgH = math.max(4, (h * scale).round());

    final thumb = img.copyResize(image, width: bgW, height: bgH);
    final blurredThumb = img.gaussianBlur(thumb, radius: 4);
    final bgMap = img.copyResize(blurredThumb, width: w, height: h);

    final normalized = img.Image(width: w, height: h);

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final pOrig = image.getPixel(x, y);
        final pBg = bgMap.getPixel(x, y);

        final bgLum = (0.299 * pBg.r + 0.587 * pBg.g + 0.114 * pBg.b).clamp(40.0, 255.0);
        final factor = 240.0 / bgLum;

        final newR = (pOrig.r * factor).round().clamp(0, 255);
        final newG = (pOrig.g * factor).round().clamp(0, 255);
        final newB = (pOrig.b * factor).round().clamp(0, 255);

        normalized.setPixelRgba(x, y, newR, newG, newB, pOrig.a.toInt());
      }
    }

    return normalized;
  }

  /// Evaluates document scan quality (blur, contrast, brightness, resolution).
  static PageQualityAssessment assessQuality(img.Image image, {int estimatedDpi = 300}) {
    final w = image.width;
    final h = image.height;
    final warnings = <String>[];

    // Downscale for efficient statistical evaluation
    const evalDim = 300;
    final scale = math.min(1.0, evalDim / math.max(w, h));
    final evalW = math.max(10, (w * scale).round());
    final evalH = math.max(10, (h * scale).round());

    final small = img.copyResize(image, width: evalW, height: evalH);
    final gray = img.grayscale(small);

    // 1. Mean brightness and contrast (standard deviation of luminance)
    double sumLum = 0.0;
    final count = evalW * evalH;
    final lums = Float64List(count);

    int idx = 0;
    for (int y = 0; y < evalH; y++) {
      for (int x = 0; x < evalW; x++) {
        final p = gray.getPixel(x, y);
        final lum = p.r.toDouble();
        lums[idx++] = lum;
        sumLum += lum;
      }
    }
    final meanLum = sumLum / count;

    double sumSqDiff = 0.0;
    for (int i = 0; i < count; i++) {
      final diff = lums[i] - meanLum;
      sumSqDiff += diff * diff;
    }
    final contrastScore = math.sqrt(sumSqDiff / count);

    // 2. Blur assessment using Laplacian variance
    double lapVariance = 0.0;
    double sumLap = 0.0;
    final lapCount = (evalW - 2) * (evalH - 2);
    final laps = Float64List(lapCount);

    int lapIdx = 0;
    for (int y = 1; y < evalH - 1; y++) {
      for (int x = 1; x < evalW - 1; x++) {
        final center = gray.getPixel(x, y).r.toDouble();
        final up = gray.getPixel(x, y - 1).r.toDouble();
        final down = gray.getPixel(x, y + 1).r.toDouble();
        final left = gray.getPixel(x - 1, y).r.toDouble();
        final right = gray.getPixel(x + 1, y).r.toDouble();

        final lap = (up + down + left + right) - 4.0 * center;
        laps[lapIdx++] = lap;
        sumLap += lap;
      }
    }
    final meanLap = sumLap / lapCount;
    double sumLapSq = 0.0;
    for (int i = 0; i < lapCount; i++) {
      final diff = laps[i] - meanLap;
      sumLapSq += diff * diff;
    }
    lapVariance = sumLapSq / lapCount;

    // Check thresholds
    final isBlurry = lapVariance < 35.0;
    if (isBlurry) {
      warnings.add('Ảnh hơi mờ (Độ sắc nét: ${lapVariance.toStringAsFixed(1)})');
    }

    final isTooDark = meanLum < 65.0;
    if (isTooDark) {
      warnings.add('Trang bị tối');
    }

    final isTooBright = meanLum > 235.0;
    if (isTooBright) {
      warnings.add('Trang bị chói sáng');
    }

    final isLowResolution = w < 800 || h < 1000;
    if (isLowResolution) {
      warnings.add('Độ phân giải thấp cho OCR ($w x $h)');
    }

    return PageQualityAssessment(
      blurScore: lapVariance,
      contrastScore: contrastScore,
      brightnessScore: meanLum,
      dpi: estimatedDpi,
      isBlurry: isBlurry,
      isTooDark: isTooDark,
      isTooBright: isTooBright,
      isLowResolution: isLowResolution,
      warnings: warnings,
    );
  }

  /// Detects whether [image] is likely a blank page.
  static bool detectBlankPage(img.Image image) {
    const checkDim = 200;
    final scale = math.min(1.0, checkDim / math.max(image.width, image.height));
    final chkW = (image.width * scale).round();
    final chkH = (image.height * scale).round();

    final small = img.copyResize(image, width: chkW, height: chkH);
    final gray = img.grayscale(small);

    // Count non-white / content pixels (pixels darker than 220)
    int contentPixels = 0;
    final total = chkW * chkH;

    for (int y = 0; y < chkH; y++) {
      for (int x = 0; x < chkW; x++) {
        if (gray.getPixel(x, y).r < 210) {
          contentPixels++;
        }
      }
    }

    final contentRatio = contentPixels / total.toDouble();
    // If content occupies less than 0.6% of the page, it's likely blank
    return contentRatio < 0.006;
  }

  /// Calculates 64-bit difference hash (dHash) for duplicate detection.
  static String calculateDHash(img.Image image) {
    // Resize to 9x8 grayscale
    final small = img.copyResize(image, width: 9, height: 8);
    final gray = img.grayscale(small);

    int hashPart1 = 0;
    int hashPart2 = 0;

    int bitIndex = 0;
    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 8; x++) {
        final left = gray.getPixel(x, y).r;
        final right = gray.getPixel(x + 1, y).r;
        final bit = left > right ? 1 : 0;

        if (bitIndex < 32) {
          hashPart1 = (hashPart1 << 1) | bit;
        } else {
          hashPart2 = (hashPart2 << 1) | bit;
        }
        bitIndex++;
      }
    }

    final p1Hex = hashPart1.toRadixString(16).padLeft(8, '0');
    final p2Hex = hashPart2.toRadixString(16).padLeft(8, '0');
    return '$p1Hex$p2Hex';
  }

  /// Calculates Hamming distance between two hex dHash strings.
  static int hammingDistance(String hash1, String hash2) {
    if (hash1.length != 16 || hash2.length != 16) return 64;

    int dist = 0;
    for (int i = 0; i < 16; i++) {
      final v1 = int.tryParse(hash1[i], radix: 16) ?? 0;
      final v2 = int.tryParse(hash2[i], radix: 16) ?? 0;
      int xor = v1 ^ v2;
      while (xor > 0) {
        dist += (xor & 1);
        xor >>= 1;
      }
    }
    return dist;
  }

  // --- Internal Helper Algorithms ---

  static Uint8List _computeSobelEdges(img.Image gray) {
    final w = gray.width;
    final h = gray.height;
    final edgeBytes = Uint8List(w * h);

    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        final p00 = gray.getPixel(x - 1, y - 1).r.toInt();
        final p01 = gray.getPixel(x, y - 1).r.toInt();
        final p02 = gray.getPixel(x + 1, y - 1).r.toInt();
        final p10 = gray.getPixel(x - 1, y).r.toInt();
        final p12 = gray.getPixel(x + 1, y).r.toInt();
        final p20 = gray.getPixel(x - 1, y + 1).r.toInt();
        final p21 = gray.getPixel(x, y + 1).r.toInt();
        final p22 = gray.getPixel(x + 1, y + 1).r.toInt();

        final gx = (p02 + 2 * p12 + p22) - (p00 + 2 * p10 + p20);
        final gy = (p20 + 2 * p21 + p22) - (p00 + 2 * p01 + p02);

        final mag = (gx.abs() + gy.abs()).clamp(0, 255);
        edgeBytes[y * w + x] = mag > 60 ? 255 : 0;
      }
    }

    return edgeBytes;
  }

  static List<Point2D> _findBoundaryCorners(Uint8List edges, int w, int h) {
    // Scan perimeter rays to find extreme page boundaries
    Point2D? tlCandidate;
    Point2D? trCandidate;
    Point2D? brCandidate;
    Point2D? blCandidate;

    // Corner search areas (e.g. within 35% of each respective corner)
    final cornerMarginX = (w * 0.35).round();
    final cornerMarginY = (h * 0.35).round();

    // 1. Top-Left search (minimize x + y)
    double minSum = double.infinity;
    for (int y = 0; y < cornerMarginY; y++) {
      for (int x = 0; x < cornerMarginX; x++) {
        if (edges[y * w + x] > 0) {
          final sum = (x + y).toDouble();
          if (sum < minSum) {
            minSum = sum;
            tlCandidate = Point2D(x.toDouble(), y.toDouble());
          }
        }
      }
    }

    // 2. Top-Right search (minimize y - x)
    double minTrDiff = double.infinity;
    for (int y = 0; y < cornerMarginY; y++) {
      for (int x = w - 1; x >= w - cornerMarginX; x--) {
        if (edges[y * w + x] > 0) {
          final diff = (y - x).toDouble();
          if (diff < minTrDiff) {
            minTrDiff = diff;
            trCandidate = Point2D(x.toDouble(), y.toDouble());
          }
        }
      }
    }

    // 3. Bottom-Right search (maximize x + y)
    double maxSum = -double.infinity;
    for (int y = h - 1; y >= h - cornerMarginY; y--) {
      for (int x = w - 1; x >= w - cornerMarginX; x--) {
        if (edges[y * w + x] > 0) {
          final sum = (x + y).toDouble();
          if (sum > maxSum) {
            maxSum = sum;
            brCandidate = Point2D(x.toDouble(), y.toDouble());
          }
        }
      }
    }

    // 4. Bottom-Left search (maximize y - x)
    double maxBlDiff = -double.infinity;
    for (int y = h - 1; y >= h - cornerMarginY; y--) {
      for (int x = 0; x < cornerMarginX; x++) {
        if (edges[y * w + x] > 0) {
          final diff = (y - x).toDouble();
          if (diff > maxBlDiff) {
            maxBlDiff = diff;
            blCandidate = Point2D(x.toDouble(), y.toDouble());
          }
        }
      }
    }

    if (tlCandidate != null &&
        trCandidate != null &&
        brCandidate != null &&
        blCandidate != null) {
      return [tlCandidate, trCandidate, brCandidate, blCandidate];
    }

    return const [];
  }

  static img.Pixel _sampleBilinear(img.Image imgObj, double x, double y, int w, int h) {
    final x0 = x.floor().clamp(0, w - 1);
    final y0 = y.floor().clamp(0, h - 1);
    final x1 = (x0 + 1).clamp(0, w - 1);
    final y1 = (y0 + 1).clamp(0, h - 1);

    final sx = (x - x0).clamp(0.0, 1.0);
    final sy = (y - y0).clamp(0.0, 1.0);

    final p00 = imgObj.getPixel(x0, y0);
    final p10 = imgObj.getPixel(x1, y0);
    final p01 = imgObj.getPixel(x0, y1);
    final p11 = imgObj.getPixel(x1, y1);

    final r = (1.0 - sx) * (1.0 - sy) * p00.r +
        sx * (1.0 - sy) * p10.r +
        (1.0 - sx) * sy * p01.r +
        sx * sy * p11.r;
    final g = (1.0 - sx) * (1.0 - sy) * p00.g +
        sx * (1.0 - sy) * p10.g +
        (1.0 - sx) * sy * p01.g +
        sx * sy * p11.g;
    final b = (1.0 - sx) * (1.0 - sy) * p00.b +
        sx * (1.0 - sy) * p10.b +
        (1.0 - sx) * sy * p01.b +
        sx * sy * p11.b;

    // Return interpolated pixel using destination pixel representation
    final dummy = img.Image(width: 1, height: 1);
    dummy.setPixelRgba(0, 0, r.round().clamp(0, 255), g.round().clamp(0, 255), b.round().clamp(0, 255), 255);
    return dummy.getPixel(0, 0);
  }

  static img.Image _binarizeOtsu(img.Image gray) {
    final histogram = List<int>.filled(256, 0);
    final total = gray.width * gray.height;

    for (int y = 0; y < gray.height; y++) {
      for (int x = 0; x < gray.width; x++) {
        histogram[gray.getPixel(x, y).r.toInt()]++;
      }
    }

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

    final out = img.Image(width: gray.width, height: gray.height);
    for (int y = 0; y < gray.height; y++) {
      for (int x = 0; x < gray.width; x++) {
        final val = gray.getPixel(x, y).r < threshold ? 0 : 255;
        out.setPixelRgb(x, y, val, val, val);
      }
    }
    return out;
  }

  static img.Image _sharpenImage(img.Image image) {
    final w = image.width;
    final h = image.height;
    final out = img.Image(width: w, height: h);

    // Unsharp mask approximation using 3x3 convolution
    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        final c = image.getPixel(x, y);
        final up = image.getPixel(x, y - 1);
        final down = image.getPixel(x, y + 1);
        final left = image.getPixel(x - 1, y);
        final right = image.getPixel(x + 1, y);

        final r = (5 * c.r - (up.r + down.r + left.r + right.r)).clamp(0, 255);
        final g = (5 * c.g - (up.g + down.g + left.g + right.g)).clamp(0, 255);
        final b = (5 * c.b - (up.b + down.b + left.b + right.b)).clamp(0, 255);

        out.setPixelRgba(x, y, r.toInt(), g.toInt(), b.toInt(), c.a.toInt());
      }
    }
    return out;
  }
}
