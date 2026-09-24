import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'ai_intake_controller.dart';
import 'widgets/action_suggestions_panel.dart';
import 'widgets/review_panel.dart';

/// Shared review screen for both the voice and image journeys. Displays the
/// original extraction, an editable final text, opt-in corrections, and
/// action suggestions with their extracted/missing fields. Nothing here
/// executes an action — confirming only calls the injected
/// `ActionDraftHandler` via the controller.
///
/// `onAfterConfirm` is supplied by the composition root (app/app_routes.dart)
/// so this page never has to know a concrete route name for wherever drafts
/// are previewed — keeping this module free of app-specific routing.
class ReviewPage extends StatelessWidget {
  const ReviewPage({super.key, required this.onAfterConfirm});

  final VoidCallback onAfterConfirm;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AiIntakeController>();
    return Scaffold(
      appBar: AppBar(title: const Text('مراجعة النص والإجراءات')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            ExtractionSummary(controller: controller),
            Text('النص للمراجعة', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            ReviewedTextField(controller: controller),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: controller.canAnalyze ? controller.analyzeReviewedText : null,
                icon: const Icon(Icons.search),
                label: const Text('تحليل النص'),
              ),
            ),
            const SizedBox(height: 20),
            CorrectionsList(controller: controller),
            const SizedBox(height: 12),
            ActionSuggestionsList(controller: controller),
            const SizedBox(height: 24),
            Obx(() => FilledButton(
                  onPressed: controller.selectedSuggestionIds.isEmpty
                      ? null
                      : () {
                          controller.confirmSelectedDrafts();
                          onAfterConfirm();
                        },
                  child: Text(
                    controller.selectedSuggestionIds.isEmpty
                        ? 'اختر إجراءً واحدًا على الأقل'
                        : 'معاينة المسودّات (${controller.selectedSuggestionIds.length})',
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
