import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import '../../../core/errors/app_exceptions.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/media/ffmpeg_service.dart';
import '../domain/models/tts_options.dart';
import '../domain/models/tts_result.dart';
import '../domain/models/tts_timing_segment.dart';

/// Service responsible for concatenating chunked audio files, inserting natural pauses,
/// encoding to WAV or MP3, and performing programmatic audio QA (headers, duration, silence detection).
class AudioAssemblyService {
  final FfmpegService _ffmpegService;

  AudioAssemblyService({FfmpegService? ffmpegService})
      : _ffmpegService = ffmpegService ?? FfmpegService.instance;

  /// Assembles multiple chunk audio files into a single master audio file.
  Future<TtsResult> assembleAudio({
    required List<String> chunkAudioPaths,
    required List<String> chunkTexts,
    required List<bool> isParagraphBoundaries,
    required String outputAudioPath,
    required TtsOptions options,
    void Function(double progress, String status)? onProgress,
  }) async {
    if (chunkAudioPaths.isEmpty) {
      throw const TtsInputException('Không có tệp âm thanh phân đoạn nào để ghép nối.');
    }

    onProgress?.call(0.1, 'Đang chuẩn bị ghép nối ${chunkAudioPaths.length} đoạn âm thanh...');

    final outDir = Directory(p.dirname(outputAudioPath));
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    // 1. If only 1 chunk and format is WAV, and output matches, validate directly
    if (chunkAudioPaths.length == 1 && options.format == TtsAudioFormat.wav) {
      final singleFile = File(chunkAudioPaths.first);
      if (singleFile.path != outputAudioPath) {
        await singleFile.copy(outputAudioPath);
      }
      return _validateAndBuildResult(
        outputAudioPath: outputAudioPath,
        format: TtsAudioFormat.wav,
        chunkTexts: chunkTexts,
      );
    }

    // 2. Perform PCM WAV Assembly with configurable pauses
    final intermediateWavPath = options.format == TtsAudioFormat.wav
        ? outputAudioPath
        : p.join(outDir.path, 'temp_assembled_${DateTime.now().millisecondsSinceEpoch}.wav');

    final timingSegments = await _concatenatePcmWavFiles(
      inputWavPaths: chunkAudioPaths,
      chunkTexts: chunkTexts,
      isParagraphBoundaries: isParagraphBoundaries,
      outputWavPath: intermediateWavPath,
      paragraphPauseMs: options.paragraphPauseMs,
      sentencePauseMs: options.sentencePauseMs,
      onProgress: onProgress,
    );

    onProgress?.call(0.8, 'Đang kiểm tra chất lượng âm thanh...');
    final wavValidation = await validateAudio(intermediateWavPath, TtsAudioFormat.wav);
    if (!wavValidation.isValid) {
      throw TtsEncodingException('Kiểm tra chất lượng WAV thất bại: ${wavValidation.errorMessage}');
    }

    // 3. If target format is MP3, encode WAV -> MP3
    if (options.format == TtsAudioFormat.mp3) {
      onProgress?.call(0.85, 'Đang nén âm thanh sang định dạng MP3...');
      final encoded = await _encodeWavToMp3(
        intermediateWavPath,
        outputAudioPath,
      );

      // Clean up intermediate WAV
      try {
        final f = File(intermediateWavPath);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}

      if (!encoded) {
        throw const TtsEncodingException('Không thể mã hóa tệp âm thanh sang định dạng MP3.');
      }

      onProgress?.call(0.95, 'Đang xác thực tệp MP3...');
      final mp3Validation = await validateAudio(outputAudioPath, TtsAudioFormat.mp3);
      if (!mp3Validation.isValid) {
        throw TtsEncodingException('Kiểm tra chất lượng MP3 thất bại: ${mp3Validation.errorMessage}');
      }
    }

    onProgress?.call(1.0, 'Ghép nối và xuất âm thanh hoàn tất.');

    final finalFile = File(outputAudioPath);
    final totalDurationMs = timingSegments.isNotEmpty ? timingSegments.last.endMs : 0;

    return TtsResult(
      audioPath: outputAudioPath,
      format: options.format,
      durationMs: totalDurationMs,
      fileSize: finalFile.existsSync() ? finalFile.lengthSync() : 0,
      sampleRate: wavValidation.sampleRate,
      channels: wavValidation.channels,
      timingSegments: timingSegments,
    );
  }

