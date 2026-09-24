import 'package:get/get.dart';

import '../ai_intake/models/ai_action_draft.dart';

/// Demo-only. Holds whatever drafts the ai_intake feature has handed to
/// `DemoActionDraftHandler` so this screen can show exactly what a host app
/// would receive. Registered as a permanent singleton so it survives across
/// navigation between the review screen and this preview screen.
class ActionPreviewController extends GetxController {
  final RxList<AiActionDraft> drafts = <AiActionDraft>[].obs;

  void addDraft(AiActionDraft draft) => drafts.add(draft);

  void clear() => drafts.clear();
}
