/// Source of acquired scanner pages.
enum ScanSource {
  physicalScanner,
  imageImport,
  camera,
  pdfImport;

  String get label {
    switch (this) {
      case ScanSource.physicalScanner:
        return 'Máy quét vật lý';
      case ScanSource.imageImport:
        return 'Tệp ảnh';
      case ScanSource.camera:
        return 'Camera / Webcam';
      case ScanSource.pdfImport:
        return 'Tài liệu PDF';
    }
  }
}

/// Supported export formats for scanned sessions.
enum ScanOutputFormat {
  searchablePdf,
  standardPdf,
  docx,
  pptx,
  images,
  txt;

  String get label {
    switch (this) {
      case ScanOutputFormat.searchablePdf:
        return 'PDF có thể tìm kiếm văn bản (Searchable PDF)';
      case ScanOutputFormat.standardPdf:
        return 'PDF ảnh chuẩn (Standard PDF)';
      case ScanOutputFormat.docx:
        return 'Giáo án / Văn bản Word (.docx)';
      case ScanOutputFormat.pptx:
        return 'Bài giảng trình chiếu PowerPoint (.pptx)';
      case ScanOutputFormat.images:
        return 'Tập tin hình ảnh (PNG / JPEG)';
      case ScanOutputFormat.txt:
        return 'Văn bản thuần (.txt)';
    }
  }

  String get extension {
    switch (this) {
      case ScanOutputFormat.searchablePdf:
      case ScanOutputFormat.standardPdf:
        return '.pdf';
      case ScanOutputFormat.docx:
        return '.docx';
      case ScanOutputFormat.pptx:
        return '.pptx';
      case ScanOutputFormat.images:
        return '.png';
      case ScanOutputFormat.txt:
        return '.txt';
    }
  }
}

/// Compression and quality presets for PDF / Image export.
enum ScanOutputQuality {
  small(0.6, 150, 'Dung lượng nhỏ (150 DPI, nén 60%)'),
  balanced(0.8, 200, 'Cân bằng (200 DPI, nén 80%)'),
  high(0.95, 300, 'Chất lượng cao (300 DPI, nén 95%)');

  final double jpegQuality;
  final int targetDpi;
  final String label;

  const ScanOutputQuality(this.jpegQuality, this.targetDpi, this.label);
}

/// Preset filter modes for image cleanup.
enum EnhancementPreset {
  original('Gốc'),
  document('Tài liệu văn phòng'),
  cleanScan('Quét sạch nền'),
  blackAndWhite('Trắng đen rõ nét'),
  photo('Ảnh chụp tự nhiên');

  final String label;
  const EnhancementPreset(this.label);
}

/// Options controlling non-destructive visual enhancement for a page.
class ScanProcessingOptions {
  final EnhancementPreset preset;
  final bool autoEnhance;
  final bool grayscale;
  final bool blackAndWhite;
  final double contrast; // 1.0 = normal, 1.2 = enhanced
  final double brightness; // 1.0 = normal
  final bool sharpen;
  final bool denoise;
  final bool cleanBackground;
  final bool deskew;
  final bool autoCrop;
  final int rotationDegrees; // 0, 90, 180, 270

  const ScanProcessingOptions({
    this.preset = EnhancementPreset.document,
    this.autoEnhance = true,
    this.grayscale = false,
    this.blackAndWhite = false,
    this.contrast = 1.15,
    this.brightness = 1.02,
    this.sharpen = false,
    this.denoise = false,
    this.cleanBackground = true,
    this.deskew = true,
    this.autoCrop = true,
    this.rotationDegrees = 0,
  });

  ScanProcessingOptions copyWith({
    EnhancementPreset? preset,
    bool? autoEnhance,
    bool? grayscale,
    bool? blackAndWhite,
    double? contrast,
    double? brightness,
    bool? sharpen,
    bool? denoise,
    bool? cleanBackground,
    bool? deskew,
    bool? autoCrop,
    int? rotationDegrees,
  }) {
    return ScanProcessingOptions(
      preset: preset ?? this.preset,
      autoEnhance: autoEnhance ?? this.autoEnhance,
      grayscale: grayscale ?? this.grayscale,
      blackAndWhite: blackAndWhite ?? this.blackAndWhite,
      contrast: contrast ?? this.contrast,
      brightness: brightness ?? this.brightness,
      sharpen: sharpen ?? this.sharpen,
      denoise: denoise ?? this.denoise,
      cleanBackground: cleanBackground ?? this.cleanBackground,
      deskew: deskew ?? this.deskew,
      autoCrop: autoCrop ?? this.autoCrop,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
    );
  }

  Map<String, dynamic> toJson() => {
        'preset': preset.name,
        'autoEnhance': autoEnhance,
        'grayscale': grayscale,
        'blackAndWhite': blackAndWhite,
        'contrast': contrast,
        'brightness': brightness,
        'sharpen': sharpen,
        'denoise': denoise,
        'cleanBackground': cleanBackground,
        'deskew': deskew,
        'autoCrop': autoCrop,
        'rotationDegrees': rotationDegrees,
      };

  factory ScanProcessingOptions.fromJson(Map<String, dynamic> json) => ScanProcessingOptions(
        preset: EnhancementPreset.values.firstWhere(
          (e) => e.name == json['preset'],
          orElse: () => EnhancementPreset.document,
        ),
        autoEnhance: json['autoEnhance'] as bool? ?? true,
        grayscale: json['grayscale'] as bool? ?? false,
        blackAndWhite: json['blackAndWhite'] as bool? ?? false,
        contrast: (json['contrast'] as num?)?.toDouble() ?? 1.15,
        brightness: (json['brightness'] as num?)?.toDouble() ?? 1.02,
        sharpen: json['sharpen'] as bool? ?? false,
        denoise: json['denoise'] as bool? ?? false,
        cleanBackground: json['cleanBackground'] as bool? ?? true,
        deskew: json['deskew'] as bool? ?? true,
        autoCrop: json['autoCrop'] as bool? ?? true,
        rotationDegrees: (json['rotationDegrees'] as num?)?.toInt() ?? 0,
      );
}

/// Options controlling final export of a scan session.
class ScanOutputOptions {
  final ScanOutputFormat format;
  final String outputPath;
  final ScanOutputQuality quality;
  final bool enableOcr;
  final String ocrLanguage; // 'vie', 'eng', 'vie+eng'
  final bool allowFallbackLanguage;
  final List<int>? pageIndices; // null = all pages

  const ScanOutputOptions({
    required this.format,
    required this.outputPath,
    this.quality = ScanOutputQuality.balanced,
    this.enableOcr = true,
    this.ocrLanguage = 'vie',
    this.allowFallbackLanguage = false,
    this.pageIndices,
  });

  Map<String, dynamic> toJson() => {
        'format': format.name,
        'outputPath': outputPath,
        'quality': quality.name,
        'enableOcr': enableOcr,
        'ocrLanguage': ocrLanguage,
        'allowFallbackLanguage': allowFallbackLanguage,
        'pageIndices': pageIndices,
      };
}