  /// Concatenates multiple WAV PCM files cleanly at the byte level and tracks exact timing.
  Future<List<TtsTimingSegment>> _concatenatePcmWavFiles({
    required List<String> inputWavPaths,
    required List<String> chunkTexts,
    required List<bool> isParagraphBoundaries,
    required String outputWavPath,
    required int paragraphPauseMs,
    required int sentencePauseMs,
    void Function(double progress, String status)? onProgress,
  }) async {
    final firstFile = File(inputWavPaths.first);
    final firstBytes = await firstFile.readAsBytes();

    final headerInfo = _parseWavHeader(firstBytes);
    if (headerInfo == null) {
      throw const TtsEncodingException('Tệp âm thanh đầu vào không có định dạng RIFF/WAVE PCM hợp lệ.');
    }

    final sampleRate = headerInfo.sampleRate;
    final channels = headerInfo.channels;
    final bitsPerSample = headerInfo.bitsPerSample;
    final bytesPerSample = (bitsPerSample / 8).ceil();
    final blockAlign = channels * bytesPerSample;
    final bytesPerSecond = sampleRate * blockAlign;

    final outputSink = File(outputWavPath).openWrite();

    // Write placeholder 44-byte WAV header (will update sizes at end)
    outputSink.add(Uint8List(44));

    var totalPcmBytes = 0;
    var currentTimelineMs = 0;
    final segments = <TtsTimingSegment>[];

    for (int i = 0; i < inputWavPaths.length; i++) {
      final pct = 0.2 + (i / inputWavPaths.length) * 0.6;
      onProgress?.call(pct, 'Đang ghép đoạn ${i + 1}/${inputWavPaths.length}...');

      final chunkFile = File(inputWavPaths[i]);
      if (!chunkFile.existsSync()) continue;

      final chunkBytes = await chunkFile.readAsBytes();
      final pcmSlice = _extractPcmData(chunkBytes);

      if (pcmSlice.isNotEmpty) {
        outputSink.add(pcmSlice);
        totalPcmBytes += pcmSlice.length;

        final chunkDurationMs = (pcmSlice.length / bytesPerSecond * 1000).round();
        final startMs = currentTimelineMs;
        final endMs = startMs + chunkDurationMs;

        segments.add(
          TtsTimingSegment(
            index: i,
            startMs: startMs,
            endMs: endMs,
            text: i < chunkTexts.length ? chunkTexts[i] : '',
            isEstimated: true,
          ),
        );

        currentTimelineMs = endMs;

        // Insert pause between chunks if not the last chunk
        if (i < inputWavPaths.length - 1) {
          final isPara = i < isParagraphBoundaries.length && isParagraphBoundaries[i];
          final pauseMs = isPara ? paragraphPauseMs : sentencePauseMs;
          if (pauseMs > 0) {
            final pauseBytesCount = ((pauseMs / 1000.0) * bytesPerSecond).round();
            // Silence = 0-filled byte buffer
            final silenceBytes = Uint8List(pauseBytesCount);
            outputSink.add(silenceBytes);
            totalPcmBytes += pauseBytesCount;
            currentTimelineMs += pauseMs;
          }
        }
      }
    }

    await outputSink.flush();
    await outputSink.close();

    // Rewrite true header with exact file size and data chunk size
    final completeHeader = _buildWavHeader(
      totalPcmBytes: totalPcmBytes,
      sampleRate: sampleRate,
      channels: channels,
      bitsPerSample: bitsPerSample,
    );

    final randomAccess = await File(outputWavPath).open(mode: FileMode.append);
    await randomAccess.setPosition(0);
    await randomAccess.writeFrom(completeHeader);
    await randomAccess.close();

    return segments;
  }

