import '../models/ai_action_draft.dart';

/// The single seam a host app implements to receive reviewed drafts. This
/// is the *only* way ai_intake ever communicates a result outward — it
/// never navigates to, imports, or knows about whatever the host does with
/// a draft.
///
/// This demo shell's implementation (`DemoActionDraftHandler`, in
/// modules/action_preview) opens a read-only preview screen. A real host
/// app would instead route each draft to its existing request/meeting/
/// email/task form, pre-filling `extractedFields` and asking the user to
/// resolve `unresolvedFields`.
abstract class ActionDraftHandler {
  void onActionDraft(AiActionDraft draft);
}
