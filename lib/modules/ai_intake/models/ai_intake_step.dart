/// The state machine for a single ai_intake session, matching the journeys
/// documented for the feature:
///
/// Voice: idle -> permissionDenied -> recording -> recordingPreview ->
///        [preparingModel ->] transcribing -> review
/// Image: imageIdle -> imagePreview -> extractingText -> review
///
/// `review` is shared by both journeys. `preparingModel` only appears the
/// first time on-device Arabic speech-to-text is used (or after its model
/// files are missing/corrupted) — see `SpeechModelProvisioner`.
enum AiIntakeStep {
  voiceIdle,
  permissionDenied,
  recording,
  recordingPreview,
  preparingModel,
  transcribing,
  imageIdle,
  imagePreview,
  extractingText,
  review,
  failure,
}
