/// Small, independent local playback adapter so the user can listen to a
/// just-recorded clip before it is sent for transcription. Deliberately
/// separate from `AudioRecorder` and unrelated to the old chat
/// `AudioPlayerController` (no remote download, no `ChatPostModel`, no
/// token-bearing URLs) — this only ever plays a local file path.
abstract class AudioPlayback {
  bool get isPlaying;

  Stream<bool> get isPlayingStream;

  Stream<Duration> get positionStream;

  Future<Duration?> load(String localPath);

  Future<void> play();

  Future<void> pause();

  Future<void> stop();

  void dispose();
}
