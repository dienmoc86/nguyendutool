import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:nguyendu_tool/features/scanner/domain/models/document_quad.dart';
import 'package:nguyendu_tool/features/scanner/infrastructure/cv_document_processor.dart';

void main() {
  final fixturesDir = p.join(Directory.current.path, 'test', 'fixtures', 'cv');

  group('CvDocumentProcessor - Geometry & Corner Ordering', () {
    test('Point2D distance and arithmetic', () {
      const p1 = Point2D(0, 0);
      const p2 = Point2D(3, 4);
      expect(p1.distanceTo(p2), equals(5.0));

      final p3 = p1 + p2;
      expect(p3.x, equals(3.0));
      expect(p3.y, equals(4.0));
    });

    test('DocumentQuad orders 4 arbitrary points clockwise', () {
      // Unordered corners
      final pts = [
        const Point2D(700, 900), // BR
        const Point2D(100, 100), // TL
        const Point2D(100, 900), // BL
        const Point2D(700, 100), // TR
      ];

      final quad = DocumentQuad.orderCorners(pts);

      expect(quad.topLeft, equals(const Point2D(100, 100)));
      expect(quad.topRight, equals(const Point2D(700, 100)));
      expect(quad.bottomRight, equals(const Point2D(700, 900)));
      expect(quad.bottomLeft, equals(const Point2D(100, 900)));

      expect(quad.isConvex, isTrue);
      expect(quad.isPlausible(800, 1000), isTrue);
      expect(quad.area, closeTo(600 * 800, 10.0));
    });

    test('DocumentQuad rejects non-convex or implausible quadrilaterals', () {
      // Self-intersecting "bowtie" quad
      const bowtie = DocumentQuad(
        topLeft: Point2D(100, 100),
        topRight: Point2D(700, 900),
        bottomRight: Point2D(700, 100),
        bottomLeft: Point2D(100, 900),
      );
      expect(bowtie.isConvex, isFalse);

      // Micro quad (< 5% of 800x1000)
      const micro = DocumentQuad(
        topLeft: Point2D(10, 10),
        topRight: Point2D(20, 10),
        bottomRight: Point2D(20, 20),
        bottomLeft: Point2D(10, 20),
      );
      expect(micro.isPlausible(800, 1000), isFalse);
    });
  });

  group('CvDocumentProcessor - Boundary Detection & Perspective Warping', () {
    test('detectDocumentQuad finds document boundary with tolerance', () async {
      final file = File(p.join(fixturesDir, 'flat_document.png'));
      expect(file.existsSync(), isTrue);

      final image = img.decodePng(await file.readAsBytes())!;
      final quad = CvDocumentProcessor.detectDocumentQuad(image);

      expect(quad.isConvex, isTrue);
      // Expected corners in flat_document: ~100, 100 to 700, 900
      // Allow +/- 30px tolerance due to downsampling & edge search
      expect(quad.topLeft.x, closeTo(100, 30));
      expect(quad.topLeft.y, closeTo(100, 30));
      expect(quad.bottomRight.x, closeTo(700, 30));
      expect(quad.bottomRight.y, closeTo(900, 30));
    });

    test('warpPerspective rectifies perspective trapezoid into rectangular image', () async {
      final file = File(p.join(fixturesDir, 'perspective_document.png'));
      expect(file.existsSync(), isTrue);

      final image = img.decodePng(await file.readAsBytes())!;
      const quad = DocumentQuad(
        topLeft: Point2D(180, 140),
        topRight: Point2D(620, 160),
        bottomRight: Point2D(720, 880),
        bottomLeft: Point2D(80, 850),
      );

      final warped = CvDocumentProcessor.warpPerspective(image, quad);
      expect(warped.width, greaterThan(400));
      expect(warped.height, greaterThan(600));

      // Rectified image should have high contrast center
      final centerPixel = warped.getPixel(warped.width ~/ 2, warped.height ~/ 2);
      expect(centerPixel.r, greaterThan(150));
    });
  });

  group('CvDocumentProcessor - Blank Page & Quality Assessment & Hash', () {
    test('detectBlankPage correctly identifies blank page vs content document', () async {
      final blankFile = File(p.join(fixturesDir, 'blank_page.png'));
      final flatFile = File(p.join(fixturesDir, 'flat_document.png'));

      final blankImg = img.decodePng(await blankFile.readAsBytes())!;
      final flatImg = img.decodePng(await flatFile.readAsBytes())!;

      expect(CvDocumentProcessor.detectBlankPage(blankImg), isTrue);
      expect(CvDocumentProcessor.detectBlankPage(flatImg), isFalse);
    });

    test('assessQuality detects blurred image and low contrast', () async {
      final blurFile = File(p.join(fixturesDir, 'blur_document.png'));
      final lowContrastFile = File(p.join(fixturesDir, 'low_contrast_document.png'));
      final flatFile = File(p.join(fixturesDir, 'flat_document.png'));

      final blurImg = img.decodePng(await blurFile.readAsBytes())!;
      final lowContrastImg = img.decodePng(await lowContrastFile.readAsBytes())!;
      final flatImg = img.decodePng(await flatFile.readAsBytes())!;

      final blurQuality = CvDocumentProcessor.assessQuality(blurImg);
      final lowContrastQuality = CvDocumentProcessor.assessQuality(lowContrastImg);
      final flatQuality = CvDocumentProcessor.assessQuality(flatImg);

      expect(blurQuality.blurScore, lessThan(flatQuality.blurScore));
      expect(lowContrastQuality.contrastScore, lessThan(flatQuality.contrastScore));
    });

    test('calculateDHash generates consistent 16-hex perceptual hash and computes Hamming distance', () async {
      final flatFile = File(p.join(fixturesDir, 'flat_document.png'));
      final flatImg = img.decodePng(await flatFile.readAsBytes())!;

      final hash1 = CvDocumentProcessor.calculateDHash(flatImg);
      expect(hash1.length, equals(16));

      // Identical image should have Hamming distance 0
      final distIdentical = CvDocumentProcessor.hammingDistance(hash1, hash1);
      expect(distIdentical, equals(0));

      // Slightly brightened image should have very low Hamming distance (<= 2)
      final brightened = img.adjustColor(flatImg, brightness: 1.05);
      final hash2 = CvDocumentProcessor.calculateDHash(brightened);
      final distNear = CvDocumentProcessor.hammingDistance(hash1, hash2);
      expect(distNear, lessThanOrEqualTo(2));
    });
  });
}
