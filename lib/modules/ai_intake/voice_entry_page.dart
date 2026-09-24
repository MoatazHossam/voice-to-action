import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'ai_intake_controller.dart';
import 'models/ai_intake_step.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Obx(() {
          final active = controller.step.value == AiIntakeStep.recording ||
              controller.step.value == AiIntakeStep.transcribing;
          return ColoredBox(
            color: const Color(0xFFF7F9FE),
            child: Column(children: [
              if (!active) const VoiceFlowHeader(),
              Expanded(child: _buildStep()),
            ]),
          );
        }),
      ),
    );
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
          onContinue: () async {
            await controller.confirmClipProceedToTranscription();
            if (mounted) Get.toNamed(widget.reviewRouteName);
          },
        );
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
