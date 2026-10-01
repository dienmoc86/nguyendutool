import 'package:ilocal_client/ilocal_client.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/pdf_converter/infrastructure/vietnamese_ocr_engine.dart';
import '../../features/scanner/infrastructure/windows_wia_scanner_provider.dart';
import '../../features/text_to_speech/infrastructure/windows_speech_synthesizer_provider.dart';
import '../logging/app_logger.dart';
import '../media/ffmpeg_service.dart';
import '../security/credential_service.dart';
import '../security/windows_dpapi_secure_storage.dart';
import 'app_capability.dart';
import 'capability_availability.dart';

/// Central registry managing all system and functional capabilities.
///
/// Modules query this registry to determine whether prerequisites are met,
/// enabling graceful degradation and honest error reporting without crashing.
class CapabilityRegistry {
  static final CapabilityRegistry instance = CapabilityRegistry._internal();

  static const String capAiTextGenerate = 'ai.text.generate';
  static const String capAiGeminiTextGenerate = 'ai.gemini.text.generate';
  static const String capAiOpenAiTextGenerate = 'ai.openai.text.generate';
  static const String capAiLocalTextGenerate = 'ai.local.text.generate';

  final Map<String, AppCapability> _cache = {};
  bool _isProbing = false;

  CapabilityRegistry._internal() {
    _initDefaultState();
  }

