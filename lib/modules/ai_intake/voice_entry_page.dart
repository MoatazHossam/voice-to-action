import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'ai_intake_controller.dart';
import 'models/ai_intake_step.dart';
import 'widgets/processing_panel.dart';
import 'widgets/recorder_panel.dart';

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
      appBar: AppBar(title: const Text('إدخال صوتي')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Obx(() {
            switch (controller.step.value) {
              case AiIntakeStep.permissionDenied:
                return PermissionDeniedView(controller: controller, onRetry: controller.beginRecording);
              case AiIntakeStep.recording:
                return RecordingView(controller: controller);
              case AiIntakeStep.recordingPreview:
              case AiIntakeStep.transcribing:
                return Column(
                  children: [
                    Expanded(
                      child: RecordingPreviewView(
                        controller: controller,
                        onContinue: () async {
                          await controller.confirmClipProceedToTranscription();
                          if (mounted) Get.toNamed(widget.reviewRouteName);
                        },
                      ),
                    ),
                    ProcessingIndicator(controller: controller, label: 'معالجة محلية على الجهاز...'),
                  ],
                );
              case AiIntakeStep.failure:
                return FailureView(controller: controller, onRetry: controller.enterVoiceFlow);
              case AiIntakeStep.voiceIdle:
              default:
                return VoiceIdleView(controller: controller);
            }
          }),
        ),
      ),
    );
  }
}
