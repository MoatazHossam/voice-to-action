/// The state machine for a single ai_intake session, matching the journeys
/// documented for the feature:
///
/// Voice: idle -> permissionDenied -> recording -> recordingPreview ->
///        transcribing -> review
/// Image: imageIdle -> imagePreview -> extractingText -> review
///
/// `review` is shared by both journeys.
enum AiIntakeStep {
  voiceIdle,
  permissionDenied,
  recording,
  recordingPreview,
  transcribing,
  imageIdle,
  imagePreview,
  extractingText,
  review,
  failure,
}
