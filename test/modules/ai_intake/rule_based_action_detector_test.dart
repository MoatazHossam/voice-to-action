import 'package:flutter_test/flutter_test.dart';
import 'package:voice_to_action/modules/ai_intake/models/action_suggestion.dart';
import 'package:voice_to_action/modules/ai_intake/services/rule_based_action_detector.dart';

void main() {
  late RuleBasedActionDetector detector;

  setUp(() => detector = RuleBasedActionDetector());

  test('empty text yields no suggestions', () {
    expect(detector.detect(''), isEmpty);
    expect(detector.detect('   '), isEmpty);
  });

  test('a single combined sentence yields both a request and a meeting suggestion', () {
    // Exact acceptance-criteria example from README_AI_INTAKE.md.
    const text = 'أنشئ طلب صيانة للتكييف وحدد اجتماعاً غداً مع الفريق';
    final suggestions = detector.detect(text);

    expect(suggestions.map((s) => s.type), containsAll([ActionType.newRequest, ActionType.meeting]));
    final meeting = suggestions.firstWhere((s) => s.type == ActionType.meeting);
    expect(meeting.extractedFields['date'], anyOf('غداً', 'غدا', 'غدًا'));
  });

  test('plain text with no keywords yields no suggestions', () {
    expect(detector.detect('هذا نص عادي بدون أي إجراء محدد'), isEmpty);
  });

  test('email keyword with an address extracts the recipient field', () {
    final suggestions = detector.detect('أرسل بريد إلى ahmed@example.com بخصوص التقرير الشهري');
    final email = suggestions.firstWhere((s) => s.type == ActionType.email);
    expect(email.extractedFields['recipient'], 'ahmed@example.com');
  });

  test('missing required fields are reported, not silently dropped', () {
    final suggestions = detector.detect('لدي مهمة');
    final task = suggestions.firstWhere((s) => s.type == ActionType.task);
    expect(task.missingRequiredFields, contains('dueDate'));
  });

  test('detected suggestions never carry a fabricated confidence score', () {
    final suggestions = detector.detect('اجتماع غداً مع الفريق');
    for (final s in suggestions) {
      expect(s.confidence, isNull);
    }
  });
}
