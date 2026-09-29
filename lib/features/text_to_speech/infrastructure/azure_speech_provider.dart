import 'dart:convert';
import 'dart:io';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/logging/app_logger.dart';
import '../domain/models/tts_options.dart';
import '../domain/models/tts_provider_info.dart';
import '../domain/models/tts_request.dart';
import '../domain/models/tts_voice.dart';
import '../domain/services/tts_provider.dart';

/// Architecture adapter for Microsoft Azure Cognitive Services Speech REST API.
/// Safely disabled until subscription key and region are configured by user.
/// Secret tokens and authorization keys are masked in all logs.
class AzureSpeechProvider implements TtsProvider {
  String? _subscriptionKey;
  String? _region;
  bool _initialized = false;
  HttpClientRequest? _activeRequest;

  AzureSpeechProvider({String? subscriptionKey, String? region})
      : _subscriptionKey = subscriptionKey,
        _region = region ?? 'southeastasia';

  void configure({String? subscriptionKey, String? region}) {
    _subscriptionKey = subscriptionKey;
    if (region != null && region.isNotEmpty) _region = region;
    _initialized = false;
  }

  @override
  String get id => 'azure_speech';

  @override
  TtsProviderInfo get info => TtsProviderInfo(
        id: 'azure_speech',
        name: 'Microsoft Azure Cognitive Speech (Neural Voices)',
        description: 'Dịch vụ giọng đọc đám mây Microsoft Azure với các giọng Hoài My, Nam Minh cực kỳ tự nhiên.',
        isOffline: false,
        isConfigured: _subscriptionKey != null && _subscriptionKey!.trim().isNotEmpty,
        supportsPitch: true,
        supportsRate: true,
        supportsSsml: true,
        supportsWav: true,
        supportsMp3: true,
        supportsTiming: true,
        maxCharactersPerRequest: 10000,
        minSpeed: 0.5,
        maxSpeed: 2.0,
      );

  @override
  bool get isAvailable => _subscriptionKey != null && _subscriptionKey!.trim().isNotEmpty;

  bool get isInitialized => _initialized;

  @override
  Future<bool> initialize() async {
    _initialized = true;
    final isConfig = _subscriptionKey != null && _subscriptionKey!.trim().isNotEmpty;
    AppLogger.info('Azure Speech initialized: configured=$isConfig (Key: ${_maskSecret(_subscriptionKey)}, Region: $_region)');
    return isConfig;
  }

  @override
  Future<List<TtsVoice>> getVoices() async {
    return const [
      TtsVoice(
        id: 'vi-VN-HoaiMyNeural',
        name: 'vi-VN-HoaiMyNeural (Nữ)',
        language: 'vi-VN',
        locale: 'vi-VN',
        gender: 'Female',
        providerId: 'azure_speech',
        isOffline: false,
      ),
      TtsVoice(
        id: 'vi-VN-NamMinhNeural',
        name: 'vi-VN-NamMinhNeural (Nam)',
        language: 'vi-VN',
        locale: 'vi-VN',
        gender: 'Male',
        providerId: 'azure_speech',
        isOffline: false,
      ),
    ];
  }

  @override
  Future<String> synthesize(TtsRequest request) async {
    if (!isAvailable) {
      throw const TtsProviderAuthException(
        'Microsoft Azure Speech chưa được cấu hình Subscription Key. Vui lòng nhập khóa trong Cài đặt.',
        providerId: 'azure_speech',
      );
    }

    try {
      final client = HttpClient();
      final region = _region ?? 'southeastasia';
      final uri = Uri.parse('https://$region.tts.speech.microsoft.com/cognitiveservices/v1');
      _activeRequest = await client.postUrl(uri);

      final audioOutputFormat = request.options.format == TtsAudioFormat.mp3
          ? 'audio-24khz-160kbitrate-mono-mp3'
          : 'riff-24khz-16bit-mono-pcm';

      _activeRequest!.headers.set('Ocp-Apim-Subscription-Key', _subscriptionKey!);
      _activeRequest!.headers.set('Content-Type', 'application/ssml+xml');
      _activeRequest!.headers.set('X-Microsoft-OutputFormat', audioOutputFormat);
      _activeRequest!.headers.set('User-Agent', 'NguyenDuTool_TTS_1.5.1');

      final ratePct = ((request.options.speed - 1.0) * 100).round();
      final rateStr = ratePct >= 0 ? '+$ratePct%' : '$ratePct%';

      final ssml = '''
<speak version='1.0' xml:lang='${request.voice.language}'>
  <voice xml:lang='${request.voice.language}' name='${request.voice.id}'>
    <prosody rate='$rateStr'>
      ${_escapeXml(request.text)}
    </prosody>
  </voice>
</speak>
''';

      _activeRequest!.write(ssml);
      final response = await _activeRequest!.close();
      _activeRequest = null;

      if (response.statusCode == 429) {
        throw const TtsRateLimitException(
          'Azure Speech đã vượt giới hạn hạn ngạch gọi dịch vụ. Vui lòng thử lại sau giây lát.',
          retryAfter: Duration(seconds: 5),
        );
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const TtsProviderAuthException(
          'Azure Speech Subscription Key hoặc Region không chính xác.',
          providerId: 'azure_speech',
        );
      }

      if (response.statusCode != 200) {
        final err = await response.transform(utf8.decoder).join();
        throw TtsSynthesisException('Lỗi Azure Speech: $err', chunkIndex: request.chunkIndex);
      }

      final outPath = request.outputPath ??
          '${Directory.systemTemp.path}/azure_chunk_${DateTime.now().millisecondsSinceEpoch}.${request.options.format.extension}';
      final file = File(outPath);
      final sink = file.openWrite();
      await response.pipe(sink);
      return outPath;
    } catch (e, st) {
      if (e is TtsException) rethrow;
      throw TtsSynthesisException(
        'Lỗi kết nối Azure Speech: $e',
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

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  String _maskSecret(String? secret) {
    if (secret == null || secret.isEmpty) return '(None)';
    if (secret.length <= 8) return '****';
    return '${secret.substring(0, 4)}...${secret.substring(secret.length - 4)}';
  }
}
