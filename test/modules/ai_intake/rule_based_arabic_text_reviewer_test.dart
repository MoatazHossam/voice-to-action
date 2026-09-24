import 'package:flutter_test/flutter_test.dart';
import 'package:voice_to_action/modules/ai_intake/services/rule_based_arabic_text_reviewer.dart';

void main() {
  late RuleBasedArabicTextReviewer reviewer;

  setUp(() => reviewer = RuleBasedArabicTextReviewer());

  test('suggests removing decorative tatweel runs', () {
    final corrections = reviewer.suggestCorrections('مرحبـــا بك');
    expect(corrections, isNotEmpty);
    expect(corrections.first.proposedSpan, isEmpty);
  });

  test('suggests collapsing repeated whitespace', () {
    final corrections = reviewer.suggestCorrections('نص  فيه   مسافات');
    expect(corrections.any((c) => c.proposedSpan == ' '), isTrue);
  });

  test('corrections start unaccepted and only apply once accepted', () {
    final corrections = reviewer.suggestCorrections('مرحبـــا بك');
    expect(corrections.every((c) => !c.accepted), isTrue);

    final unchanged = reviewer.applyAccepted('مرحبـــا بك', corrections);
    expect(unchanged, 'مرحبـــا بك');

    final accepted = corrections.map((c) => c.copyWith(accepted: true)).toList();
    final changed = reviewer.applyAccepted('مرحبـــا بك', accepted);
    expect(changed, 'مرحبا بك');
  });

  test('protected entities (email, amount, date, invoice id) are never touched', () {
    const text = 'التواصل عبر ali.ahmed@example.com  بخصوص فاتورة #12345 بمبلغ 500 درهم بتاريخ 12/05/2026';
    final corrections = reviewer.suggestCorrections(text);

    for (final c in corrections) {
      expect(text.contains('ali.ahmed@example.com'), isTrue);
      expect(c.originalSpan.contains('@'), isFalse);
      expect(c.originalSpan.contains('#12345'), isFalse);
      expect(c.originalSpan.contains('500'), isFalse);
      expect(c.originalSpan.contains('12/05/2026'), isFalse);
    }
  });
}