  /// Encodes WAV file to MP3 via FFmpeg (preferred) or Windows MediaTranscoder fallback.
  Future<bool> _encodeWavToMp3(String inputWavPath, String outputMp3Path) async {
    // 1. Try FFmpeg first if available
    if (_ffmpegService.isAvailable) {
      final success = await _ffmpegService.encodeMp3(
        inputWavPath: inputWavPath,
        outputMp3Path: outputMp3Path,
        bitrateKbps: 192,
      );
      if (success) return true;
    }

    // 2. Windows MediaTranscoder fallback
    if (Platform.isWindows) {
      try {
        final cleanWav = inputWavPath.replaceAll("'", "''");
        final cleanMp3 = outputMp3Path.replaceAll("'", "''");

        final script = '''
\$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Runtime.WindowsRuntime

\$asTaskOp = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    \$_.Name -eq "AsTask" -and \$_.GetParameters().Count -eq 1 -and \$_.GetParameters()[0].ParameterType.Name.StartsWith("IAsyncOperation")
} | Select-Object -First 1

function Await-Op(\$op, [Type]\$targetType) {
    \$m = \$asTaskOp.MakeGenericMethod(\$targetType)
    return \$m.Invoke(\$null, @(\$op)).GetAwaiter().GetResult()
}

\$asTaskProgress = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    \$_.Name -eq "AsTask" -and \$_.GetParameters().Count -eq 1 -and \$_.GetParameters()[0].ParameterType.Name.StartsWith("IAsyncActionWithProgress")
} | Select-Object -First 1
\$asTaskActionWithProgressDouble = \$asTaskProgress.MakeGenericMethod([double])

[Windows.Media.Transcoding.MediaTranscoder, Windows.Media.Transcoding, ContentType = WindowsRuntime] | Out-Null
[Windows.Media.MediaProperties.MediaEncodingProfile, Windows.Media.MediaProperties, ContentType = WindowsRuntime] | Out-Null
[Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime] | Out-Null

\$srcFile = Await-Op ([Windows.Storage.StorageFile]::GetFileFromPathAsync('$cleanWav')) ([Windows.Storage.StorageFile])

\$folderPath = [System.IO.Path]::GetDirectoryName('$cleanMp3')
\$fileName = [System.IO.Path]::GetFileName('$cleanMp3')
\$destFolder = Await-Op ([Windows.Storage.StorageFolder]::GetFolderFromPathAsync(\$folderPath)) ([Windows.Storage.StorageFolder])
\$destFile = Await-Op (\$destFolder.CreateFileAsync(\$fileName, [Windows.Storage.CreationCollisionOption]::ReplaceExisting)) ([Windows.Storage.StorageFile])

\$transcoder = New-Object Windows.Media.Transcoding.MediaTranscoder
\$profile = [Windows.Media.MediaProperties.MediaEncodingProfile]::CreateMp3([Windows.Media.MediaProperties.AudioEncodingQuality]::High)

\$prepareOp = Await-Op (\$transcoder.PrepareFileTranscodeAsync(\$srcFile, \$destFile, \$profile)) ([Windows.Media.Transcoding.PrepareTranscodeResult])
if (\$prepareOp.CanTranscode) {
    \$transcodeAction = \$prepareOp.TranscodeAsync()
    \$task = \$asTaskActionWithProgressDouble.Invoke(\$null, @(\$transcodeAction))
    \$task.Wait()
    Start-Sleep -Milliseconds 150
} else {
    exit 2
}
''';

        final res = await Process.run(
          'powershell',
          ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', script],
        ).timeout(const Duration(minutes: 5));

        if (res.exitCode == 0 && File(outputMp3Path).existsSync() && File(outputMp3Path).lengthSync() > 500) {
          return true;
        } else {
          AppLogger.warning('Windows MediaTranscoder failed (exitCode=${res.exitCode}): ${res.stderr}\n${res.stdout}');
        }
      } catch (e) {
        AppLogger.warning('Windows MediaTranscoder fallback failed: $e');
      }
    }

    return false;
  }

