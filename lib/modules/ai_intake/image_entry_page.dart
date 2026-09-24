import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'ai_intake_controller.dart';
import 'models/ai_intake_step.dart';
import 'widgets/image_input_panel.dart';
import 'widgets/processing_panel.dart';
import 'widgets/recorder_panel.dart';

/// Idle image entry screen plus preview state, leading into the shared
/// review screen. Mirrors [VoiceEntryPage]'s composition pattern.
class ImageEntryPage extends StatefulWidget {
  const ImageEntryPage({super.key, required this.reviewRouteName});

  final String reviewRouteName;

  @override
  State<ImageEntryPage> createState() => _ImageEntryPageState();
}

class _ImageEntryPageState extends State<ImageEntryPage> {
  late final AiIntakeController controller = Get.find<AiIntakeController>();

  @override
  void initState() {
    super.initState();
    controller.enterImageFlow();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final step = controller.step.value;
      final active = step == AiIntakeStep.extractingText;
      return PopScope(
        // Leaving mid-OCR must discard the stale result, not just abandon
        // the screen while the extractor keeps running in the background.
        canPop: !active,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          controller.cancelProcessing();
          if (mounted) Navigator.of(context).pop();
        },
        child: Scaffold(
          appBar: AppBar(title: const Text('إدخال صورة')),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _buildStep(step),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildStep(AiIntakeStep step) {
    switch (step) {
      case AiIntakeStep.permissionDenied:
        return PermissionDeniedView(
          controller: controller,
          onRetry: () => controller.pickImage(fromCamera: true),
        );
      case AiIntakeStep.imagePreview:
      case AiIntakeStep.extractingText:
        return Column(
          children: [
            Expanded(
              child: ImagePreviewView(
                controller: controller,
                onContinue: () async {
                  await controller.confirmImageProceedToOcr();
                  if (mounted) Get.toNamed(widget.reviewRouteName);
                },
              ),
            ),
            ProcessingIndicator(controller: controller, label: 'معالجة محلية على الجهاز...'),
          ],
        );
      case AiIntakeStep.failure:
        return FailureView(controller: controller, onRetry: controller.enterImageFlow);
      case AiIntakeStep.imageIdle:
      default:
        return ImageIdleView(controller: controller);
    }
  }
}
