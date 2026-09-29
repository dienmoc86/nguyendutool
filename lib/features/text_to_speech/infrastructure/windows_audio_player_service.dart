import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../../core/logging/app_logger.dart';
import '../application/tts_state.dart';

/// Lightweight native Windows audio playback service using PresentationCore MediaPlayer via standard IPC.
/// Provides real playback, seeking, pause, stop, volume control without requiring heavy external C++ plugins.
class WindowsAudioPlayerService {
  Process? _process;
  StreamSubscription? _stdoutSub;
  Timer? _positionTimer;

  final _statusController = StreamController<AudioPlaybackStatus>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();

  AudioPlaybackStatus _status = AudioPlaybackStatus.idle;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  double _volume = 1.0;
  String? _currentFilePath;
  bool _isDisposed = false;

  WindowsAudioPlayerService() {
    _statusController.add(_status);
  }

  Stream<AudioPlaybackStatus> get statusStream => _statusController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get durationStream => _durationController.stream;

  AudioPlaybackStatus get status => _status;
  Duration get position => _currentPosition;
  Duration get duration => _totalDuration;
  double get volume => _volume;
  String? get currentFilePath => _currentFilePath;

  Future<void> _ensureProcess() async {
    if (_process != null) return;
    if (!Platform.isWindows) {
      AppLogger.info('WindowsAudioPlayerService: Non-Windows platform fallback mode.');
      return;
    }

    try {
      const script = r'''
Add-Type -AssemblyName presentationCore
$player = New-Object System.Windows.Media.MediaPlayer

while ($true) {
    $line = [Console]::ReadLine()
    if ($null -eq $line) { break }
    $parts = $line.Trim().Split(' ', 2)
    $cmd = $parts[0].ToUpper()
    $arg = if ($parts.Length -gt 1) { $parts[1] } else { "" }

    try {
        switch ($cmd) {
            "OPEN" {
                $uri = New-Object System.Uri($arg)
                $player.Open($uri)
                Write-Host "OPENED"
            }
            "PLAY" {
                $player.Play()
                Write-Host "PLAYING"
            }
            "PAUSE" {
                $player.Pause()
                Write-Host "PAUSED"
            }
            "STOP" {
                $player.Stop()
                Write-Host "STOPPED"
            }
            "SEEK" {
                $ms = [int]$arg
                $player.Position = [TimeSpan]::FromMilliseconds($ms)
                Write-Host "SEEKED $ms"
            }
            "VOLUME" {
                $vol = [double]$arg
                $player.Volume = $vol
                Write-Host "VOLUME $vol"
            }
            "STATUS" {
                $pos = if ($player.Position) { [int]$player.Position.TotalMilliseconds } else { 0 }
                $dur = if ($player.NaturalDuration.HasTimeSpan) { [int]$player.NaturalDuration.TimeSpan.TotalMilliseconds } else { 0 }
                Write-Host "STATUS $pos $dur"
            }
            "EXIT" {
                exit 0
            }
        }
    } catch {
        Write-Host "ERROR: $_"
    }
}
''';

      _process = await Process.start(
        'powershell',
        ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', script],
        mode: ProcessStartMode.normal,
      );

      _stdoutSub = _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_handleWorkerOutput, onError: (e) {
        AppLogger.error('Audio player worker stdout error: $e');
      });

      _process!.exitCode.then((code) {
        _process = null;
        if (!_isDisposed) {
          _updateStatus(AudioPlaybackStatus.idle);
        }
      });
    } catch (e, st) {
      AppLogger.error('Failed to spawn WindowsAudioPlayer worker', e, st);
    }
  }

  void _handleWorkerOutput(String line) {
    final trimmed = line.trim();
    if (trimmed.startsWith('STATUS ')) {
      final parts = trimmed.split(' ');
      if (parts.length >= 3) {
        final posMs = int.tryParse(parts[1]) ?? 0;
        final durMs = int.tryParse(parts[2]) ?? 0;

        _currentPosition = Duration(milliseconds: posMs);
        _positionController.add(_currentPosition);

        if (durMs > 0 && durMs != _totalDuration.inMilliseconds) {
          _totalDuration = Duration(milliseconds: durMs);
          _durationController.add(_totalDuration);
        }

        if (durMs > 0 && posMs >= durMs - 200 && _status == AudioPlaybackStatus.playing) {
          _updateStatus(AudioPlaybackStatus.completed);
          _stopPositionTimer();
        }
      }
    } else if (trimmed == 'OPENED') {
      _updateStatus(AudioPlaybackStatus.stopped);
    } else if (trimmed == 'PLAYING') {
      _updateStatus(AudioPlaybackStatus.playing);
      _startPositionTimer();
    } else if (trimmed == 'PAUSED') {
      _updateStatus(AudioPlaybackStatus.paused);
      _stopPositionTimer();
    } else if (trimmed == 'STOPPED') {
      _updateStatus(AudioPlaybackStatus.stopped);
      _currentPosition = Duration.zero;
      _positionController.add(_currentPosition);
      _stopPositionTimer();
    } else if (trimmed.startsWith('ERROR')) {
      AppLogger.warning('Audio player worker error: $trimmed');
    }
  }

  void _sendCommand(String cmd) {
    if (_process != null) {
      try {
        _process!.stdin.writeln(cmd);
      } catch (e) {
        AppLogger.warning('Failed to send command to audio player worker: $e');
      }
    }
  }

  /// Opens an audio file for playback.
  Future<void> open(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      _updateStatus(AudioPlaybackStatus.error);
      throw Exception('Tệp âm thanh không tồn tại: $filePath');
    }

    _currentFilePath = filePath;
    _updateStatus(AudioPlaybackStatus.loading);

    await _ensureProcess();
    final uriStr = file.uri.toString();
    _sendCommand('OPEN $uriStr');
    _sendCommand('VOLUME $_volume');
  }

  /// Starts or resumes playback.
  Future<void> play() async {
    if (_currentFilePath == null) return;
    await _ensureProcess();
    _sendCommand('PLAY');
    _updateStatus(AudioPlaybackStatus.playing);
    _startPositionTimer();
  }

  /// Pauses playback.
  Future<void> pause() async {
    _sendCommand('PAUSE');
    _updateStatus(AudioPlaybackStatus.paused);
    _stopPositionTimer();
  }

  /// Stops playback.
  Future<void> stop() async {
    _sendCommand('STOP');
    _updateStatus(AudioPlaybackStatus.stopped);
    _stopPositionTimer();
  }

  /// Seeks to a specific [position].
  Future<void> seek(Duration position) async {
    _currentPosition = position;
    _positionController.add(_currentPosition);
    _sendCommand('SEEK ${position.inMilliseconds}');
  }

  /// Sets volume (0.0 to 1.0).
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    _sendCommand('VOLUME $_volume');
  }

  void _startPositionTimer() {
    _stopPositionTimer();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_status == AudioPlaybackStatus.playing) {
        _sendCommand('STATUS');
      }
    });
  }

  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  void _updateStatus(AudioPlaybackStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(_status);
    }
  }

  Future<void> dispose() async {
    _isDisposed = true;
    _stopPositionTimer();
    _sendCommand('EXIT');
    await _stdoutSub?.cancel();
    _process?.kill();
    _process = null;
    await _statusController.close();
    await _positionController.close();
    await _durationController.close();
  }
}
