/// The four draft destinations the demo shell knows how to preview. A host
/// app embedding ai_intake would map each of these to one of its real forms.
enum ActionType { newRequest, meeting, email, task }

/// A candidate action detected in the reviewed text. One input can yield
/// zero, one, or several suggestions (of the same or different [type]s) —
/// nothing here executes anything by itself.
class ActionSuggestion {
  const ActionSuggestion({
    required this.id,
    required this.type,
    required this.evidenceText,
    required this.extractedFields,
    required this.missingRequiredFields,
    this.confidence,
  });

  final String id;
  final ActionType type;

  /// The substring of the reviewed text that triggered this suggestion, so
  /// the user can see exactly why it was proposed.
  final String evidenceText;

  final Map<String, String> extractedFields;

  /// Required fields for [type] that could not be extracted and need the
  /// user (or the host app's real form) to fill in before the action can be
  /// carried out for real.
  final List<String> missingRequiredFields;

  /// Left null by the rule-based detector shipped in this POC: a confidence
  /// score implies a calibrated model, which this milestone does not have.
  final double? confidence;
}
