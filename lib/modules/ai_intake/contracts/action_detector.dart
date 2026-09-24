import '../models/action_suggestion.dart';

/// Finds zero, one, or multiple action suggestions in reviewed text. A
/// single input (e.g. "أنشئ طلب صيانة للتكييف وحدد اجتماعاً غداً مع الفريق")
/// may legitimately produce more than one suggestion of different types.
/// Detecting an action never executes it.
abstract class ActionDetector {
  List<ActionSuggestion> detect(String text);
}
