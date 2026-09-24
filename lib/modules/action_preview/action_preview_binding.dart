import 'package:get/get.dart';

import 'action_preview_controller.dart';

class ActionPreviewBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<ActionPreviewController>()) {
      Get.put(ActionPreviewController(), permanent: true);
    }
  }
}
