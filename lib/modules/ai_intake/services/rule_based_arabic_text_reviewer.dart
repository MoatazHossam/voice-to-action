import '../contracts/arabic_text_reviewer.dart';
import '../models/text_correction.dart';

/// Narrow, deterministic Arabic normalization — NOT a grammar or spelling
/// model. Only two safe, reversible rules ship in this milestone:
///
///  1. Remove decorative tatweel/kashida runs (ـــ).
///  2. Collapse repeated whitespace into a single space.
///
/// Both rules skip matches inside protected entities (emails, numbers/
/// amounts, and simple date-like tokens) so names, monetary amounts, dates,
/// emails, invoice numbers, and IDs are never altered by a suggestion.
/// Evaluating a real grammar/spelling approach is future work (see
/// README_AI_INTAKE.md, "On-device processing").
class RuleBasedArabicTextReviewer implements ArabicTextReviewer {
  static final RegExp _tatweelRun = RegExp('ـ+');
  static final RegExp _whitespaceRun = RegExp(r'[ \t]{2,}');
  static final RegExp _protectedEntity = RegExp(
    r'[\w.+-]+@[\w-]+\.[\w.-]+' // emails
    r'|\d{1,4}[/-]\d{1,2}[/-]\d{1,4}' // simple dates
    r'|[\d,.]+(?:\s?(?:ريال|درهم|جنيه|دولار|AED|SAR))?' // numbers/amounts
    r'|#[A-Za-z0-9-]+', // invoice/reference numbers
  );

  @override
  List<TextCorrection> suggestCorrections(String text) {
    final protectedRanges = _protectedEntity
        .allMatches(text)
        .map((m) => (m.start, m.end))
        .toList();

    bool overlapsProtected(int start, int end) => protectedRanges.any(
          (r) => start < r.$2 && end > r.$1,
        );

    final corrections = <TextCorrection>[];
    var index = 0;

    for (final match in _tatweelRun.allMatches(text)) {
      if (overlapsProtected(match.start, match.end)) continue;
      corrections.add(TextCorrection(
        id: 'tatweel-${index++}',
        originalSpan: match.group(0)!,
        proposedSpan: '',
        reason: 'إزالة حرف التطويل الزخرفي (ـ) — لا يغيّر المعنى',
      ));
    }

    for (final match in _whitespaceRun.allMatches(text)) {
      if (overlapsProtected(match.start, match.end)) continue;
      corrections.add(TextCorrection(
        id: 'space-${index++}',
        originalSpan: match.group(0)!,
        proposedSpan: ' ',
        reason: 'ضغط المسافات المتكررة إلى مسافة واحدة',
      ));
    }

    return corrections;
  }

  @override
  String applyAccepted(String baseText, List<TextCorrection> corrections) {
    var result = baseText;
    for (final correction in corrections) {
      if (!correction.accepted) continue;
      result = result.replaceFirst(correction.originalSpan, correction.proposedSpan);
    }
    return result;
  }
}
