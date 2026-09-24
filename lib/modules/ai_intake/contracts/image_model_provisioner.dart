import '../models/model_setup_progress.dart';

/// Makes whatever on-device model a real `ImageTextExtractor` needs
/// available without any manual/developer step: fetch it once, verify it,
/// install it, and reuse it on every later launch. Structurally identical to
/// `SpeechModelProvisioner` (both just manage a small set of downloadable,
/// checksum-verified files) but kept as its own type since the two
/// features' setup can proceed independently and a host may swap either one
/// separately.
abstract class ImageModelProvisioner {
  ModelSetupProgress get currentProgress;

  Stream<ModelSetupProgress> get progressStream;

  /// Known ahead of time (no network round-trip needed) so the UI can show
  /// an estimated download size immediately.
  int get estimatedTotalBytes;

  /// Resolves once the model is installed and verified (`true`), or once a
  /// terminal failure is reached (`false`) — check `currentProgress.status`
  /// for which kind, to render the right retry/offline/storage state.
  /// Safe to call again after a failure: it resumes/repairs rather than
  /// starting over from zero. Never throws — any unexpected error (including
  /// one raised while finalizing installation) is caught and reported as a
  /// terminal status instead of leaving a caller's `await` unresolved.
  Future<bool> ensureReady();

  /// Best-effort: stops any in-flight download. Already-verified files are
  /// kept; a partially-downloaded file is left in place so a later
  /// `ensureReady()` call can resume it.
  void cancel();

  void dispose();
}
