import '../models/text_correction.dart';

/// Proposes Arabic spelling/normalization corrections for review. This is a
/// narrow, deterministic contract on purpose — a full grammar model is an
/// open POC decision (see README_AI_INTAKE.md); implementations must label
/// themselves honestly rather than imply ML-grade correction.
abstract class ArabicTextReviewer {
  /// True protected-entity awareness is enforced by the implementation:
  /// suggestions must not alter names, monetary amounts, dates, emails,
  /// invoice numbers, or IDs.
  List<TextCorrection> suggestCorrections(String text);

  /// Re-applies exactly the corrections whose `id` is in [acceptedIds] onto
  /// [baseText], leaving everything else untouched.
  String applyAccepted(String baseText, List<TextCorrection> corrections);
}
