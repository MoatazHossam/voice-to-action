import 'package:get/get.dart';

import '../ai_intake/contracts/action_draft_handler.dart';
import '../ai_intake/models/ai_action_draft.dart';
import 'action_preview_controller.dart';

/// The demo shell's implementation of the ai_intake host callback. It only
/// stores the draft for `ActionPreviewPage` to render — it never sends an
/// email, schedules a meeting, creates a task, or submits a request.
///
/// A real host app would implement `ActionDraftHandler` itself and instead
/// route each draft's `extractedFields`/`unresolvedFields` into its actual
/// request/meeting/email/task form (see ARCHITECTURE.md).
class DemoActionDraftHandler implements ActionDraftHandler {
  @override
  void onActionDraft(AiActionDraft draft) {
    final controller = Get.isRegistered<ActionPreviewController>()
        ? Get.find<ActionPreviewController>()
        : Get.put(ActionPreviewController(), permanent: true);
    controller.addDraft(draft);
  }
}
