/// Real, on-device audio capture. Implementations must use an actual
/// recording API (e.g. the platform's microphone input) — never a playback
/// library's controller pretending to record (see README_AI_INTAKE.md's
/// note on audio_waveforms' `PlayerController`).
abstract class AudioRecorder {
  Future<bool> hasPermission();

  Future<bool> requestPermission();

  bool get isRecording;

  /// Normalized (0.0–1.0) amplitude samples for driving a waveform-style UI
  /// while recording.
  Stream<double> get amplitudeStream;

  Stream<Duration> get elapsedStream;

  /// Starts capture to a new on-device temp file. Throws if permission has
  /// not been granted.
  Future<void> start();

  /// Stops capture and returns the local file path, or null if nothing was
  /// captured (e.g. stopped immediately with zero duration).
  Future<String?> stop();

  /// Stops capture (if running) and deletes the partial recording.
  Future<void> cancel();

  void dispose();
}