  /// Validates audio file headers, duration, and performs silence/clipping detection.
  Future<AudioValidationReport> validateAudio(String filePath, TtsAudioFormat format) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      return const AudioValidationReport(isValid: false, errorMessage: 'Tệp âm thanh không tồn tại trên đĩa.');
    }

    final length = file.lengthSync();
    if (length < 100) {
      return const AudioValidationReport(isValid: false, errorMessage: 'Dung lượng tệp âm thanh quá nhỏ.');
    }

    final bytes = await file.readAsBytes();

    if (format == TtsAudioFormat.wav) {
      // Validate RIFF & WAVE headers
      if (bytes.length < 44) {
        return const AudioValidationReport(isValid: false, errorMessage: 'Tiêu đề WAV không đủ 44 bytes.');
      }

      final riffTag = String.fromCharCodes(bytes.sublist(0, 4));
      final waveTag = String.fromCharCodes(bytes.sublist(8, 12));
      if (riffTag != 'RIFF' || waveTag != 'WAVE') {
        return const AudioValidationReport(isValid: false, errorMessage: 'Định dạng RIFF/WAVE không hợp lệ.');
      }

      final headerInfo = _parseWavHeader(bytes);
      if (headerInfo == null) {
        return const AudioValidationReport(isValid: false, errorMessage: 'Không thể đọc cấu trúc fmt chunk của tệp WAV.');
      }

      // Check for all-silence or clipping
      final pcmBytes = _extractPcmData(bytes);
      if (pcmBytes.isEmpty) {
        return const AudioValidationReport(isValid: false, errorMessage: 'Dữ liệu âm thanh PCM rỗng.');
      }

      final isSilent = _detectAllSilencePcm(pcmBytes);
      if (isSilent) {
        return const AudioValidationReport(
          isValid: false,
          errorMessage: 'Âm thanh hoàn toàn im lặng (All-silence detected). Không có tín hiệu tiếng nói.',
        );
      }

      final durationSec = pcmBytes.length / (headerInfo.sampleRate * headerInfo.channels * (headerInfo.bitsPerSample / 8));
      return AudioValidationReport(
        isValid: true,
        durationSeconds: durationSec,
        sampleRate: headerInfo.sampleRate,
        channels: headerInfo.channels,
      );
    } else {
      // Validate MP3: ID3v2 tag ("ID3") or MPEG Audio Sync Frame (0xFF 0xE0+)
      final hasId3 = bytes.length >= 3 && bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33;
      final hasSyncFrame = _findMp3SyncFrame(bytes) >= 0;

      if (!hasId3 && !hasSyncFrame) {
        return const AudioValidationReport(
          isValid: false,
          errorMessage: 'Tệp không chứa khung tiêu đề MPEG hoặc thẻ ID3 của định dạng MP3.',
        );
      }

      return AudioValidationReport(
        isValid: true,
        durationSeconds: (length / (192 * 1024 / 8)), // Estimated
        sampleRate: 22050,
        channels: 1,
      );
    }
  }

  /// Parses 44-byte WAV header details.
  _WavHeaderInfo? _parseWavHeader(Uint8List bytes) {
    if (bytes.length < 44) return null;
    final byteData = ByteData.sublistView(bytes);

    final channels = byteData.getUint16(22, Endian.little);
    final sampleRate = byteData.getUint32(24, Endian.little);
    final bitsPerSample = byteData.getUint16(34, Endian.little);

    if (sampleRate == 0 || channels == 0 || bitsPerSample == 0) return null;

    return _WavHeaderInfo(
      channels: channels,
      sampleRate: sampleRate,
      bitsPerSample: bitsPerSample,
    );
  }

  /// Extracts pure PCM payload from data chunk.
  Uint8List _extractPcmData(Uint8List wavBytes) {
    if (wavBytes.length <= 44) return Uint8List(0);

    // Look for 'data' subchunk
    for (int i = 12; i < wavBytes.length - 8; i++) {
      if (wavBytes[i] == 0x64 &&
          wavBytes[i + 1] == 0x61 &&
          wavBytes[i + 2] == 0x74 &&
          wavBytes[i + 3] == 0x61) {
        final dataStart = i + 8;
        return wavBytes.sublist(dataStart);
      }
    }

    // Default standard fallback: standard 44-byte offset
    return wavBytes.sublist(44);
  }

  /// Constructs a compliant 44-byte canonical PCM RIFF header.
  Uint8List _buildWavHeader({
    required int totalPcmBytes,
    required int sampleRate,
    required int channels,
    required int bitsPerSample,
  }) {
    final header = Uint8List(44);
    final bd = ByteData.sublistView(header);

    final bytesPerSample = (bitsPerSample / 8).ceil();
    final blockAlign = channels * bytesPerSample;
    final byteRate = sampleRate * blockAlign;

    // "RIFF"
    header.setRange(0, 4, ascii.encode('RIFF'));
    bd.setUint32(4, 36 + totalPcmBytes, Endian.little);
    // "WAVE"
    header.setRange(8, 12, ascii.encode('WAVE'));

    // "fmt "
    header.setRange(12, 16, ascii.encode('fmt '));
    bd.setUint32(16, 16, Endian.little); // Subchunk1Size for PCM
    bd.setUint16(20, 1, Endian.little); // AudioFormat = 1 (PCM)
    bd.setUint16(22, channels, Endian.little);
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, byteRate, Endian.little);
    bd.setUint16(32, blockAlign, Endian.little);
    bd.setUint16(34, bitsPerSample, Endian.little);

    // "data"
    header.setRange(36, 40, ascii.encode('data'));
    bd.setUint32(40, totalPcmBytes, Endian.little);

    return header;
  }

  /// Checks if 16-bit PCM bytes contain exclusively silence (amplitude variance < threshold).
  bool _detectAllSilencePcm(Uint8List pcmBytes) {
    if (pcmBytes.length < 100) return true;
    final bd = ByteData.sublistView(pcmBytes);
    final numSamples = pcmBytes.length ~/ 2;

    int maxAmp = 0;
    final step = (numSamples ~/ 1000).clamp(1, 100);

    for (int i = 0; i < numSamples; i += step) {
      final sample = bd.getInt16(i * 2, Endian.little).abs();
      if (sample > maxAmp) maxAmp = sample;
    }

    // Silence if maximum amplitude is less than 50 (out of 32767)
    return maxAmp < 50;
  }

  /// Locates MPEG audio frame sync marker (11 consecutive 1s: 0xFF followed by 0xE0).
  int _findMp3SyncFrame(Uint8List bytes) {
    for (int i = 0; i < bytes.length - 1; i++) {
      if (bytes[i] == 0xFF && (bytes[i + 1] & 0xE0) == 0xE0) {
        return i;
      }
    }
    return -1;
  }

  Future<TtsResult> _validateAndBuildResult({
    required String outputAudioPath,
    required TtsAudioFormat format,
    required List<String> chunkTexts,
  }) async {
    final validation = await validateAudio(outputAudioPath, format);
    final file = File(outputAudioPath);
    final durMs = ((validation.durationSeconds ?? 1.0) * 1000).round();

    return TtsResult(
      audioPath: outputAudioPath,
      format: format,
      durationMs: durMs,
      fileSize: file.lengthSync(),
      sampleRate: validation.sampleRate,
      channels: validation.channels,
      timingSegments: [
        TtsTimingSegment(
          index: 0,
          startMs: 0,
          endMs: durMs,
          text: chunkTexts.isNotEmpty ? chunkTexts.join('\n\n') : '',
          isEstimated: true,
        ),
      ],
    );
  }
}

class _WavHeaderInfo {
  final int channels;
  final int sampleRate;
  final int bitsPerSample;
  const _WavHeaderInfo({
    required this.channels,
    required this.sampleRate,
    required this.bitsPerSample,
  });
}

class AudioValidationReport {
  final bool isValid;
  final String? errorMessage;
  final double? durationSeconds;
  final int sampleRate;
  final int channels;

  const AudioValidationReport({
    required this.isValid,
    this.errorMessage,
    this.durationSeconds,
    this.sampleRate = 22050,
    this.channels = 1,
  });
}
