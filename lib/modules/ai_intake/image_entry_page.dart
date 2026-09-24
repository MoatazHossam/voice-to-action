import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'ai_intake_controller.dart';
import 'models/ai_intake_step.dart';
import 'widgets/image_input_panel.dart';
import 'widgets/model_setup_panel.dart';
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

  /// Runs the OCR pipeline (which may first have to prepare the on-device
  /// Arabic OCR model) and only leaves this screen if it actually reached
  /// the review step — a failure, cancellation, or a still-pending model
  /// download must keep the user on this screen showing the appropriate
  /// state, never silently jump to an empty review screen.
  Future<void> _proceedToOcrThenReview() async {
    await controller.confirmImageProceedToOcr();
    if (mounted && controller.step.value == AiIntakeStep.review) {
      Get.toNamed(widget.reviewRouteName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final step = controller.step.value;
      final active = step == AiIntakeStep.extractingText || step == AiIntakeStep.preparingModel;
      return PopScope(
        // Leaving mid-OCR or mid-model-download must discard the stale
        // result / cancel the download, not just abandon the screen while
        // it keeps running in the background.
        canPop: !active,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final navigator = Navigator.of(context);
          controller.cancelProcessing();
          navigator.pop();
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
                onContinue: _proceedToOcrThenReview,
              ),
            ),
            ProcessingIndicator(controller: controller, label: 'معالجة محلية على الجهاز...'),
          ],
        );
      case AiIntakeStep.preparingModel:
        return ModelSetupView(
          controller: controller,
          onRetry: _proceedToOcrThenReview,
          featureLabel: 'استخراج النص من الصورة',
        );
      case AiIntakeStep.failure:
        return FailureView(controller: controller, onRetry: controller.enterImageFlow);
      case AiIntakeStep.imageIdle:
      default:
        return ImageIdleView(controller: controller);
    }
  }
}
