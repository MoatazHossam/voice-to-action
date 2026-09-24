import 'dart:async';

import 'package:audioplayers/audioplayers.dart' as audioplayers_pkg;

import '../contracts/audio_playback.dart';

/// Plays a local file path only. Intentionally independent from the old
/// chat `AudioPlayerController`: no remote download, no `AppConstants`, no
/// `ChatPostModel`, no token-bearing URLs — and it updates these broadcast
/// streams rather than ever replacing an Rx observable wholesale.
class LocalAudioPlayback implements AudioPlayback {
  LocalAudioPlayback() : _player = audioplayers_pkg.AudioPlayer() {
    _stateSub = _player.onPlayerStateChanged.listen((state) {
      _isPlaying = state == audioplayers_pkg.PlayerState.playing;
      _isPlayingController.add(_isPlaying);
    });
    _positionSub = _player.onPositionChanged.listen(_positionController.add);
  }

  final audioplayers_pkg.AudioPlayer _player;
  StreamSubscription<audioplayers_pkg.PlayerState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;

  bool _isPlaying = false;
  final StreamController<bool> _isPlayingController = StreamController.broadcast();
  final StreamController<Duration> _positionController = StreamController.broadcast();

  @override
  bool get isPlaying => _isPlaying;

  @override
  Stream<bool> get isPlayingStream => _isPlayingController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Future<Duration?> load(String localPath) async {
    await _player.setSource(audioplayers_pkg.DeviceFileSource(localPath));
    return _player.getDuration();
  }

  @override
  Future<void> play() => _player.resume();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  void dispose() {
    _stateSub?.cancel();
    _positionSub?.cancel();
    _isPlayingController.close();
    _positionController.close();
    _player.dispose();
  }
}
