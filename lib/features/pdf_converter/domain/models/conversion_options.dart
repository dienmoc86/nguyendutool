/// Desired output format for conversion.
enum OutputFormat {
  docx,
  xlsx,
  pptx,
  both,
  all;

  String get label {
    switch (this) {
      case OutputFormat.docx:
        return 'Giáo án / Văn bản Word (.docx)';
      case OutputFormat.xlsx:
        return 'Bảng điểm / Sổ sách Excel (.xlsx)';
      case OutputFormat.pptx:
        return 'Bài giảng trình chiếu PowerPoint (.pptx)';
      case OutputFormat.both:
        return 'Cả Word & Excel (.docx & .xlsx)';
      case OutputFormat.all:
        return 'Tất cả định dạng (.docx, .xlsx, .pptx)';
    }
  }

  String get extensionLabel {
    switch (this) {
      case OutputFormat.docx:
        return '.docx';
      case OutputFormat.xlsx:
        return '.xlsx';
      case OutputFormat.pptx:
        return '.pptx';
      case OutputFormat.both:
        return '.docx + .xlsx';
      case OutputFormat.all:
        return '.docx + .xlsx + .pptx';
    }
  }
}

/// OCR Language selection.
enum OcrLanguage {
  vietnamese,
  english,
  bilingual;

  String get code {
    switch (this) {
      case OcrLanguage.vietnamese:
        return 'vie';
      case OcrLanguage.english:
        return 'eng';
      case OcrLanguage.bilingual:
        return 'vie+eng';
    }
  }

  String get label {
    switch (this) {
      case OcrLanguage.vietnamese:
        return 'Tiếng Việt';
      case OcrLanguage.english:
        return 'English';
      case OcrLanguage.bilingual:
        return 'Song ngữ (Việt - Anh)';
    }
  }
}

/// Rendering resolution preset for PDF to Image conversion prior to OCR.
enum DpiPreset {
  standard150,
  high200,
  ultra300;

  int get dpiValue {
    switch (this) {
      case DpiPreset.standard150:
        return 150;
      case DpiPreset.high200:
        return 200;
      case DpiPreset.ultra300:
        return 300;
    }
  }

  String get label {
    switch (this) {
      case DpiPreset.standard150:
        return '150 DPI (Nhanh, tài liệu thường)';
      case DpiPreset.high200:
        return '200 DPI (Cân bằng - Khuyên dùng)';
      case DpiPreset.ultra300:
        return '300 DPI (Chi tiết cao, bảng biểu nhỏ)';
    }
  }
}

/// User options for configuring the conversion process.
class ConversionOptions {
  final OutputFormat format;
  final OcrLanguage language;
  final DpiPreset dpi;
  final bool autoDeskew;
  final bool autoEnhance;
  final bool detectTables;
  final bool preserveFormatting;

  const ConversionOptions({
    this.format = OutputFormat.docx,
    this.language = OcrLanguage.vietnamese,
    this.dpi = DpiPreset.high200,
    this.autoDeskew = true,
    this.autoEnhance = true,
    this.detectTables = true,
    this.preserveFormatting = true,
  });

  ConversionOptions copyWith({
    OutputFormat? format,
    OcrLanguage? language,
    DpiPreset? dpi,
    bool? autoDeskew,
    bool? autoEnhance,
    bool? detectTables,
    bool? preserveFormatting,
  }) {
    return ConversionOptions(
      format: format ?? this.format,
      language: language ?? this.language,
      dpi: dpi ?? this.dpi,
      autoDeskew: autoDeskew ?? this.autoDeskew,
      autoEnhance: autoEnhance ?? this.autoEnhance,
      detectTables: detectTables ?? this.detectTables,
      preserveFormatting: preserveFormatting ?? this.preserveFormatting,
    );
  }

  Map<String, dynamic> toJson() => {
    'format': format.name,
    'language': language.name,
    'dpi': dpi.name,
    'autoDeskew': autoDeskew,
    'autoEnhance': autoEnhance,
    'detectTables': detectTables,
    'preserveFormatting': preserveFormatting,
  };

  factory ConversionOptions.fromJson(Map<String, dynamic> json) => ConversionOptions(
    format: OutputFormat.values.firstWhere(
      (e) => e.name == json['format'],
      orElse: () => OutputFormat.docx,
    ),
    language: OcrLanguage.values.firstWhere(
      (e) => e.name == json['language'],
      orElse: () => OcrLanguage.vietnamese,
    ),
    dpi: DpiPreset.values.firstWhere(
      (e) => e.name == json['dpi'],
      orElse: () => DpiPreset.high200,
    ),
    autoDeskew: json['autoDeskew'] as bool? ?? true,
    autoEnhance: json['autoEnhance'] as bool? ?? true,
    detectTables: json['detectTables'] as bool? ?? true,
    preserveFormatting: json['preserveFormatting'] as bool? ?? true,
  );
}
