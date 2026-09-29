import 'dart:math' as math;

/// 2D Point with floating point coordinates.
class Point2D {
  final double x;
  final double y;

  const Point2D(this.x, this.y);

  double distanceTo(Point2D other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  Point2D operator +(Point2D other) => Point2D(x + other.x, y + other.y);
  Point2D operator -(Point2D other) => Point2D(x - other.x, y - other.y);
  Point2D operator *(double factor) => Point2D(x * factor, y * factor);

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory Point2D.fromJson(Map<String, dynamic> json) => Point2D(
        (json['x'] as num?)?.toDouble() ?? 0.0,
        (json['y'] as num?)?.toDouble() ?? 0.0,
      );

  @override
  String toString() => 'Point2D(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Point2D &&
          runtimeType == other.runtimeType &&
          (x - other.x).abs() < 1e-4 &&
          (y - other.y).abs() < 1e-4;

  @override
  int get hashCode => Object.hash(x.round(), y.round());
}

/// Quadrilateral representing the 4 corners of a detected document page.
/// Always ordered: topLeft, topRight, bottomRight, bottomLeft.
class DocumentQuad {
  final Point2D topLeft;
  final Point2D topRight;
  final Point2D bottomRight;
  final Point2D bottomLeft;

  const DocumentQuad({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  /// Creates a quad covering the entire image bounds.
  factory DocumentQuad.fullImage(double width, double height) {
    return DocumentQuad(
      topLeft: const Point2D(0, 0),
      topRight: Point2D(width, 0),
      bottomRight: Point2D(width, height),
      bottomLeft: Point2D(0, height),
    );
  }

  /// List of corners in clockwise order.
  List<Point2D> get corners => [topLeft, topRight, bottomRight, bottomLeft];

  /// Average width calculated from top and bottom edges.
  double get estimatedWidth {
    final topW = topLeft.distanceTo(topRight);
    final bottomW = bottomLeft.distanceTo(bottomRight);
    return math.max(topW, bottomW);
  }

  /// Average height calculated from left and right edges.
  double get estimatedHeight {
    final leftH = topLeft.distanceTo(bottomLeft);
    final rightH = topRight.distanceTo(bottomRight);
    return math.max(leftH, rightH);
  }

  /// Approximates area using Shoelace formula (Gauss's area formula).
  double get area {
    final c = corners;
    double sum = 0.0;
    for (int i = 0; i < c.length; i++) {
      final p1 = c[i];
      final p2 = c[(i + 1) % c.length];
      sum += (p1.x * p2.y) - (p1.y * p2.x);
    }
    return (sum.abs() / 2.0);
  }

  /// Aspect ratio: width / height.
  double get aspectRatio {
    final h = estimatedHeight;
    if (h == 0) return 1.0;
    return estimatedWidth / h;
  }

  /// Verifies if quadrilateral is convex and geometrically plausible.
  bool get isConvex {
    final c = corners;
    int sign = 0;
    for (int i = 0; i < 4; i++) {
      final p1 = c[i];
      final p2 = c[(i + 1) % 4];
      final p3 = c[(i + 2) % 4];
      final dx1 = p2.x - p1.x;
      final dy1 = p2.y - p1.y;
      final dx2 = p3.x - p2.x;
      final dy2 = p3.y - p2.y;
      final crossProduct = dx1 * dy2 - dy1 * dx2;
      if (crossProduct != 0) {
        final currentSign = crossProduct > 0 ? 1 : -1;
        if (sign == 0) {
          sign = currentSign;
        } else if (sign != currentSign) {
          return false;
        }
      }
    }
    return true;
  }

  /// Validates document plausibility:
  /// - Is convex
  /// - Area >= 5% of total image area
  /// - Plausible aspect ratio (between 0.2 and 5.0)
  bool isPlausible(double imageWidth, double imageHeight) {
    if (!isConvex) return false;
    final totalImageArea = imageWidth * imageHeight;
    if (totalImageArea <= 0) return false;
    final ratio = area / totalImageArea;
    if (ratio < 0.05 || ratio > 1.05) return false;
    final ar = aspectRatio;
    if (ar < 0.2 || ar > 5.0) return false;
    return true;
  }

  /// Orders 4 arbitrary points into: topLeft, topRight, bottomRight, bottomLeft.
  /// Uses sum (x + y) and difference (y - x) sorting:
  /// - topLeft has minimum sum (x + y)
  /// - bottomRight has maximum sum (x + y)
  /// - topRight has minimum diff (y - x)
  /// - bottomLeft has maximum diff (y - x)
  static DocumentQuad orderCorners(List<Point2D> pts) {
    if (pts.length != 4) {
      throw ArgumentError('Exactly 4 points are required to construct DocumentQuad');
    }

    // Sort by sum (x + y)
    final sortedBySum = List<Point2D>.from(pts)
      ..sort((a, b) => (a.x + a.y).compareTo(b.x + b.y));
    final tl = sortedBySum.first;
    final br = sortedBySum.last;

    // Remaining 2 points are topRight and bottomLeft
    final remaining = pts.where((p) => p != tl && p != br).toList();
    if (remaining.length == 2) {
      // Sort remaining by diff (y - x): topRight has smaller (y - x), bottomLeft has larger (y - x)
      remaining.sort((a, b) => (a.y - a.x).compareTo(b.y - b.x));
      final tr = remaining.first;
      final bl = remaining.last;
      return DocumentQuad(topLeft: tl, topRight: tr, bottomRight: br, bottomLeft: bl);
    }

    // Fallback if points had identical sums
    return DocumentQuad(
      topLeft: pts[0],
      topRight: pts[1],
      bottomRight: pts[2],
      bottomLeft: pts[3],
    );
  }

  Map<String, dynamic> toJson() => {
        'topLeft': topLeft.toJson(),
        'topRight': topRight.toJson(),
        'bottomRight': bottomRight.toJson(),
        'bottomLeft': bottomLeft.toJson(),
      };

  factory DocumentQuad.fromJson(Map<String, dynamic> json) => DocumentQuad(
        topLeft: Point2D.fromJson(json['topLeft'] as Map<String, dynamic>? ?? {}),
        topRight: Point2D.fromJson(json['topRight'] as Map<String, dynamic>? ?? {}),
        bottomRight: Point2D.fromJson(json['bottomRight'] as Map<String, dynamic>? ?? {}),
        bottomLeft: Point2D.fromJson(json['bottomLeft'] as Map<String, dynamic>? ?? {}),
      );
}
