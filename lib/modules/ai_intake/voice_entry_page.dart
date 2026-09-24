import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'ai_intake_controller.dart';
import 'models/ai_intake_step.dart';
import 'widgets/model_setup_panel.dart';
import 'widgets/processing_panel.dart';
import 'widgets/recorder_panel.dart';
import 'widgets/voice_flow_header.dart';

/// Idle voice entry screen plus the recording/preview states that lead into
/// the shared review screen. Route-agnostic: it only calls back into
/// [AiIntakeController]; navigating to the review route is triggered here
/// (the composition root decides the route name via `Get.toNamed`), not
/// inside the portable controller.
class VoiceEntryPage extends StatefulWidget {
  const VoiceEntryPage({super.key, required this.reviewRouteName});

  final String reviewRouteName;

  @override
  State<VoiceEntryPage> createState() => _VoiceEntryPageState();
}

class _VoiceEntryPageState extends State<VoiceEntryPage> {
  late final AiIntakeController controller = Get.find<AiIntakeController>();

  @override
  void initState() {
    super.initState();
    controller.enterVoiceFlow();
  }

  /// Runs the transcription pipeline (which may first have to prepare the
  /// on-device speech model) and only leaves this screen if it actually
  /// reached the review step — a failure, cancellation, or a still-pending
  /// model download must keep the user on this screen showing the
  /// appropriate state, never silently jump to an empty review screen.
  Future<void> _proceedToTranscriptionThenReview() async {
    await controller.confirmClipProceedToTranscription();
    if (mounted && controller.step.value == AiIntakeStep.review) {
      Get.toNamed(widget.reviewRouteName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final step = controller.step.value;
      final active = step == AiIntakeStep.recording ||
          step == AiIntakeStep.preparingModel ||
          step == AiIntakeStep.transcribing;
      return PopScope(
        // Leaving mid-recording, mid-model-download, or mid-transcription
        // must stop the mic / cancel the download / discard the stale
        // result — not just silently abandon the screen.
        canPop: !active,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final navigator = Navigator.of(context);
          if (step == AiIntakeStep.recording) {
            await controller.cancelRecording();
          } else if (step == AiIntakeStep.preparingModel || step == AiIntakeStep.transcribing) {
            controller.cancelProcessing();
          }
          navigator.pop();
        },
        child: Scaffold(
          body: SafeArea(
            bottom: false,
            child: ColoredBox(
              color: const Color(0xFFF7F9FE),
              child: Column(children: [
                if (!active) const VoiceFlowHeader(),
                Expanded(child: _buildStep()),
              ]),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildStep() {
    switch (controller.step.value) {
      case AiIntakeStep.permissionDenied:
        return PermissionDeniedView(controller: controller, onRetry: controller.beginRecording);
      case AiIntakeStep.recording:
        return RecordingView(controller: controller);
      case AiIntakeStep.recordingPreview:
        return RecordingPreviewView(
          controller: controller,
          onContinue: _proceedToTranscriptionThenReview,
        );
      case AiIntakeStep.preparingModel:
        return ModelSetupView(controller: controller, onRetry: _proceedToTranscriptionThenReview);
      case AiIntakeStep.transcribing:
        return ProcessingView(controller: controller);
      case AiIntakeStep.failure:
        return FailureView(controller: controller, onRetry: controller.enterVoiceFlow);
      case AiIntakeStep.voiceIdle:
      default:
        return VoiceIdleView(controller: controller);
    }
  }
}
