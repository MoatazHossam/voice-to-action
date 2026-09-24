import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ai_intake/widgets/status_banner.dart';
import 'action_preview_controller.dart';
import 'widgets/draft_preview_card.dart';

/// DEMO ONLY. Shows exactly what a host app's `ActionDraftHandler` would
/// receive for each accepted suggestion. Nothing on this screen is wired to
/// a real request/meeting/email/task backend — a real host app replaces
/// this whole page with its own forms.
class ActionPreviewPage extends GetView<ActionPreviewController> {
  const ActionPreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('معاينة المسودّات'),
        actions: [
          IconButton(
            tooltip: 'مسح',
            onPressed: controller.clear,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StatusBanner(
                kind: StatusBannerKind.stub,
                message: 'معاينة فقط — لن يتم إرسال بريد أو جدولة اجتماع أو إنشاء طلب/مهمة فعليًا.',
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Obx(() {
                  if (controller.drafts.isEmpty) {
                    return const Center(child: Text('لا توجد مسودّات بعد.'));
                  }
                  return ListView.separated(
                    itemCount: controller.drafts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => DraftPreviewCard(
                      draft: controller.drafts[index],
                      index: index,
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
