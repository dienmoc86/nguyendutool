import 'package:nguyendu_tool/core/errors/app_exceptions.dart';

/// Handler for exact score representation and integer hundredths arithmetic (Section 10).
class ScorePrecisionHandler {
  const ScorePrecisionHandler._();

  /// Maximum allowed decimal places (2 decimal places / hundredths).
  static const int maxDecimals = 2;

  /// Checks if a score is valid: finite, non-negative, and fits within 2 decimal places.
  static bool isValidScore(double score) {
    if (score.isNaN || score.isInfinite || score < 0) return false;
    final cents = score * 100;
    final rounded = cents.round();
    return (cents - rounded).abs() < 1e-4;
  }

  /// Converts a double score to integer hundredths (e.g. 0.25 -> 25).
  /// Throws [ScorePrecisionException] if the score is NaN, infinite, negative,
  /// or specifies more than 2 decimal places.
  static int toHundredths(double score) {
    if (score.isNaN || score.isInfinite) {
      throw ScorePrecisionException('Điểm số không được là NaN hoặc vô cực.', score: score);
    }
    if (score < 0) {
      throw ScorePrecisionException('Điểm số không được là số âm.', score: score);
    }
    final cents = score * 100;
    final rounded = cents.round();
    if ((cents - rounded).abs() >= 1e-4) {
      throw ScorePrecisionException(
        'Điểm số vượt quá độ chính xác cho phép (tối đa 2 chữ số thập phân / phần trăm).',
        score: score,
      );
    }
    return rounded;
  }

  /// Converts integer hundredths back to double (e.g. 25 -> 0.25).
  static double fromHundredths(int hundredths) {
    return hundredths / 100.0;
  }

  /// Formats score to standard string representation (e.g. 0.25, 1.0, 10.0).
  static String formatScore(double score) {
    if (score == score.roundToDouble()) {
      return score.toStringAsFixed(1);
    }
    return score.toStringAsFixed(2);
  }
}
