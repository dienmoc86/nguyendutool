/// Origin/source of capability values reported for a scanner device.
enum CapabilitySource {
  reportedByDevice,
  inferredDefault,
  unknown;

  String get label {
    switch (this) {
      case CapabilitySource.reportedByDevice:
        return 'Thiết bị báo cáo';
      case CapabilitySource.inferredDefault:
        return 'Mặc định suy luận';
      case CapabilitySource.unknown:
        return 'Chưa xác định';
    }
  }
}

/// Capability descriptor for a hardware scanner device.
class ScannerCapability {
  final List<int> supportedDpis;
  final List<String> supportedColorModes;
  final bool supportsFlatbed;
  final bool supportsAdf;
  final bool supportsDuplex;
  final List<String> supportedPaperSizes;
  final CapabilitySource capabilitySource;

  const ScannerCapability({
    this.supportedDpis = const [75, 100, 150, 200, 300, 600],
    this.supportedColorModes = const ['color', 'grayscale', 'bw'],
    this.supportsFlatbed = true,
    this.supportsAdf = false,
    this.supportsDuplex = false,
    this.supportedPaperSizes = const ['A4', 'Letter', 'Auto'],
    this.capabilitySource = CapabilitySource.inferredDefault,
  });

  Map<String, dynamic> toJson() => {
        'supportedDpis': supportedDpis,
        'supportedColorModes': supportedColorModes,
        'supportsFlatbed': supportsFlatbed,
        'supportsAdf': supportsAdf,
        'supportsDuplex': supportsDuplex,
        'supportedPaperSizes': supportedPaperSizes,
        'capabilitySource': capabilitySource.name,
      };

  factory ScannerCapability.fromJson(Map<String, dynamic> json) => ScannerCapability(
        supportedDpis: (json['supportedDpis'] as List<dynamic>?)?.map((e) => e as int).toList() ??
            const [75, 100, 150, 200, 300, 600],
        supportedColorModes:
            (json['supportedColorModes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
                const ['color', 'grayscale', 'bw'],
        supportsFlatbed: json['supportsFlatbed'] as bool? ?? true,
        supportsAdf: json['supportsAdf'] as bool? ?? false,
        supportsDuplex: json['supportsDuplex'] as bool? ?? false,
        supportedPaperSizes:
            (json['supportedPaperSizes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
                const ['A4', 'Letter', 'Auto'],
        capabilitySource: json['capabilitySource'] != null
            ? CapabilitySource.values.firstWhere(
                (e) => e.name == json['capabilitySource'],
                orElse: () => CapabilitySource.inferredDefault,
              )
            : CapabilitySource.inferredDefault,
      );
}

/// Information about an attached physical scanner device discovered via WIA or TWAIN.
class ScannerDevice {
  final String id;
  final String name;
  final String? manufacturer;
  final String? connectionType;
  final ScannerCapability capabilities;

  const ScannerDevice({
    required this.id,
    required this.name,
    this.manufacturer,
    this.connectionType,
    this.capabilities = const ScannerCapability(),
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'manufacturer': manufacturer,
        'connectionType': connectionType,
        'capabilities': capabilities.toJson(),
      };

  factory ScannerDevice.fromJson(Map<String, dynamic> json) => ScannerDevice(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Máy quét chưa xác định',
        manufacturer: json['manufacturer'] as String?,
        connectionType: json['connectionType'] as String?,
        capabilities: json['capabilities'] != null
            ? ScannerCapability.fromJson(json['capabilities'] as Map<String, dynamic>)
            : const ScannerCapability(),
      );

  @override
  String toString() => '$name ($manufacturer, $connectionType)';
}
