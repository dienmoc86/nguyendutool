/// Classification of a PDF document or page based on its embedded content stream vs raster images.
enum PdfClassification {
  text,
  scanned,
  mixed,
  needsRasterAnalysis;

  String get label {
    switch (this) {
      case PdfClassification.text:
        return 'Văn bản số (Digital Text)';
      case PdfClassification.scanned:
        return 'Tài liệu quét (Scanned / Image)';
      case PdfClassification.mixed:
        return 'Hỗn hợp (Mixed Text & Scan)';
      case PdfClassification.needsRasterAnalysis:
        return 'Cần phân tích Raster / OCR';
    }
  }
}

/// Analysis details for an individual PDF page.
class PdfPageAnalysis {
  final int pageNumber;
  final int textLength;
  final int imageCount;
  final double imageAreaRatio;
  final bool hasEmbeddedFonts;
  final PdfClassification classification;
  final int rotationDegrees;

  const PdfPageAnalysis({
    required this.pageNumber,
    required this.textLength,
    required this.imageCount,
    required this.imageAreaRatio,
    required this.hasEmbeddedFonts,
    required this.classification,
    this.rotationDegrees = 0,
  });

  bool get requiresOcr =>
      classification == PdfClassification.scanned ||
      classification == PdfClassification.mixed ||
      classification == PdfClassification.needsRasterAnalysis;

  Map<String, dynamic> toJson() => {
    'pageNumber': pageNumber,
    'textLength': textLength,
    'imageCount': imageCount,
    'imageAreaRatio': imageAreaRatio,
    'hasEmbeddedFonts': hasEmbeddedFonts,
    'classification': classification.name,
    'rotationDegrees': rotationDegrees,
  };

  factory PdfPageAnalysis.fromJson(Map<String, dynamic> json) => PdfPageAnalysis(
    pageNumber: json['pageNumber'] as int? ?? 1,
    textLength: json['textLength'] as int? ?? 0,
    imageCount: json['imageCount'] as int? ?? 0,
    imageAreaRatio: (json['imageAreaRatio'] as num?)?.toDouble() ?? 0.0,
    hasEmbeddedFonts: json['hasEmbeddedFonts'] as bool? ?? false,
    classification: PdfClassification.values.firstWhere(
      (e) => e.name == json['classification'],
      orElse: () => PdfClassification.text,
    ),
    rotationDegrees: json['rotationDegrees'] as int? ?? 0,
  );
}

/// Complete document analysis result for a PDF file.
class PdfDocumentAnalysis {
  final String filePath;
  final int totalPages;
  final List<PdfPageAnalysis> pages;
  final PdfClassification overallClassification;
  final int totalCharacters;
  final bool containsTables;
  final int fileSize;

  const PdfDocumentAnalysis({
    required this.filePath,
    required this.totalPages,
    required this.pages,
    required this.overallClassification,
    required this.totalCharacters,
    this.containsTables = false,
    this.fileSize = 0,
  });

  bool get needsOcr =>
      overallClassification == PdfClassification.scanned ||
      overallClassification == PdfClassification.mixed ||
      overallClassification == PdfClassification.needsRasterAnalysis;

  Map<String, dynamic> toJson() => {
    'filePath': filePath,
    'totalPages': totalPages,
    'pages': pages.map((p) => p.toJson()).toList(),
    'overallClassification': overallClassification.name,
    'totalCharacters': totalCharacters,
    'containsTables': containsTables,
    'fileSize': fileSize,
  };

  factory PdfDocumentAnalysis.fromJson(Map<String, dynamic> json) => PdfDocumentAnalysis(
    filePath: json['filePath'] as String? ?? '',
    totalPages: json['totalPages'] as int? ?? 0,
    pages: (json['pages'] as List<dynamic>?)
            ?.map((p) => PdfPageAnalysis.fromJson(p as Map<String, dynamic>))
            .toList() ??
        [],
    overallClassification: PdfClassification.values.firstWhere(
      (e) => e.name == json['overallClassification'],
      orElse: () => PdfClassification.text,
    ),
    totalCharacters: json['totalCharacters'] as int? ?? 0,
    containsTables: json['containsTables'] as bool? ?? false,
    fileSize: json['fileSize'] as int? ?? 0,
  );
}
