import '../models/model_setup_progress.dart';

/// Makes whatever on-device model a real `SpeechTranscriber` needs available
/// without any manual/developer step: fetch it once, verify it, install it,
/// and reuse it on every later launch. A host app can swap this out (e.g.
/// for a different model or distribution strategy) without touching the
/// transcriber or the controller.
abstract class SpeechModelProvisioner {
  ModelSetupProgress get currentProgress;

  Stream<ModelSetupProgress> get progressStream;

  /// Known ahead of time (no network round-trip needed) so the UI can show
  /// an estimated download size immediately.
  int get estimatedTotalBytes;

  /// Resolves once the model is installed and verified (`true`), or once a
  /// terminal failure is reached (`false`) — check `currentProgress.status`
  /// for which kind, to render the right retry/offline/storage state.
  /// Safe to call again after a failure: it resumes/repairs rather than
  /// starting over from zero.
  Future<bool> ensureReady();

  /// Best-effort: stops any in-flight download. Already-verified files are
  /// kept; a partially-downloaded file is left in place so a later
  /// `ensureReady()` call can resume it.
  void cancel();

  void dispose();
}
