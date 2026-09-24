/// A single proposed change to the reviewed text. Corrections are always
/// opt-in: [accepted] starts `false` and the user must explicitly approve
/// each one before it is folded into a draft's `reviewedText`.
class TextCorrection {
  const TextCorrection({
    required this.id,
    required this.originalSpan,
    required this.proposedSpan,
    required this.reason,
    this.accepted = false,
  });

  final String id;
  final String originalSpan;
  final String proposedSpan;

  /// Human-readable rationale shown next to the suggestion, e.g. "Remove
  /// stray tatweel (ـ) characters" or "Collapse repeated whitespace". This
  /// POC only ships narrow, deterministic rules — never claim this is a
  /// full grammar/spelling model.
  final String reason;

  final bool accepted;

  TextCorrection copyWith({bool? accepted}) => TextCorrection(
        id: id,
        originalSpan: originalSpan,
        proposedSpan: proposedSpan,
        reason: reason,
        accepted: accepted ?? this.accepted,
      );
}
