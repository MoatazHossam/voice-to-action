/// Where an [AiIntakeInput] came from. Kept intentionally small: this POC
/// only supports capturing audio or a still image on-device.
enum AiIntakeSourceType { audio, image }

/// The raw capture handed from a recorder/camera adapter into the rest of
/// the ai_intake pipeline. `localPath` always points at a file already on
/// device storage — this module never receives or produces remote URLs.
class AiIntakeInput {
  const AiIntakeInput({
    required this.sourceType,
    required this.localPath,
    required this.capturedAt,
    this.captureMetadata = const {},
  });

  final AiIntakeSourceType sourceType;
  final String localPath;
  final DateTime capturedAt;

  /// Free-form, source-specific metadata (e.g. `{'durationMs': 4210}` for
  /// audio, or `{'source': 'camera', 'width': 3024}` for an image). Kept as
  /// a plain map so this model never depends on a capture package's types.
  final Map<String, Object?> captureMetadata;
}
