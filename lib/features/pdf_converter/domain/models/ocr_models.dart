/// Bounding box representation in normalized or pixel coordinates.
class OcrBoundingBox {
  final double left;
  final double top;
  final double width;
  final double height;

  const OcrBoundingBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  double get right => left + width;
  double get bottom => top + height;

  Map<String, dynamic> toJson() => {
    'left': left,
    'top': top,
    'width': width,
    'height': height,
  };

  factory OcrBoundingBox.fromJson(Map<String, dynamic> json) => OcrBoundingBox(
    left: (json['left'] as num?)?.toDouble() ?? 0.0,
    top: (json['top'] as num?)?.toDouble() ?? 0.0,
    width: (json['width'] as num?)?.toDouble() ?? 0.0,
    height: (json['height'] as num?)?.toDouble() ?? 0.0,
  );
}

/// A recognized line of text within an OCR text block.
class OcrLineBlock {
  final String text;
  final OcrBoundingBox box;
  final double? confidence;

  const OcrLineBlock({
    required this.text,
    required this.box,
    this.confidence,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'box': box.toJson(),
    'confidence': confidence,
  };

  factory OcrLineBlock.fromJson(Map<String, dynamic> json) => OcrLineBlock(
    text: json['text'] as String? ?? '',
    box: OcrBoundingBox.fromJson(json['box'] as Map<String, dynamic>? ?? {}),
    confidence: (json['confidence'] as num?)?.toDouble(),
  );
}

/// A paragraph or block of recognized text with its bounding box and confidence score.
class OcrTextBlock {
  final String text;
  final OcrBoundingBox box;
  final double? confidence;
  final List<OcrLineBlock> lines;

  const OcrTextBlock({
    required this.text,
    required this.box,
    this.confidence,
    this.lines = const [],
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'box': box.toJson(),
    'confidence': confidence,
    'lines': lines.map((l) => l.toJson()).toList(),
  };

  factory OcrTextBlock.fromJson(Map<String, dynamic> json) => OcrTextBlock(
    text: json['text'] as String? ?? '',
    box: OcrBoundingBox.fromJson(json['box'] as Map<String, dynamic>? ?? {}),
    confidence: (json['confidence'] as num?)?.toDouble(),
    lines: (json['lines'] as List<dynamic>?)
            ?.map((l) => OcrLineBlock.fromJson(l as Map<String, dynamic>))
            .toList() ??
        const [],
  );
}

/// Status of the OCR operation.
enum OcrStatus {
  success,
  noTextDetected,
  engineUnavailable,
  languageUnavailable,
  decodeFailure,
  timeout,
  cancelled,
  error,
}

/// Results of performing OCR on a single rendered page image.
class OcrPageResult {
  final int pageNumber;
  final List<OcrTextBlock> blocks;
  final String fullText;
  final double? averageConfidence;
  final int durationMs;
  final OcrStatus status;
  final String? languageUsed;

  const OcrPageResult({
    required this.pageNumber,
    required this.blocks,
    required this.fullText,
    this.averageConfidence,
    this.durationMs = 0,
    this.status = OcrStatus.success,
    this.languageUsed,
  });

  String get confidenceDisplay => averageConfidence != null
      ? '${(averageConfidence! * 100).toStringAsFixed(1)}%'
      : 'Không có dữ liệu độ tin cậy';

  Map<String, dynamic> toJson() => {
    'pageNumber': pageNumber,
    'blocks': blocks.map((b) => b.toJson()).toList(),
    'fullText': fullText,
    'averageConfidence': averageConfidence,
    'durationMs': durationMs,
    'status': status.name,
    'languageUsed': languageUsed,
  };

  factory OcrPageResult.fromJson(Map<String, dynamic> json) => OcrPageResult(
    pageNumber: json['pageNumber'] as int? ?? 1,
    blocks: (json['blocks'] as List<dynamic>?)
            ?.map((b) => OcrTextBlock.fromJson(b as Map<String, dynamic>))
            .toList() ??
        const [],
    fullText: json['fullText'] as String? ?? '',
    averageConfidence: (json['averageConfidence'] as num?)?.toDouble(),
    durationMs: json['durationMs'] as int? ?? 0,
    status: OcrStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => OcrStatus.success,
    ),
    languageUsed: json['languageUsed'] as String?,
  );
}

/// Request parameters sent to the OCR engine.
class OcrRequest {
  final String imagePath;
  final int pageNumber;
  final String language; // 'vie', 'eng', 'vie+eng'
  final bool autoDeskew;
  final bool autoEnhance;
  final int rotationDegrees; // 0, 90, 180, 270
  final bool autoRotate; // auto detect orientation
  final bool allowFallbackLanguage; // allow available engine if requested language unavailable

  const OcrRequest({
    required this.imagePath,
    required this.pageNumber,
    this.language = 'vie',
    this.autoDeskew = true,
    this.autoEnhance = true,
    this.rotationDegrees = 0,
    this.autoRotate = true,
    this.allowFallbackLanguage = true,
  });
}

/// Base typed exception for OCR failures.
class OcrException implements Exception {
  final String message;
  final OcrStatus status;
  const OcrException(this.message, {this.status = OcrStatus.error});

  @override
  String toString() => 'OcrException($status): $message';
}

class OcrEngineUnavailableException extends OcrException {
  const OcrEngineUnavailableException([
    super.message = 'Động cơ nhận dạng ký tự quang học (Windows OCR) không khả dụng trên hệ thống này.',
  ]) : super(status: OcrStatus.engineUnavailable);
}

class OcrLanguageUnavailableException extends OcrException {
  final String language;
  const OcrLanguageUnavailableException(
    this.language, [
    super.message = 'Gói nhận dạng ngôn ngữ yêu cầu chưa được cài đặt trong Windows.',
  ]) : super(status: OcrStatus.languageUnavailable);
}

class OcrImageDecodeException extends OcrException {
  const OcrImageDecodeException([
    super.message = 'Không thể giải mã dữ liệu ảnh bitmap để nhận dạng OCR.',
  ]) : super(status: OcrStatus.decodeFailure);
}

class OcrTimeoutException extends OcrException {
  const OcrTimeoutException([
    super.message = 'Quá thời gian thực thi nhận dạng OCR.',
  ]) : super(status: OcrStatus.timeout);
}

class OcrProcessException extends OcrException {
  const OcrProcessException(super.message, {super.status = OcrStatus.error});
}
