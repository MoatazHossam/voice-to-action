import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ai_intake_controller.dart';

/// Honest progress: a measured percentage when the engine reports one,
/// otherwise a genuinely indeterminate indicator — never a fake progress
/// bar animated to imply precision the underlying stub does not have.
class ProcessingIndicator extends StatelessWidget {
  const ProcessingIndicator({super.key, required this.controller, required this.label});

  final AiIntakeController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.isProcessing.value) return const SizedBox.shrink();
      final progress = controller.processingProgress.value;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
    });
  }
}
