/// Where a one-time, app-managed model download/install stands.
enum ModelSetupStatus {
  /// Nothing has been attempted yet, or the model is already installed and
  /// no setup is needed this launch.
  notStarted,

  /// A previously-installed, still-valid model is in use — no network
  /// activity happened this launch.
  ready,

  /// Actively downloading and/or verifying file integrity.
  downloading,

  /// No usable network connection.
  offline,

  /// The device rejected a write for lack of space.
  insufficientStorage,

  /// Any other download/verification failure (bad response, corrupt file,
  /// unexpected I/O error).
  failed,
}

/// A snapshot of setup progress, safe to show directly in UI: it never
/// carries a file path, host name, or other implementation detail — only
/// what a non-technical user needs (status + how much of the download is
/// done).
class ModelSetupProgress {
  const ModelSetupProgress({
    required this.status,
    this.receivedBytes = 0,
    this.totalBytes,
  });

  static const ModelSetupProgress notStartedValue =
      ModelSetupProgress(status: ModelSetupStatus.notStarted);

  final ModelSetupStatus status;
  final int receivedBytes;
  final int? totalBytes;

  bool get isReady => status == ModelSetupStatus.ready;

  bool get isTerminalFailure =>
      status == ModelSetupStatus.offline ||
      status == ModelSetupStatus.insufficientStorage ||
      status == ModelSetupStatus.failed;

  /// 0.0–1.0, or null if not yet meaningful (e.g. before the first byte).
  double? get fraction {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return (receivedBytes / total).clamp(0.0, 1.0);
  }
}