  void _initDefaultState() {
    // 1. Static capabilities guaranteed by bundled app code
    _registerDefault(const AppCapability(
      id: 'document.pdf.read',
      displayName: 'Đọc & Phân tích PDF',
      description: 'Trích xuất văn bản số, hình ảnh và trang từ tệp PDF.',
      availability: CapabilityAvailability.available,
      provider: 'Syncfusion / ISO 32000 Engine',
    ));

    _registerDefault(const AppCapability(
      id: 'document.pdf.write',
      displayName: 'Tạo tệp PDF Searchable',
      description: 'Biên tập và xuất tệp PDF nhị phân với lớp văn bản tra cứu được.',
      availability: CapabilityAvailability.available,
      provider: 'Syncfusion / ISO 32000 Engine',
    ));

    _registerDefault(const AppCapability(
      id: 'document.docx.write',
      displayName: 'Xuất văn bản Word (.docx)',
      description: 'Tạo tài liệu Microsoft Word thuần OpenXML ECMA-376 không cần cài Office.',
      availability: CapabilityAvailability.available,
      provider: 'Archive / OpenXML Engine',
    ));

    _registerDefault(const AppCapability(
      id: 'document.xlsx.write',
      displayName: 'Xuất bảng tính Excel (.xlsx)',
      description: 'Tạo bảng tính Microsoft Excel từ dữ liệu bảng biểu nhận diện.',
      availability: CapabilityAvailability.available,
      provider: 'Archive / OpenXML Engine',
    ));

    // 2. OCR Capabilities (Initial: unknown, probed at runtime)
    _registerDefault(const AppCapability(
      id: 'document.ocr',
      displayName: 'Nhận diện quang học OCR Tiếng Việt',
      description: 'Nhận diện chữ in từ tài liệu quét, ảnh chụp sách và đề thi.',
      availability: CapabilityAvailability.unknown,
      provider: 'Windows Media OCR / WinRT',
    ));

    _registerDefault(const AppCapability(
      id: 'document.ocr.engine',
      displayName: 'Động cơ Windows Media OCR',
      description: 'Động cơ WinRT OCR của hệ điều hành Windows.',
      availability: CapabilityAvailability.unknown,
      provider: 'Windows.Media.Ocr.OcrEngine',
    ));

    _registerDefault(const AppCapability(
      id: 'document.ocr.vi_language',
      displayName: 'Gói ngôn ngữ OCR Tiếng Việt',
      description: 'Gói nhận dạng ký tự tiếng Việt (vi-VN) trong Windows OCR.',
      availability: CapabilityAvailability.unknown,
      provider: 'Windows OCR Language Pack',
    ));

    // 3. TTS Capabilities (Initial: unknown, probed at runtime)
    _registerDefault(const AppCapability(
      id: 'media.tts',
      displayName: 'Giọng đọc Tiếng Việt Ngoại tuyến',
      description: 'Tổng hợp giọng nói tiếng Việt tự nhiên qua Windows SAPI & OneCore.',
      availability: CapabilityAvailability.unknown,
      provider: 'Windows Speech API (SAPI / OneCore)',
    ));

    _registerDefault(const AppCapability(
      id: 'media.tts.engine',
      displayName: 'Động cơ giọng đọc Windows SAPI/OneCore',
      description: 'Hệ thống tổng hợp âm thanh giọng nói của Windows.',
      availability: CapabilityAvailability.unknown,
      provider: 'Windows Speech Synthesizer',
    ));

    _registerDefault(const AppCapability(
      id: 'media.tts.vi_voice',
      displayName: 'Giọng đọc Tiếng Việt cài đặt sẵn',
      description: 'Giọng đọc tiếng Việt (An / Nam / Mai / vi-VN) được cài trong Windows.',
      availability: CapabilityAvailability.unknown,
      provider: 'Windows SAPI / OneCore Vietnamese Voice',
    ));

    // 4. Media & Video rendering capabilities
    _registerDefault(const AppCapability(
      id: 'media.ffmpeg',
      displayName: 'Động cơ FFmpeg & FFprobe',
      description: 'Xử lý video, audio, nén âm thanh và ghép phụ đề.',
      availability: CapabilityAvailability.unknown,
      provider: 'FFmpeg 8.0.1 Tích hợp',
    ));

    _registerDefault(const AppCapability(
      id: 'media.video.render',
      displayName: 'Xưởng dựng Video E-Learning',
      description: 'Kết xuất video MP4 bài giảng đa lớp với hiệu ứng chuyển cảnh.',
      availability: CapabilityAvailability.unknown,
      provider: 'NguyenDu Video Compositor',
    ));

    // 5. WIA Scanner Capabilities (Initial: unknown, probed at runtime)
    _registerDefault(const AppCapability(
      id: 'scanner.wia',
      displayName: 'Giao tiếp Máy quét (WIA 2.0)',
      description: 'Kết nối và điều khiển máy scan tài liệu phẳng chuẩn Windows WIA.',
      availability: CapabilityAvailability.unknown,
      provider: 'Windows Image Acquisition (WIA)',
    ));

    _registerDefault(const AppCapability(
      id: 'scanner.wia.service',
      displayName: 'Dịch vụ Windows Image Acquisition (WIA)',
      description: 'Dịch vụ nền WIA hệ điều hành Windows phục vụ kết nối thiết bị quét.',
      availability: CapabilityAvailability.unknown,
      provider: 'Windows WIA Service (stisvc)',
    ));

    _registerDefault(const AppCapability(
      id: 'scanner.wia.device',
      displayName: 'Thiết bị Máy quét kết nối thực tế',
      description: 'Máy quét tài liệu vật lý kết nối qua USB/mạng cục bộ.',
      availability: CapabilityAvailability.unknown,
      provider: 'WIA Device Manager',
    ));

    // 6. Security DPAPI (Initial: unknown, probed at runtime)
    _registerDefault(const AppCapability(
      id: 'security.dpapi',
      displayName: 'Bảo mật khoá & mã hóa DPAPI',
      description: 'Mã hóa khóa API và thông tin nhạy cảm ở cấp độ người dùng Windows.',
      availability: CapabilityAvailability.unknown,
      provider: 'Windows CryptProtectData (DPAPI)',
    ));

    // 7. AI Text Generation Capabilities
    _registerDefault(const AppCapability(
      id: capAiLocalTextGenerate,
      displayName: 'iLocal AI Shared Core (Ngoại tuyến)',
      description: 'Hạ tầng AI cục bộ chạy offline, bảo mật tuyệt đối, hỗ trợ GPU NVIDIA cho soạn bài và RAG.',
      availability: CapabilityAvailability.unknown,
      provider: 'iLocal AI Runtime (Port 18181)',
    ));
    _registerDefault(const AppCapability(
      id: 'ai.gemini.text.generate',
      displayName: 'Google Gemini AI',
      description: 'Hỗ trợ soạn giáo án và sinh nội dung học tập qua Google Gemini API.',
      availability: CapabilityAvailability.notConfigured,
      provider: 'Google Gemini REST API',
      reason: 'Chưa cấu hình Google Gemini API Key trong Cài đặt.',
    ));

    _registerDefault(const AppCapability(
      id: 'ai.openai.text.generate',
      displayName: 'OpenAI API (Đang phát triển)',
      description: 'Hỗ trợ OpenAI GPT đang phát triển trong các bản cập nhật sau.',
      availability: CapabilityAvailability.unavailable,
      provider: 'OpenAI REST API',
      reason: 'Chưa hỗ trợ kết nối OpenAI trong phiên bản này. Vui lòng sử dụng Google Gemini.',
    ));

    _registerDefault(const AppCapability(
      id: 'ai.text.generate',
      displayName: 'Trí tuệ nhân tạo (AI Text Generation)',
      description: 'Hỗ trợ soạn giáo án và sinh nội dung học tập qua Google Gemini API.',
      availability: CapabilityAvailability.notConfigured,
      provider: 'Google Gemini REST API',
      reason: 'Chưa cấu hình Google Gemini API Key trong Cài đặt.',
    ));
  }

