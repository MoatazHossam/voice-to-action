import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart' as record_pkg;

import '../contracts/audio_recorder.dart';

/// Real microphone capture backed by the `record` plugin. Named
/// `DeviceAudioRecorder` (rather than `AudioRecorder`) purely to avoid
/// colliding with the package's own `AudioRecorder` class and with our
/// contract of the same name.
class DeviceAudioRecorder implements AudioRecorder {
  DeviceAudioRecorder() : _recorder = record_pkg.AudioRecorder();

  final record_pkg.AudioRecorder _recorder;
  StreamSubscription<record_pkg.Amplitude>? _amplitudeSub;
  Timer? _elapsedTimer;
  final StreamController<double> _amplitudeController = StreamController.broadcast();
  final StreamController<Duration> _elapsedController = StreamController.broadcast();

  String? _currentPath;
  DateTime? _startedAt;
  bool _isRecording = false;

  @override
  bool get isRecording => _isRecording;

  @override
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  @override
  Stream<Duration> get elapsedStream => _elapsedController.stream;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<bool> requestPermission() => _recorder.hasPermission();

  @override
  Future<void> start() async {
    if (!await _recorder.hasPermission()) {
      throw StateError('Microphone permission was not granted.');
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/ai_intake_${DateTime.now().microsecondsSinceEpoch}.wav';
    await _recorder.start(
      // 16kHz mono PCM WAV: the format the on-device Whisper adapter needs
      // directly, with no separate transcoding step.
      const record_pkg.RecordConfig(
        encoder: record_pkg.AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    _currentPath = path;
    _startedAt = DateTime.now();
    _isRecording = true;

    _amplitudeSub?.cancel();
    _amplitudeSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 150))
        .listen((amp) {
      // dBFS is typically in [-45, 0]; normalize to 0..1 for a waveform bar.
      final normalized = ((amp.current + 45) / 45).clamp(0.0, 1.0);
      _amplitudeController.add(normalized);
    });

    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final started = _startedAt;
      if (started != null) {
        _elapsedController.add(DateTime.now().difference(started));
      }
    });
  }

  @override
  Future<String?> stop() async {
    final path = await _recorder.stop();
    _isRecording = false;
    _amplitudeSub?.cancel();
    _elapsedTimer?.cancel();
    if (path == null || !File(path).existsSync()) return null;
    final durationOk = _startedAt != null &&
        DateTime.now().difference(_startedAt!) > const Duration(milliseconds: 300);
    if (!durationOk) {
      await File(path).delete().catchError((_) => File(path));
      return null;
    }
    return path;
  }

  @override
  Future<void> cancel() async {
    if (_isRecording) {
      await _recorder.stop();
      _isRecording = false;
    }
    _amplitudeSub?.cancel();
    _elapsedTimer?.cancel();
    final path = _currentPath;
    if (path != null && File(path).existsSync()) {
      await File(path).delete().catchError((_) => File(path));
    }
    _currentPath = null;
  }

  @override
  void dispose() {
    _amplitudeSub?.cancel();
    _elapsedTimer?.cancel();
    _amplitudeController.close();
    _elapsedController.close();
    _recorder.dispose();
  }
}
