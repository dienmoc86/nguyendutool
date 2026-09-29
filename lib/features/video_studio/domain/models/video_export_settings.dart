import 'audio_ducking_level.dart';

/// Video aspect ratio presets.
enum VideoAspectRatio {
  widescreen16x9('16:9', 16 / 9, 'Ngang chuẩn (16:9 - Bài giảng / YouTube)'),
  vertical9x16('9:16', 9 / 16, 'Dọc di động (9:16 - Short / TikTok / Reel)'),
  square1x1('1:1', 1.0, 'Vuông (1:1 - Mạng xã hội / Slide)'),
  standard4x3('4:3', 4 / 3, 'Trình chiếu chuẩn (4:3 - Máy chiếu trường học)');

  final String ratioString;
  final double value;
  final String displayName;

  const VideoAspectRatio(this.ratioString, this.value, this.displayName);
}

/// Output video resolution presets.
enum VideoResolution {
  res720p(1280, 720, '720p HD (1280x720) - Xuất nhanh'),
  res1080p(1920, 1080, '1080p Full HD (1920x1080) - Tiêu chuẩn cao'),
  res2160p(3840, 2160, '4K Ultra HD (3840x2160) - Yêu cầu cấu hình mạnh');

  final int width;
  final int height;
  final String displayName;

  const VideoResolution(this.width, this.height, this.displayName);

  /// Computes target width and height taking aspect ratio into account.
  (int, int) getDimensionsFor(VideoAspectRatio ratio) {
    switch (ratio) {
      case VideoAspectRatio.widescreen16x9:
        return (width, height);
      case VideoAspectRatio.vertical9x16:
        return (height, width);
      case VideoAspectRatio.square1x1:
        return (height, height);
      case VideoAspectRatio.standard4x3:
        final calcWidth = (height * 4 / 3).round();
        return (calcWidth % 2 == 0 ? calcWidth : calcWidth + 1, height);
    }
  }
}

/// Encoding quality preset.
enum ExportQuality {
  draft(crf: 28, preset: 'veryfast', audioBitrateKbps: 128, displayName: 'Bản nháp (Draft - Nhanh)'),
  standard(crf: 23, preset: 'medium', audioBitrateKbps: 192, displayName: 'Tiêu chuẩn (Standard - Cân bằng)'),
  highQuality(crf: 18, preset: 'slow', audioBitrateKbps: 320, displayName: 'Chất lượng cao (High Quality - Nét nhất)');

  final int crf;
  final String preset;
  final int audioBitrateKbps;
  final String displayName;

  const ExportQuality({
    required this.crf,
    required this.preset,
    required this.audioBitrateKbps,
    required this.displayName,
  });
}

/// Hardware encoder preferences.
enum HardwareEncoderMode {
  auto('Tự động phát hiện (Ưu tiên phần cứng, tự chuyển CPU nếu lỗi)'),
  softwareOnly('Phần mềm CPU (libx264 - Ổn định tuyệt đối)'),
  nvenc('Nvidia NVENC (h264_nvenc)'),
  qsv('Intel QuickSync (h264_qsv)'),
  amf('AMD AMF (h264_amf)');

  final String displayName;
  const HardwareEncoderMode(this.displayName);
}

/// Watermark corner positions.
enum WatermarkPosition {
  topRight('Góc trên bên phải'),
  topLeft('Góc trên bên trái'),
  bottomRight('Góc dưới bên phải'),
  bottomLeft('Góc dưới bên trái');

  final String displayName;
  const WatermarkPosition(this.displayName);
}

/// Comprehensive export settings for FFmpeg rendering pipeline.
class VideoExportSettings {
  final VideoResolution resolution;
  final VideoAspectRatio aspectRatio;
  final int fps; // 24, 25, 30, 60
  final ExportQuality quality;
  final HardwareEncoderMode hardwareEncoder;
  final bool burnSubtitles;
  final AudioDuckingLevel duckingLevel;
  final double backgroundMusicVolume; // 0.0 to 1.5
  final double voiceoverVolume; // 0.0 to 2.0
  final String? watermarkPath;
  final WatermarkPosition watermarkPosition;
  final double watermarkOpacity; // 0.1 to 1.0
  final int watermarkMargin; // pixels
  final String? customOutputDirectory;

  const VideoExportSettings({
    this.resolution = VideoResolution.res1080p,
    this.aspectRatio = VideoAspectRatio.widescreen16x9,
    this.fps = 30,
    this.quality = ExportQuality.standard,
    this.hardwareEncoder = HardwareEncoderMode.auto,
    this.burnSubtitles = true,
    this.duckingLevel = AudioDuckingLevel.medium,
    this.backgroundMusicVolume = 0.35,
    this.voiceoverVolume = 1.0,
    this.watermarkPath,
    this.watermarkPosition = WatermarkPosition.topRight,
    this.watermarkOpacity = 0.8,
    this.watermarkMargin = 32,
    this.customOutputDirectory,
  });

  Map<String, dynamic> toJson() => {
        'resolution': resolution.name,
        'aspectRatio': aspectRatio.name,
        'fps': fps,
        'quality': quality.name,
        'hardwareEncoder': hardwareEncoder.name,
        'burnSubtitles': burnSubtitles,
        'duckingLevel': duckingLevel.name,
        'backgroundMusicVolume': backgroundMusicVolume,
        'voiceoverVolume': voiceoverVolume,
        'watermarkPath': watermarkPath,
        'watermarkPosition': watermarkPosition.name,
        'watermarkOpacity': watermarkOpacity,
        'watermarkMargin': watermarkMargin,
        'customOutputDirectory': customOutputDirectory,
      };

  factory VideoExportSettings.fromJson(Map<String, dynamic> json) => VideoExportSettings(
        resolution: VideoResolution.values.firstWhere(
          (r) => r.name == json['resolution'],
          orElse: () => VideoResolution.res1080p,
        ),
        aspectRatio: VideoAspectRatio.values.firstWhere(
          (a) => a.name == json['aspectRatio'],
          orElse: () => VideoAspectRatio.widescreen16x9,
        ),
        fps: json['fps'] as int? ?? 30,
        quality: ExportQuality.values.firstWhere(
          (q) => q.name == json['quality'],
          orElse: () => ExportQuality.standard,
        ),
        hardwareEncoder: HardwareEncoderMode.values.firstWhere(
          (h) => h.name == json['hardwareEncoder'],
          orElse: () => HardwareEncoderMode.auto,
        ),
        burnSubtitles: json['burnSubtitles'] as bool? ?? true,
        duckingLevel: AudioDuckingLevel.values.firstWhere(
          (d) => d.name == json['duckingLevel'],
          orElse: () => AudioDuckingLevel.medium,
        ),
        backgroundMusicVolume: (json['backgroundMusicVolume'] as num?)?.toDouble() ?? 0.35,
        voiceoverVolume: (json['voiceoverVolume'] as num?)?.toDouble() ?? 1.0,
        watermarkPath: json['watermarkPath'] as String?,
        watermarkPosition: WatermarkPosition.values.firstWhere(
          (w) => w.name == json['watermarkPosition'],
          orElse: () => WatermarkPosition.topRight,
        ),
        watermarkOpacity: (json['watermarkOpacity'] as num?)?.toDouble() ?? 0.8,
        watermarkMargin: json['watermarkMargin'] as int? ?? 32,
        customOutputDirectory: json['customOutputDirectory'] as String?,
      );
}
