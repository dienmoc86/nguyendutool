import 'package:nguyendu_tool/features/pdf_converter/domain/models/ocr_models.dart';
import 'document_quad.dart';
import 'scan_options.dart';

/// Assessment of visual scan quality.
class PageQualityAssessment {
  final double blurScore; // higher = sharper
  final double contrastScore;
  final double brightnessScore;
  final int dpi;
  final bool isBlurry;
  final bool isTooDark;
  final bool isTooBright;
  final bool isLowResolution;
  final List<String> warnings;

  const PageQualityAssessment({
    required this.blurScore,
    required this.contrastScore,
    required this.brightnessScore,
    required this.dpi,
    this.isBlurry = false,
    this.isTooDark = false,
    this.isTooBright = false,
    this.isLowResolution = false,
    this.warnings = const [],
  });

  Map<String, dynamic> toJson() => {
        'blurScore': blurScore,
        'contrastScore': contrastScore,
        'brightnessScore': brightnessScore,
        'dpi': dpi,
        'isBlurry': isBlurry,
        'isTooDark': isTooDark,
        'isTooBright': isTooBright,
        'isLowResolution': isLowResolution,
        'warnings': warnings,
      };

  factory PageQualityAssessment.fromJson(Map<String, dynamic> json) => PageQualityAssessment(
        blurScore: (json['blurScore'] as num?)?.toDouble() ?? 100.0,
        contrastScore: (json['contrastScore'] as num?)?.toDouble() ?? 50.0,
        brightnessScore: (json['brightnessScore'] as num?)?.toDouble() ?? 128.0,
        dpi: (json['dpi'] as num?)?.toInt() ?? 300,
        isBlurry: json['isBlurry'] as bool? ?? false,
        isTooDark: json['isTooDark'] as bool? ?? false,
        isTooBright: json['isTooBright'] as bool? ?? false,
        isLowResolution: json['isLowResolution'] as bool? ?? false,
        warnings: (json['warnings'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      );
}

/// Represents a single scanned or imported page in a session.
/// Keeps both original and processed image paths non-destructively.
class ScanPage {
  final String id;
  final String sessionId;
  final int pageIndex;
  final String originalPath;
  final String processedPath;
  final int rotation; // 0, 90, 180, 270
  final DocumentQuad? detectedQuad;
  final DocumentQuad? manualQuad;
  final double cropPadding;
  final ScanProcessingOptions processingOptions;
  final PageQualityAssessment? quality;
  final OcrPageResult? ocrResult;
  final String ocrStatus; // 'none', 'pending', 'done', 'error'
  final bool isLikelyBlank;
  final String? perceptualHash;
  final DateTime createdAt;

  const ScanPage({
    required this.id,
    required this.sessionId,
    required this.pageIndex,
    required this.originalPath,
    required this.processedPath,
    this.rotation = 0,
    this.detectedQuad,
    this.manualQuad,
    this.cropPadding = 0.0,
    this.processingOptions = const ScanProcessingOptions(),
    this.quality,
    this.ocrResult,
    this.ocrStatus = 'none',
    this.isLikelyBlank = false,
    this.perceptualHash,
    required this.createdAt,
  });

  /// The active crop quad: manual quad if user adjusted, otherwise detected quad.
  DocumentQuad? get activeQuad => manualQuad ?? detectedQuad;

  ScanPage copyWith({
    String? id,
    String? sessionId,
    int? pageIndex,
    String? originalPath,
    String? processedPath,
    int? rotation,
    DocumentQuad? detectedQuad,
    DocumentQuad? manualQuad,
    double? cropPadding,
    ScanProcessingOptions? processingOptions,
    PageQualityAssessment? quality,
    OcrPageResult? ocrResult,
    String? ocrStatus,
    bool? isLikelyBlank,
    String? perceptualHash,
    DateTime? createdAt,
  }) {
    return ScanPage(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      pageIndex: pageIndex ?? this.pageIndex,
      originalPath: originalPath ?? this.originalPath,
      processedPath: processedPath ?? this.processedPath,
      rotation: rotation ?? this.rotation,
      detectedQuad: detectedQuad ?? this.detectedQuad,
      manualQuad: manualQuad ?? this.manualQuad,
      cropPadding: cropPadding ?? this.cropPadding,
      processingOptions: processingOptions ?? this.processingOptions,
      quality: quality ?? this.quality,
      ocrResult: ocrResult ?? this.ocrResult,
      ocrStatus: ocrStatus ?? this.ocrStatus,
      isLikelyBlank: isLikelyBlank ?? this.isLikelyBlank,
      perceptualHash: perceptualHash ?? this.perceptualHash,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'pageIndex': pageIndex,
        'originalPath': originalPath,
        'processedPath': processedPath,
        'rotation': rotation,
        'detectedQuad': detectedQuad?.toJson(),
        'manualQuad': manualQuad?.toJson(),
        'cropPadding': cropPadding,
        'processingOptions': processingOptions.toJson(),
        'quality': quality?.toJson(),
        'ocrResult': ocrResult?.toJson(),
        'ocrStatus': ocrStatus,
        'isLikelyBlank': isLikelyBlank,
        'perceptualHash': perceptualHash,
        'createdAt': createdAt.toIso8601String(),
      };
}