  void _registerDefault(AppCapability cap) {
    _cache[cap.id] = cap;
  }

  /// Returns a capability by ID
  AppCapability? getCapability(String id) => _cache[id];

  /// Lists all registered capabilities
  List<AppCapability> listCapabilities() => _cache.values.toList();

  /// Quick check whether a capability is available or degraded (usable)
  bool isAvailable(String id) {
    final cap = _cache[id];
    return cap != null && cap.isAvailable;
  }

  /// Sets capability for testing or manual override
  void setCapability(AppCapability cap) {
    _cache[cap.id] = cap;
  }

  /// Asynchronously probes all runtime capabilities against real system diagnostics
  Future<void> refreshAll({bool force = false}) async {
    if (_isProbing) return;
    _isProbing = true;

    try {
      final now = DateTime.now();

      // 1. Probe FFmpeg
      try {
        final ffmpeg = FfmpegService.instance;
        final ok = await ffmpeg.initialize(forceReinitialize: force);
        _cache['media.ffmpeg'] = AppCapability(
          id: 'media.ffmpeg',
          displayName: 'Động cơ FFmpeg & FFprobe',
          description: 'Xử lý video, audio, nén âm thanh và ghép phụ đề.',
          availability: ok ? CapabilityAvailability.available : CapabilityAvailability.unavailable,
          provider: ffmpeg.originLabel,
          reason: ok ? 'Đã tìm thấy FFmpeg tại ${ffmpeg.binaryPath}' : 'Không tìm thấy binary ffmpeg.exe',
          lastChecked: now,
        );

        _cache['media.video.render'] = AppCapability(
          id: 'media.video.render',
          displayName: 'Xưởng dựng Video E-Learning',
          description: 'Kết xuất video MP4 bài giảng đa lớp với hiệu ứng chuyển cảnh.',
          availability: ok ? CapabilityAvailability.available : CapabilityAvailability.degraded,
          provider: 'NguyenDu Video Compositor',
          reason: ok ? 'Sẵn sàng dựng video MP4' : 'Cần cài đặt hoặc kiểm tra FFmpeg',
          lastChecked: now,
        );
      } catch (e) {
        AppLogger.warning('Capability probe error for FFmpeg: $e');
        _cache['media.ffmpeg'] = AppCapability(
          id: 'media.ffmpeg',
          displayName: 'Động cơ FFmpeg & FFprobe',
          description: 'Xử lý video, audio, nén âm thanh và ghép phụ đề.',
          availability: CapabilityAvailability.unavailable,
          provider: 'FFmpeg 8.0.1 Tích hợp',
          reason: 'Lỗi khởi tạo FFmpeg: $e',
          lastChecked: now,
        );
      }

      // 2. Probe Windows DPAPI via real in-memory encrypt/decrypt roundtrip
      try {
        if (!Platform.isWindows) {
          _cache['security.dpapi'] = AppCapability(
            id: 'security.dpapi',
            displayName: 'Bảo mật khoá & mã hóa DPAPI',
            description: 'Mã hóa khóa API ở cấp độ người dùng Windows.',
            availability: CapabilityAvailability.unavailable,
            provider: 'Windows CryptProtectData (DPAPI)',
            reason: 'Chỉ hỗ trợ hệ điều hành Windows.',
            lastChecked: now,
          );
        } else {
          final storage = WindowsDpapiSecureStorage();
          final roundtripOk = storage.probeRoundtrip();
          _cache['security.dpapi'] = AppCapability(
            id: 'security.dpapi',
            displayName: 'Bảo mật khoá & mã hóa DPAPI',
            description: 'Mã hóa khóa API và thông tin nhạy cảm qua Windows DPAPI.',
            availability: roundtripOk ? CapabilityAvailability.available : CapabilityAvailability.unavailable,
            provider: 'Windows CryptProtectData (DPAPI)',
            reason: roundtripOk
                ? 'Thử nghiệm mã hóa & giải mã DPAPI thành công.'
                : 'Thử nghiệm gọi hàm CryptProtectData thất bại.',
            lastChecked: now,
          );
        }
      } catch (e) {
        AppLogger.warning('Capability probe error for DPAPI: $e');
        _cache['security.dpapi'] = AppCapability(
          id: 'security.dpapi',
          displayName: 'Bảo mật khoá & mã hóa DPAPI',
          description: 'Mã hóa khóa API và thông tin nhạy cảm qua Windows DPAPI.',
          availability: CapabilityAvailability.unavailable,
          provider: 'Windows CryptProtectData (DPAPI)',
          reason: 'Lỗi kiểm tra DPAPI: $e',
          lastChecked: now,
        );
      }

      // 3. Probe TTS (Engine & Vietnamese voice count)
      try {
        if (!Platform.isWindows) {
          _cache['media.tts.engine'] = AppCapability(
            id: 'media.tts.engine',
            displayName: 'Động cơ giọng đọc Windows SAPI/OneCore',
            description: 'Động cơ giọng đọc Windows.',
            availability: CapabilityAvailability.unavailable,
            provider: 'Windows Speech Synthesizer',
            reason: 'Chỉ hỗ trợ hệ điều hành Windows.',
            lastChecked: now,
          );
          _cache['media.tts.vi_voice'] = AppCapability(
            id: 'media.tts.vi_voice',
            displayName: 'Giọng đọc Tiếng Việt cài đặt sẵn',
            description: 'Gói giọng đọc tiếng Việt.',
            availability: CapabilityAvailability.unavailable,
            provider: 'Windows Vietnamese Voice',
            reason: 'Chỉ hỗ trợ hệ điều hành Windows.',
            lastChecked: now,
          );
          _cache['media.tts'] = AppCapability(
            id: 'media.tts',
            displayName: 'Giọng đọc Tiếng Việt Ngoại tuyến',
            description: 'Tổng hợp giọng nói tiếng Việt tự nhiên qua Windows SAPI & OneCore.',
            availability: CapabilityAvailability.unavailable,
            provider: 'Windows Speech API',
            reason: 'Chỉ hỗ trợ hệ điều hành Windows.',
            lastChecked: now,
          );
        } else {
          final ttsProvider = WindowsSpeechSynthesizerProvider();
          final initialized = await ttsProvider.initialize();
          final voiceCount = ttsProvider.voices.length;
          final hasViVoice = ttsProvider.hasVietnameseVoice;

          _cache['media.tts.engine'] = AppCapability(
            id: 'media.tts.engine',
            displayName: 'Động cơ giọng đọc Windows SAPI/OneCore',
            description: 'Hệ thống tổng hợp âm thanh giọng nói của Windows.',
            availability: (initialized && voiceCount > 0)
                ? CapabilityAvailability.available
                : CapabilityAvailability.unavailable,
            provider: 'Windows SAPI 5.4 / OneCore',
            reason: initialized ? 'Tìm thấy $voiceCount giọng đọc đã cài đặt.' : 'Không thể khởi tạo SAPI.',
            lastChecked: now,
          );

          _cache['media.tts.vi_voice'] = AppCapability(
            id: 'media.tts.vi_voice',
            displayName: 'Giọng đọc Tiếng Việt cài đặt sẵn',
            description: 'Giọng đọc tiếng Việt (An / Nam / Mai / vi-VN) được cài trong Windows.',
            availability: hasViVoice ? CapabilityAvailability.available : CapabilityAvailability.notConfigured,
            provider: 'Windows Vietnamese TTS Voice',
            reason: hasViVoice
                ? 'Đã phát hiện giọng đọc Tiếng Việt sẵn sàng.'
                : 'Chưa cài đặt gói giọng đọc Tiếng Việt cho Windows.',
            lastChecked: now,
          );

          // Alias media.tts: available if vi voice present, degraded if only foreign voices present
          _cache['media.tts'] = AppCapability(
            id: 'media.tts',
            displayName: 'Giọng đọc Tiếng Việt Ngoại tuyến',
            description: 'Tổng hợp giọng nói tiếng Việt tự nhiên qua Windows SAPI & OneCore.',
            availability: hasViVoice
                ? CapabilityAvailability.available
                : (voiceCount > 0 ? CapabilityAvailability.degraded : CapabilityAvailability.unavailable),
            provider: 'Windows Speech Synthesizer',
            reason: hasViVoice
                ? 'Đầy đủ giọng đọc Tiếng Việt cục bộ.'
                : (voiceCount > 0
                    ? 'Chỉ có giọng tiếng Anh/ngoại ngữ. Cần cài thêm giọng Tiếng Việt.'
                    : 'Không phát hiện giọng đọc nào.'),
            lastChecked: now,
          );
        }
      } catch (e) {
        AppLogger.warning('Capability probe error for TTS: $e');
      }

      // 4. Probe WIA Scanner (Service & Device count)
      try {
        if (!Platform.isWindows) {
          _cache['scanner.wia.service'] = AppCapability(
            id: 'scanner.wia.service',
            displayName: 'Dịch vụ Windows Image Acquisition (WIA)',
            description: 'Dịch vụ quét WIA.',
            availability: CapabilityAvailability.unavailable,
            provider: 'Windows Image Acquisition (WIA)',
            reason: 'Chỉ hỗ trợ hệ điều hành Windows.',
            lastChecked: now,
          );
          _cache['scanner.wia.device'] = AppCapability(
            id: 'scanner.wia.device',
            displayName: 'Thiết bị Máy quét kết nối thực tế',
            description: 'Máy quét tài liệu vật lý.',
            availability: CapabilityAvailability.unavailable,
            provider: 'WIA Device Manager',
            reason: 'Chỉ hỗ trợ hệ điều hành Windows.',
            lastChecked: now,
          );
          _cache['scanner.wia'] = AppCapability(
            id: 'scanner.wia',
            displayName: 'Giao tiếp Máy quét (WIA 2.0)',
            description: 'Kết nối và điều khiển máy scan.',
            availability: CapabilityAvailability.unavailable,
            provider: 'Windows Image Acquisition (WIA)',
            reason: 'Chỉ hỗ trợ hệ điều hành Windows.',
            lastChecked: now,
          );
        } else {
          final wiaProvider = WindowsWiaScannerProvider();
          final devices = await wiaProvider.getAvailableScanners();

          _cache['scanner.wia.service'] = AppCapability(
            id: 'scanner.wia.service',
            displayName: 'Dịch vụ Windows Image Acquisition (WIA)',
            description: 'Dịch vụ nền WIA hệ điều hành Windows phục vụ kết nối thiết bị quét.',
            availability: CapabilityAvailability.available,
            provider: 'WIA COM Service',
            reason: 'Dịch vụ WIA phản hồi bình thường.',
            lastChecked: now,
          );

          final hasDevices = devices.isNotEmpty;
          _cache['scanner.wia.device'] = AppCapability(
            id: 'scanner.wia.device',
            displayName: 'Thiết bị Máy quét kết nối thực tế',
            description: 'Máy quét tài liệu vật lý kết nối qua USB/mạng cục bộ.',
            availability: hasDevices ? CapabilityAvailability.available : CapabilityAvailability.unavailable,
            provider: 'WIA Device Infos',
            reason: hasDevices
                ? 'Tìm thấy ${devices.length} máy quét: ${devices.map((d) => d.name).join(", ")}'
                : 'Chưa phát hiện thiết bị máy quét WIA kết nối tới máy tính.',
            lastChecked: now,
          );

          // Alias scanner.wia
          _cache['scanner.wia'] = AppCapability(
            id: 'scanner.wia',
            displayName: 'Giao tiếp Máy quét (WIA 2.0)',
            description: 'Kết nối và điều khiển máy scan tài liệu phẳng chuẩn Windows WIA.',
            availability: hasDevices ? CapabilityAvailability.available : CapabilityAvailability.degraded,
            provider: 'Windows Image Acquisition (WIA)',
            reason: hasDevices
                ? 'Máy quét đã kết nối và sẵn sàng.'
                : 'Dịch vụ WIA sẵn sàng nhưng chưa kết nối máy quét vật lý.',
            lastChecked: now,
          );
        }
      } catch (e) {
        AppLogger.warning('Capability probe error for WIA: $e');
      }

      // 5. Probe OCR (Engine & Vietnamese language)
      try {
        if (!Platform.isWindows) {
          _cache['document.ocr.engine'] = AppCapability(
            id: 'document.ocr.engine',
            displayName: 'Động cơ Windows Media OCR',
            description: 'Động cơ WinRT OCR.',
            availability: CapabilityAvailability.unavailable,
            provider: 'Windows.Media.Ocr.OcrEngine',
            reason: 'Chỉ hỗ trợ hệ điều hành Windows.',
            lastChecked: now,
          );
          _cache['document.ocr.vi_language'] = AppCapability(
            id: 'document.ocr.vi_language',
            displayName: 'Gói ngôn ngữ OCR Tiếng Việt',
            description: 'Gói nhận dạng tiếng Việt.',
            availability: CapabilityAvailability.unavailable,
            provider: 'Windows OCR Language Pack',
            reason: 'Chỉ hỗ trợ hệ điều hành Windows.',
            lastChecked: now,
          );
          _cache['document.ocr'] = AppCapability(
            id: 'document.ocr',
            displayName: 'Nhận diện quang học OCR Tiếng Việt',
            description: 'Nhận diện chữ in từ tài liệu quét.',
            availability: CapabilityAvailability.unavailable,
            provider: 'Windows Media OCR / WinRT',
            reason: 'Chỉ hỗ trợ hệ điều hành Windows.',
            lastChecked: now,
          );
        } else {
          final ocrEngine = VietnameseOcrEngine();
          final initialized = await ocrEngine.initialize();
          final hasViLang = ocrEngine.hasVietnameseLanguagePack;

          _cache['document.ocr.engine'] = AppCapability(
            id: 'document.ocr.engine',
            displayName: 'Động cơ Windows Media OCR',
            description: 'Động cơ WinRT OCR của hệ điều hành Windows.',
            availability: initialized ? CapabilityAvailability.available : CapabilityAvailability.unavailable,
            provider: 'Windows.Media.Ocr.OcrEngine',
            reason: initialized ? 'Động cơ WinRT OCR đã sẵn sàng.' : 'Không thể khởi tạo Windows Media OCR.',
            lastChecked: now,
          );

          _cache['document.ocr.vi_language'] = AppCapability(
            id: 'document.ocr.vi_language',
            displayName: 'Gói ngôn ngữ OCR Tiếng Việt',
            description: 'Gói nhận dạng ký tự tiếng Việt (vi-VN) trong Windows OCR.',
            availability: hasViLang ? CapabilityAvailability.available : CapabilityAvailability.notConfigured,
            provider: 'Windows OCR Language Pack',
            reason: hasViLang
                ? 'Gói ngôn ngữ Tiếng Việt (vi-VN) đã được cài đặt.'
                : 'Chưa cài đặt gói ngôn ngữ OCR Tiếng Việt trên Windows.',
            lastChecked: now,
          );

          // Alias document.ocr
          _cache['document.ocr'] = AppCapability(
            id: 'document.ocr',
            displayName: 'Nhận diện quang học OCR Tiếng Việt',
            description: 'Nhận diện chữ in từ tài liệu quét, ảnh chụp sách và đề thi.',
            availability: hasViLang
                ? CapabilityAvailability.available
                : (initialized ? CapabilityAvailability.degraded : CapabilityAvailability.unavailable),
            provider: 'Windows Media OCR / WinRT',
            reason: hasViLang
                ? 'OCR Tiếng Việt hoạt động với độ chính xác cao.'
                : (initialized
                    ? 'Chưa cài ngôn ngữ tiếng Việt cho OCR. Sẽ sử dụng nhận dạng ngôn ngữ mặc định.'
                    : 'Không khả dụng.'),
            lastChecked: now,
          );
        }
      } catch (e) {
        AppLogger.warning('Capability probe error for OCR: $e');
      }

      // 6. Probe AI Text Generation (iLocal AI Shared Core + Cloud)
      try {
        final credService = CredentialService();
        final hasGeminiKey = await credService.hasCredential(CredentialService.keyGeminiApiKey);
        final hasOpenAiKey = await credService.hasCredential(CredentialService.keyOpenAiApiKey);

        // Probe iLocal AI Core
        bool hasLocalAi = false;
        try {
          final localClient = LocalAIClient(port: 18181);
          final health = await localClient.health().timeout(const Duration(milliseconds: 1500));
          hasLocalAi = health.isSuccess && health.value.isReady;
        } catch (_) {
          hasLocalAi = false;
        }

        _cache[capAiLocalTextGenerate] = AppCapability(
          id: capAiLocalTextGenerate,
          displayName: 'iLocal AI Shared Core (Ngoại tuyến)',
          description: 'Hạ tầng AI cục bộ chạy offline, bảo mật tuyệt đối, hỗ trợ GPU NVIDIA (Qwen 2.5 3B).',
          availability: hasLocalAi ? CapabilityAvailability.available : CapabilityAvailability.notConfigured,
          provider: 'iLocal AI Daemon (127.0.0.1:18181)',
          reason: hasLocalAi
              ? 'Dịch vụ iLocal AI Core đang chạy ổn định trên cổng 18181.'
              : 'Dịch vụ iLocal AI Core chưa khởi động hoặc chưa lắng nghe trên cổng 18181.',
          lastChecked: now,
        );

        // Gemini specific capability
        _cache[capAiGeminiTextGenerate] = AppCapability(
          id: capAiGeminiTextGenerate,
          displayName: 'Google Gemini AI',
          description: 'Hỗ trợ soạn giáo án và sinh nội dung học tập qua Google Gemini API.',
          availability: hasGeminiKey ? CapabilityAvailability.available : CapabilityAvailability.notConfigured,
          provider: 'Google Gemini REST API',
          reason: hasGeminiKey
              ? 'Khóa API Google Gemini hợp lệ đã được lưu trữ an toàn trong Windows DPAPI.'
              : 'Chưa cấu hình Google Gemini API Key trong mục Cài đặt -> Nhà cung cấp AI.',
          lastChecked: now,
        );

        // OpenAI specific capability (backend currently unimplemented in this release)
        _cache[capAiOpenAiTextGenerate] = AppCapability(
          id: capAiOpenAiTextGenerate,
          displayName: 'OpenAI API (Đang phát triển)',
          description: 'Hỗ trợ OpenAI GPT đang phát triển trong các bản cập nhật sau.',
          availability: CapabilityAvailability.unavailable,
          provider: 'OpenAI REST API',
          reason: hasOpenAiKey
              ? 'Đã phát hiện khóa API OpenAI nhưng tính năng này chưa được kích hoạt trong phiên bản này. Vui lòng sử dụng iLocal AI hoặc Google Gemini.'
              : 'Chưa hỗ trợ kết nối OpenAI trong phiên bản này. Vui lòng sử dụng iLocal AI hoặc Google Gemini.',
          lastChecked: now,
        );

        // Aggregate ai.text.generate capability: Available if EITHER local AI is ready OR Gemini is configured!
        if (hasLocalAi || hasGeminiKey) {
          final activeProviderName = hasLocalAi ? 'iLocal AI Core (Ngoại tuyến)' : 'Google Gemini (Đám mây)';
          _cache[capAiTextGenerate] = AppCapability(
            id: capAiTextGenerate,
            displayName: 'Trí tuệ nhân tạo (AI Text Generation)',
            description: 'Hỗ trợ soạn giáo án và sinh nội dung học tập qua iLocal AI hoặc Google Gemini.',
            availability: CapabilityAvailability.available,
            provider: activeProviderName,
            reason: hasLocalAi
                ? 'iLocal AI Shared Core đang chạy sẵn sàng ngoại tuyến (không cần internet, không tốn API key).'
                : 'Khóa API Google Gemini đã được cấu hình hợp lệ.',
            lastChecked: now,
          );
        } else {
          _cache[capAiTextGenerate] = AppCapability(
            id: capAiTextGenerate,
            displayName: 'Trí tuệ nhân tạo (AI Text Generation)',
            description: 'Hỗ trợ soạn giáo án và sinh nội dung học tập qua Google Gemini hoặc iLocal AI.',
            availability: CapabilityAvailability.notConfigured,
            provider: 'iLocal AI / Google Gemini',
            reason: 'Chưa khởi động dịch vụ iLocal AI và chưa cấu hình Google Gemini API Key.',
            lastChecked: now,
          );
        }
      } catch (e) {
        AppLogger.warning('Capability probe error for AI: $e');
      }

      // 7. Mark check time for static bundled capabilities
      final staticEngines = [
        'document.pdf.read',
        'document.pdf.write',
        'document.docx.write',
        'document.xlsx.write',
      ];

      for (final id in staticEngines) {
        final existing = _cache[id];
        if (existing != null) {
          _cache[id] = existing.copyWith(lastChecked: now);
        }
      }
    } finally {
      _isProbing = false;
    }
  }
}

/// Riverpod provider for CapabilityRegistry
final capabilityRegistryProvider = Provider<CapabilityRegistry>((ref) {
  return CapabilityRegistry.instance;
});
