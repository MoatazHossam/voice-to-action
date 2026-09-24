import '../contracts/action_detector.dart';
import '../models/action_suggestion.dart';

/// Local keyword/pattern rules only — no ML model. This intentionally
/// mirrors README_AI_INTAKE.md's guidance to try "local rules and
/// structured extraction first" for action detection. A single input can
/// yield multiple suggestions (including of the same type) because each
/// keyword match is evaluated independently.
class RuleBasedActionDetector implements ActionDetector {
  static final RegExp _email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+');
  static final RegExp _dateWord =
      RegExp(r'غدًا|غداً|غدا|بكرة|اليوم|بعد غد|\d{1,2}[/-]\d{1,2}(?:[/-]\d{2,4})?');
  static final List<String> _meetingKeywords = ['اجتماع', 'اجتماعاً', 'اجتماعا', 'موعد', 'لقاء'];
  static final List<String> _requestKeywords = ['طلب', 'أنشئ طلب', 'اطلب'];
  static final List<String> _emailKeywords = ['بريد', 'إيميل', 'ايميل', 'أرسل بريد'];
  static final List<String> _taskKeywords = ['مهمة', 'مهام', 'تذكير', 'نفّذ', 'أنجز'];

  @override
  List<ActionSuggestion> detect(String text) {
    if (text.trim().isEmpty) return const [];
    final suggestions = <ActionSuggestion>[];
    var seq = 0;

    void addIfMatched({
      required List<String> keywords,
      required ActionType type,
      required Map<String, String> Function(String evidence) buildFields,
      required List<String> requiredFields,
    }) {
      for (final keyword in keywords) {
        final start = text.indexOf(keyword);
        if (start == -1) continue;
        final evidence = _context(text, start, keyword.length);
        final fields = buildFields(evidence);
        final missing = requiredFields.where((f) => !fields.containsKey(f) || fields[f]!.isEmpty).toList();
        suggestions.add(ActionSuggestion(
          id: '${type.name}-${seq++}',
          type: type,
          evidenceText: evidence,
          extractedFields: fields,
          missingRequiredFields: missing,
        ));
        break; // one suggestion per type per keyword group, not per keyword
      }
    }

    addIfMatched(
      keywords: _meetingKeywords,
      type: ActionType.meeting,
      requiredFields: const ['date', 'attendees'],
      buildFields: (evidence) {
        final fields = <String, String>{};
        final date = _dateWord.firstMatch(text);
        if (date != null) fields['date'] = date.group(0)!;
        final attendees = _afterKeyword(text, 'مع');
        if (attendees != null) fields['attendees'] = attendees;
        return fields;
      },
    );

    addIfMatched(
      keywords: _requestKeywords,
      type: ActionType.newRequest,
      requiredFields: const ['category', 'description'],
      buildFields: (evidence) {
        final fields = <String, String>{'description': evidence};
        final category = _afterKeyword(text, 'طلب');
        if (category != null) fields['category'] = category;
        return fields;
      },
    );

    addIfMatched(
      keywords: _emailKeywords,
      type: ActionType.email,
      requiredFields: const ['recipient', 'subject'],
      buildFields: (evidence) {
        final fields = <String, String>{};
        final email = _email.firstMatch(text);
        if (email != null) fields['recipient'] = email.group(0)!;
        final subject = _afterKeyword(text, 'بخصوص') ?? _afterKeyword(text, 'عن');
        if (subject != null) fields['subject'] = subject;
        return fields;
      },
    );

    addIfMatched(
      keywords: _taskKeywords,
      type: ActionType.task,
      requiredFields: const ['title', 'dueDate'],
      buildFields: (evidence) {
        final fields = <String, String>{'title': evidence};
        final date = _dateWord.firstMatch(text);
        if (date != null) fields['dueDate'] = date.group(0)!;
        return fields;
      },
    );

    return suggestions;
  }

  static String _context(String text, int matchStart, int matchLength) {
    const window = 24;
    final start = (matchStart - window).clamp(0, text.length);
    final end = (matchStart + matchLength + window).clamp(0, text.length);
    return text.substring(start, end).trim();
  }

  /// Returns up to 3 words following [keyword], or null if not found.
  static String? _afterKeyword(String text, String keyword) {
    final idx = text.indexOf(keyword);
    if (idx == -1) return null;
    final rest = text.substring(idx + keyword.length).trim();
    if (rest.isEmpty) return null;
    final words = rest.split(RegExp(r'\s+')).take(3).join(' ');
    return words.isEmpty ? null : words;
  }
}
