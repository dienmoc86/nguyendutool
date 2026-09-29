import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../core/errors/app_exceptions.dart';
import '../../../core/logging/app_logger.dart';
import '../domain/models/tts_provider_info.dart';
import '../domain/models/tts_request.dart';
import '../domain/models/tts_voice.dart';
import '../domain/models/tts_voice_engine.dart';
import '../domain/services/tts_provider.dart';

/// Local offline Windows Speech Synthesizer provider using Windows SAPI and OneCore Speech APIs.
/// Generates genuine uncompressed PCM WAV files directly on the user's desktop with zero internet requirement.
class WindowsSpeechSynthesizerProvider implements TtsProvider {
  bool _initialized = false;
  bool _isAvailable = false;
  List<TtsVoice> _voices = const [];
  Process? _activeProcess;

  @override
  String get id => 'windows_local';

  @override
  TtsProviderInfo get info => const TtsProviderInfo(
        id: 'windows_local',
        name: 'Giọng đọc Windows Cục bộ (Offline SAPI / OneCore)',
        description: 'Động cơ tổng hợp giọng đọc ngoại tuyến tích hợp sẵn trên hệ điều hành Windows.',
        isOffline: true,
        isConfigured: true,
        supportsPitch: false, // Windows SAPI/OneCore pitch is neutral in standard desktop synthesis
        supportsRate: true,
        supportsSsml: false, // Honest: current synthesis pipeline processes plain text
        supportsWav: true,
        supportsMp3: true,
        supportsTiming: true,
        supportsChunkTiming: true, // Accurate chunk audio duration
        supportsWordTiming: false, // No exact engine word boundary events exposed
        supportsSentenceTiming: false,
        maxCharactersPerRequest: 3000,
        minSpeed: 0.5,
        maxSpeed: 2.0,
      );

  @override
  bool get isAvailable => Platform.isWindows && (!_initialized || _isAvailable);

  List<TtsVoice> get voices => _voices;

  bool get hasVietnameseVoice => _voices.any((v) => v.isVietnamese);

  @override
  Future<bool> initialize() async {
    if (_initialized) return _isAvailable;

    if (!Platform.isWindows) {
      _isAvailable = false;
      _initialized = true;
      return false;
    }

    try {
      const script = '''
\$ErrorActionPreference = "SilentlyContinue"
Add-Type -AssemblyName System.Speech

# Query SAPI Installed Voices
\$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
\$sapiVoices = \$synth.GetInstalledVoices()
\$list = @()

foreach (\$v in \$sapiVoices) {
    if (\$v.Enabled) {
        \$info = \$v.VoiceInfo
        \$list += @{
            id = \$info.Name
            name = \$info.Name
            language = \$info.Culture.Name
            locale = \$info.Culture.Name
            gender = \$info.Gender.ToString()
            providerId = "windows_local"
            isOffline = \$true
            engine = "sapi"
        }
    }
}
\$synth.Dispose()

# Query Windows OneCore Voices if available
try {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    [Windows.Media.SpeechSynthesis.SpeechSynthesizer, Windows.Media.SpeechSynthesis, ContentType = WindowsRuntime] | Out-Null
    \$oneCoreVoices = [Windows.Media.SpeechSynthesis.SpeechSynthesizer]::AllVoices
    foreach (\$ov in \$oneCoreVoices) {
        # Avoid duplicate name with SAPI
        if (-not (\$list | Where-Object { \$_.name -eq \$ov.DisplayName })) {
            \$list += @{
                id = \$ov.Id
                name = \$ov.DisplayName
                language = \$ov.Language
                locale = \$ov.Language
                gender = \$ov.Gender.ToString()
                providerId = "windows_local"
                isOffline = \$true
                engine = "oneCore"
            }
        }
    }
} catch {}

\$list | ConvertTo-Json -Compress
''';

      final res = await Process.run(
        'powershell',
        ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', script],
      ).timeout(const Duration(seconds: 15));

      if (res.exitCode == 0) {
        final out = res.stdout.toString().trim();
        if (out.isNotEmpty && (out.startsWith('[') || out.startsWith('{'))) {
          dynamic decoded = jsonDecode(out);
          if (decoded is Map<String, dynamic>) {
            decoded = [decoded];
          }
          if (decoded is List) {
            _voices = decoded
                .map((m) => TtsVoice.fromJson(m as Map<String, dynamic>))
                .toList();
            _isAvailable = _voices.isNotEmpty;
          }
        }
      }
    } catch (e) {
      AppLogger.warning('Windows TTS discovery failed: $e');
      _isAvailable = false;
    }

    _initialized = true;
    AppLogger.info('Windows TTS Initialized: available=$_isAvailable, discovered ${_voices.length} voices.');
    return _isAvailable;
  }

