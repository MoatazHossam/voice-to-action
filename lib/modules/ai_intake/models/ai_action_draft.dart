import 'action_suggestion.dart';
import 'ai_intake_input.dart';
import 'text_correction.dart';

/// The fully-reviewed, user-approved output of the ai_intake pipeline for a
/// single selected [ActionSuggestion]. This is the only object that crosses
/// the host boundary via `ActionDraftHandler.onActionDraft`. It is inert
/// data — turning it into a real request/meeting/email/task is entirely the
/// host app's responsibility.
class AiActionDraft {
  const AiActionDraft({
    required this.type,
    required this.sourceType,
    required this.originalText,
    required this.reviewedText,
    required this.acceptedCorrections,
    required this.extractedFields,
    required this.unresolvedFields,
    required this.createdAt,
  });

  final ActionType type;
  final AiIntakeSourceType sourceType;

  /// The raw, unedited extraction output (may be empty when the source
  /// extraction was a stub — see [TextExtraction.isStub]).
  final String originalText;

  /// The text after the user's manual edits and any accepted corrections.
  final String reviewedText;

  final List<TextCorrection> acceptedCorrections;
  final Map<String, String> extractedFields;

  /// Required fields the host app's real form will still need to collect.
  final List<String> unresolvedFields;

  final DateTime createdAt;
}
