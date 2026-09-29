/// Scanning preset configuration profile.
class ScanProfile {
  final String id;
  final String name;
  final int dpi;
  final String colorMode; // 'color', 'grayscale', 'bw'
  final String source; // 'flatbed', 'adf'
  final String paperSize; // 'a4', 'letter', 'auto'
  final bool autoCrop;
  final bool deskew;
  final bool contrastNormalize;
  final bool isPreset;

  const ScanProfile({
    required this.id,
    required this.name,
    this.dpi = 300,
    this.colorMode = 'color',
    this.source = 'flatbed',
    this.paperSize = 'a4',
    this.autoCrop = true,
    this.deskew = true,
    this.contrastNormalize = true,
    this.isPreset = false,
  });

  static const ScanProfile documentStandard = ScanProfile(
    id: 'profile_doc_std',
    name: 'Tài liệu tiêu chuẩn',
    dpi: 200,
    colorMode: 'color',
    source: 'flatbed',
    paperSize: 'a4',
    autoCrop: true,
    deskew: true,
    contrastNormalize: true,
    isPreset: true,
  );

  static const ScanProfile documentHighQuality = ScanProfile(
    id: 'profile_doc_hq',
    name: 'Tài liệu chất lượng cao',
    dpi: 300,
    colorMode: 'color',
    source: 'flatbed',
    paperSize: 'a4',
    autoCrop: true,
    deskew: true,
    contrastNormalize: true,
    isPreset: true,
  );

  static const ScanProfile photo = ScanProfile(
    id: 'profile_photo',
    name: 'Ảnh chụp (Photo)',
    dpi: 600,
    colorMode: 'color',
    source: 'flatbed',
    paperSize: 'auto',
    autoCrop: false,
    deskew: false,
    contrastNormalize: false,
    isPreset: true,
  );

  static const ScanProfile blackAndWhite = ScanProfile(
    id: 'profile_bw',
    name: 'Đơn sắc (Trắng đen)',
    dpi: 300,
    colorMode: 'bw',
    source: 'flatbed',
    paperSize: 'a4',
    autoCrop: true,
    deskew: true,
    contrastNormalize: true,
    isPreset: true,
  );

  static const ScanProfile ocrOptimized = ScanProfile(
    id: 'profile_ocr_opt',
    name: 'Tối ưu OCR',
    dpi: 300,
    colorMode: 'grayscale',
    source: 'flatbed',
    paperSize: 'a4',
    autoCrop: true,
    deskew: true,
    contrastNormalize: true,
    isPreset: true,
  );

  static const List<ScanProfile> defaultProfiles = [
    documentStandard,
    documentHighQuality,
    photo,
    blackAndWhite,
    ocrOptimized,
  ];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dpi': dpi,
        'colorMode': colorMode,
        'source': source,
        'paperSize': paperSize,
        'autoCrop': autoCrop,
        'deskew': deskew,
        'contrastNormalize': contrastNormalize,
        'isPreset': isPreset,
      };

  factory ScanProfile.fromJson(Map<String, dynamic> json) => ScanProfile(
        id: json['id'] as String? ?? 'profile_custom',
        name: json['name'] as String? ?? 'Tùy chỉnh',
        dpi: (json['dpi'] as num?)?.toInt() ?? 300,
        colorMode: json['colorMode'] as String? ?? 'color',
        source: json['source'] as String? ?? 'flatbed',
        paperSize: json['paperSize'] as String? ?? 'a4',
        autoCrop: json['autoCrop'] == 1 || json['autoCrop'] == true,
        deskew: json['deskew'] == 1 || json['deskew'] == true,
        contrastNormalize: json['contrastNormalize'] == 1 || json['contrastNormalize'] == true,
        isPreset: json['isPreset'] == 1 || json['isPreset'] == true,
      );
}