  @override
  Future<List<TtsVoice>> getVoices() async {
    if (!_initialized) await initialize();
    return _voices;
  }

  @override
  Future<String> synthesize(TtsRequest request) async {
    if (!Platform.isWindows) {
      throw const TtsEngineUnavailableException('Động cơ Windows Speech Synthesizer chỉ khả dụng trên Windows.');
    }

    if (!_initialized) await initialize();

    final targetPath = request.outputPath ??
        p.join(
          Directory.systemTemp.path,
          'tts_chunk_${DateTime.now().millisecondsSinceEpoch}_${request.chunkIndex ?? 0}.wav',
        );

    final outDir = Directory(p.dirname(targetPath));
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    final tempDir = Directory.systemTemp;
    final tempBase = 'tts_${DateTime.now().millisecondsSinceEpoch}_${request.chunkIndex ?? 0}';
    final textFile = File(p.join(tempDir.path, '$tempBase.txt'));
    final scriptFile = File(p.join(tempDir.path, '$tempBase.ps1'));

    // Write input text with UTF-8 encoding (without BOM for clean PowerShell reading)
    await textFile.writeAsString(request.text, encoding: utf8);

    final voiceName = request.voice.name;
    final voiceId = request.voice.id;
    final engine = request.voice.engine;

    // Rate & Volume calculations
    final rate = ((request.options.speed - 1.0) * 10).round().clamp(-10, 10);
    final volume = (request.options.volume * 100).round().clamp(0, 100);

    String scriptContent;
    if (engine == TtsVoiceEngine.oneCore) {
      // Genuine Windows.Media.SpeechSynthesis script
      scriptContent = '''
\$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Runtime.WindowsRuntime
[Windows.Media.SpeechSynthesis.SpeechSynthesizer, Windows.Media.SpeechSynthesis, ContentType = WindowsRuntime] | Out-Null
[Windows.Storage.Streams.DataReader, Windows.Storage.Streams, ContentType = WindowsRuntime] | Out-Null

\$synth = New-Object Windows.Media.SpeechSynthesis.SpeechSynthesizer
\$voices = [Windows.Media.SpeechSynthesis.SpeechSynthesizer]::AllVoices
\$targetVoice = \$voices | Where-Object { \$_.Id -eq @'
$voiceId
'@ -or \$_.DisplayName -eq @'
$voiceName
'@ } | Select-Object -First 1

if (-not \$targetVoice) {
    [System.Console]::Error.WriteLine("VOICE_UNAVAILABLE")
    [System.Environment]::Exit(3)
}

\$synth.Voice = \$targetVoice
if (\$synth.Voice.DisplayName -ne \$targetVoice.DisplayName) {
    [System.Console]::Error.WriteLine("VOICE_MISMATCH")
    [System.Environment]::Exit(3)
}

\$text = [System.IO.File]::ReadAllText(@'
${textFile.path}
'@, [System.Text.Encoding]::UTF8)

\$op = \$synth.SynthesizeTextToStreamAsync(\$text)
\$asTaskMethod = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    \$_.Name -eq 'AsTask' -and \$_.IsGenericMethodDefinition -and \$_.GetParameters().Count -eq 1
} | Select-Object -First 1

\$streamTaskMethod = \$asTaskMethod.MakeGenericMethod([Windows.Media.SpeechSynthesis.SpeechSynthesisStream])
\$stream = \$streamTaskMethod.Invoke(\$null, @(\$op)).GetAwaiter().GetResult()

\$reader = New-Object Windows.Storage.Streams.DataReader(\$stream.GetInputStreamAt(0))
\$loadOp = \$reader.LoadAsync(\$stream.Size)
\$uintTaskMethod = \$asTaskMethod.MakeGenericMethod([System.UInt32])
\$uintTaskMethod.Invoke(\$null, @(\$loadOp)).GetAwaiter().GetResult() | Out-Null

\$buffer = New-Object byte[] \$stream.Size
\$reader.ReadBytes(\$buffer)

[System.IO.File]::WriteAllBytes(@'
$targetPath
'@, \$buffer)
\$synth.Dispose()
[System.Environment]::Exit(0)
''';
    } else {
      // Genuine SAPI Desktop System.Speech script
      scriptContent = '''
\$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Speech

\$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
\$targetVoice = \$synth.GetInstalledVoices() | Where-Object {
    \$_.VoiceInfo.Name -eq @'
$voiceName
'@ -or \$_.VoiceInfo.Id -eq @'
$voiceId
'@
} | Select-Object -First 1

if (-not \$targetVoice -or -not \$targetVoice.Enabled) {
    [System.Console]::Error.WriteLine("VOICE_UNAVAILABLE")
    [System.Environment]::Exit(3)
}

try {
    \$synth.SelectVoice(\$targetVoice.VoiceInfo.Name)
} catch {
    [System.Console]::Error.WriteLine("VOICE_SELECT_FAILED")
    [System.Environment]::Exit(3)
}

if (\$synth.Voice.Name -ne \$targetVoice.VoiceInfo.Name) {
    [System.Console]::Error.WriteLine("VOICE_MISMATCH")
    [System.Environment]::Exit(3)
}

\$synth.Rate = $rate
\$synth.Volume = $volume
\$synth.SetOutputToWaveFile(@'
$targetPath
'@)

\$text = [System.IO.File]::ReadAllText(@'
${textFile.path}
'@, [System.Text.Encoding]::UTF8)

\$synth.Speak(\$text)
\$synth.Dispose()
[System.Environment]::Exit(0)
''';
    }

    await scriptFile.writeAsString(scriptContent, encoding: utf8);

    try {
      _activeProcess = await Process.start(
        'powershell',
        ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', scriptFile.path],
      );

      final exitCode = await _activeProcess!.exitCode;
      _activeProcess = null;

      if (exitCode == 3) {
        throw TtsVoiceUnavailableException(
          'Không thể sử dụng giọng đã chọn trên máy này.',
          voiceId: request.voice.id,
          voiceName: request.voice.name,
        );
      } else if (exitCode != 0) {
        throw TtsSynthesisException(
          'Không thể tổng hợp giọng đọc Windows cho đoạn văn bản này (ExitCode: $exitCode).',
          chunkIndex: request.chunkIndex,
        );
      }

      final file = File(targetPath);
      if (!file.existsSync() || file.lengthSync() < 100) {
        throw TtsSynthesisException(
          'Tệp âm thanh tổng hợp không hợp lệ hoặc rỗng: $targetPath',
          chunkIndex: request.chunkIndex,
        );
      }

      return targetPath;
    } catch (e, st) {
      _activeProcess = null;
      if (e is TtsException) rethrow;
      throw TtsSynthesisException(
        'Lỗi trong quá trình tổng hợp giọng đọc: $e',
        chunkIndex: request.chunkIndex,
        technicalDetails: e.toString(),
        stackTrace: st,
      );
    } finally {
      // Cleanup temporary script and input text files
      try {
        if (textFile.existsSync()) textFile.deleteSync();
        if (scriptFile.existsSync()) scriptFile.deleteSync();
      } catch (_) {}
    }
  }

  @override
  Future<void> cancel() async {
    if (_activeProcess != null) {
      try {
        _activeProcess!.kill(ProcessSignal.sigkill);
      } catch (_) {}
      _activeProcess = null;
    }
  }

  @override
  Future<void> dispose() async {
    await cancel();
  }
}
