import 'package:get/get.dart';

import '../modules/action_preview/action_preview_binding.dart';
import '../modules/action_preview/action_preview_page.dart';
import '../modules/action_preview/demo_action_draft_handler.dart';
import '../modules/ai_intake/ai_intake_binding.dart';
import '../modules/ai_intake/image_entry_page.dart';
import '../modules/ai_intake/review_page.dart';
import '../modules/ai_intake/voice_entry_page.dart';
import '../modules/home/home_binding.dart';
import '../modules/home/home_page.dart';

/// The only place in this app that wires the portable ai_intake feature to
/// the demo shell: it supplies `DemoActionDraftHandler` as the concrete
/// `ActionDraftHandler` and decides the review/preview route names.
/// modules/ai_intake itself never references any of these names.
abstract final class AppRoutes {
  static const home = '/home';
  static const aiIntakeVoice = '/ai-intake/voice';
  static const aiIntakeImage = '/ai-intake/image';
  static const aiIntakeReview = '/ai-intake/review';
  static const actionPreview = '/action-preview';

  static final AiIntakeBinding _aiIntakeBinding =
      AiIntakeBinding(actionDraftHandler: () => DemoActionDraftHandler());

  static final List<GetPage> pages = [
    GetPage(name: home, page: () => const HomePage(), binding: HomeBinding()),
    GetPage(
      name: aiIntakeVoice,
      page: () => const VoiceEntryPage(reviewRouteName: aiIntakeReview),
      binding: _aiIntakeBinding,
    ),
    GetPage(
      name: aiIntakeImage,
      page: () => const ImageEntryPage(reviewRouteName: aiIntakeReview),
      binding: _aiIntakeBinding,
    ),
    GetPage(
      name: aiIntakeReview,
      page: () => ReviewPage(onAfterConfirm: () => Get.toNamed(actionPreview)),
      binding: _aiIntakeBinding,
    ),
    GetPage(
      name: actionPreview,
      page: () => const ActionPreviewPage(),
      binding: ActionPreviewBinding(),
    ),
  ];
}
