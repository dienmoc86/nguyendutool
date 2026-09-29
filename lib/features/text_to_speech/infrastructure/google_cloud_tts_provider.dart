import 'dart:convert';
import 'dart:io';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/logging/app_logger.dart';
import '../domain/models/tts_options.dart';
import '../domain/models/tts_provider_info.dart';
import '../domain/models/tts_request.dart';
import '../domain/models/tts_voice.dart';
import '../domain/services/tts_provider.dart';

/// Architecture adapter for Google Cloud Text-to-Speech REST API.
/// Remains safely disabled until valid API credentials are provided by the user.
/// Masks all API tokens and secrets from system logs.
class GoogleCloudTtsProvider implements TtsProvider {
  String? _apiKey;
  bool _initialized = false;
  HttpClientRequest? _activeRequest;

  GoogleCloudTtsProvider({String? apiKey}) : _apiKey = apiKey;

  void configureApiKey(String? key) {
    _apiKey = key;
    _initialized = false;
  }

  @override
  String get id => 'google_cloud';

  @override
  TtsProviderInfo get info => TtsProviderInfo(
        id: 'google_cloud',
        name: 'Google Cloud Text-to-Speech (Neural2 / Wavenet)',
        description: 'Dịch vụ giọng đọc đám mây Google Cloud với các giọng đọc tiếng Việt Neural2 và Wavenet chất lượng cao.',
        isOffline: false,
        isConfigured: _apiKey != null && _apiKey!.trim().isNotEmpty,
        supportsPitch: true,
        supportsRate: true,
        supportsSsml: true,
        supportsWav: true,
        supportsMp3: true,
        supportsTiming: true,
        maxCharactersPerRequest: 5000,
        minSpeed: 0.25,
        maxSpeed: 4.0,
        minPitch: -20.0,
        maxPitch: 20.0,
      );

  @override
  bool get isAvailable => _apiKey != null && _apiKey!.trim().isNotEmpty;

  bool get isInitialized => _initialized;

  @override
  Future<bool> initialize() async {
    _initialized = true;
    final isConfig = _apiKey != null && _apiKey!.trim().isNotEmpty;
    AppLogger.info('Google Cloud TTS initialized: configured=$isConfig (API Key: ${_maskSecret(_apiKey)})');
    return isConfig;
  }

  @override
  Future<List<TtsVoice>> getVoices() async {
    if (!isAvailable) {
      return const [
        TtsVoice(
          id: 'vi-VN-Neural2-A',
          name: 'vi-VN-Neural2-A (Nữ)',
          language: 'vi-VN',
          locale: 'vi-VN',
          gender: 'Female',
          providerId: 'google_cloud',
          isOffline: false,
        ),
        TtsVoice(
          id: 'vi-VN-Neural2-D',
          name: 'vi-VN-Neural2-D (Nam)',
          language: 'vi-VN',
          locale: 'vi-VN',
          gender: 'Male',
          providerId: 'google_cloud',
          isOffline: false,
        ),
        TtsVoice(
          id: 'vi-VN-Wavenet-A',
          name: 'vi-VN-Wavenet-A (Nữ)',
          language: 'vi-VN',
          locale: 'vi-VN',
          gender: 'Female',
          providerId: 'google_cloud',
          isOffline: false,
        ),
        TtsVoice(
          id: 'vi-VN-Wavenet-B',
          name: 'vi-VN-Wavenet-B (Nam)',
          language: 'vi-VN',
          locale: 'vi-VN',
          gender: 'Male',
          providerId: 'google_cloud',
          isOffline: false,
        ),
      ];
    }

    return const [
      TtsVoice(
        id: 'vi-VN-Neural2-A',
        name: 'vi-VN-Neural2-A (Nữ)',
        language: 'vi-VN',
        locale: 'vi-VN',
        gender: 'Female',
        providerId: 'google_cloud',
        isOffline: false,
      ),
      TtsVoice(
        id: 'vi-VN-Neural2-D',
        name: 'vi-VN-Neural2-D (Nam)',
        language: 'vi-VN',
        locale: 'vi-VN',
        gender: 'Male',
        providerId: 'google_cloud',
        isOffline: false,
      ),
    ];
  }

  @override
  Future<String> synthesize(TtsRequest request) async {
    if (!isAvailable) {
      throw const TtsProviderAuthException(
        'Google Cloud TTS chưa được cấu hình khóa API. Vui lòng nhập khóa API trong Cài đặt.',
        providerId: 'google_cloud',
      );
    }

    try {
      final client = HttpClient();
      final uri = Uri.parse('https://texttospeech.googleapis.com/v1/text:synthesize');
      _activeRequest = await client.postUrl(uri);
      _activeRequest!.headers.set('Content-Type', 'application/json; charset=utf-8');
      _activeRequest!.headers.set('X-Goog-Api-Key', _apiKey!);

      final audioEncoding = request.options.format == TtsAudioFormat.mp3 ? 'MP3' : 'LINEAR16';

      final body = jsonEncode({
        'input': {'text': request.text},
        'voice': {
          'languageCode': request.voice.language,
          'name': request.voice.id,
        },
        'audioConfig': {
          'audioEncoding': audioEncoding,
          'speakingRate': request.options.speed,
          'pitch': (request.options.pitch - 1.0) * 10,
          'volumeGainDb': (request.options.volume - 1.0) * 10,
        },
      });

      _activeRequest!.write(body);
      final response = await _activeRequest!.close();
      _activeRequest = null;

      if (response.statusCode == 429) {
        throw const TtsRateLimitException(
          'Google Cloud TTS đã vượt giới hạn hạn ngạch gọi API. Vui lòng thử lại sau giây lát.',
          retryAfter: Duration(seconds: 5),
        );
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const TtsProviderAuthException(
          'Khóa Google Cloud API không hợp lệ hoặc đã hết hạn quyền truy cập.',
          providerId: 'google_cloud',
        );
      }

      final responseBody = await response.transform(utf8.decoder).join();
      final data = jsonDecode(responseBody) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        final err = data['error']?['message'] ?? 'Lỗi không xác định từ Google Cloud';
        throw TtsSynthesisException('Lỗi Google Cloud TTS: $err', chunkIndex: request.chunkIndex);
      }

      final audioBase64 = data['audioContent'] as String?;
      if (audioBase64 == null) {
        throw const TtsSynthesisException('Phản hồi từ Google Cloud không chứa dữ liệu âm thanh.');
      }

      final audioBytes = base64Decode(audioBase64);
      final outPath = request.outputPath ??
          '${Directory.systemTemp.path}/gcloud_chunk_${DateTime.now().millisecondsSinceEpoch}.${request.options.format.extension}';
      await File(outPath).writeAsBytes(audioBytes);
      return outPath;
    } catch (e, st) {
      if (e is TtsException) rethrow;
      throw TtsSynthesisException(
        'Lỗi kết nối Google Cloud TTS: $e',
        chunkIndex: request.chunkIndex,
        technicalDetails: e.toString(),
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> cancel() async {
    if (_activeRequest != null) {
      try {
        _activeRequest!.abort();
      } catch (_) {}
      _activeRequest = null;
    }
  }

  @override
  Future<void> dispose() async {}

  String _maskSecret(String? secret) {
    if (secret == null || secret.isEmpty) return '(None)';
    if (secret.length <= 8) return '****';
    return '${secret.substring(0, 4)}...${secret.substring(secret.length - 4)}';
  }
}
