import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ai_intake_controller.dart';
import 'voice_flow_header.dart';

class ProcessingView extends StatelessWidget {
  const ProcessingView({super.key, required this.controller});
  final AiIntakeController controller;

  @override
  Widget build(BuildContext context) => VoiceGradientBackground(
        child: Column(children: [
          const VoiceFlowHeader(),
          const Spacer(),
          const _StaticWaveform(),
          const SizedBox(height: 52),
          Obx(() {
            final progress = controller.processingProgress.value;
            final percent = progress == null ? null : (progress * 100).round();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('جارِ تحويل الصوت إلى نص...', style: TextStyle(color: Colors.white, fontSize: 16)),
                  Text(percent == null ? '•••' : '$percent%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 10),
                LinearProgressIndicator(value: progress, minHeight: 9, borderRadius: BorderRadius.circular(8), backgroundColor: Colors.white.withValues(alpha: .18), color: Colors.white),
                const SizedBox(height: 14),
                Text('نستخرج التفاصيل من كلامك', style: TextStyle(color: Colors.white.withValues(alpha: .5), fontSize: 15)),
              ]),
            );
          }),
          const Spacer(flex: 2),
        ]),
      );
}

class _StaticWaveform extends StatelessWidget {
  const _StaticWaveform();
  @override
  Widget build(BuildContext context) {
    const heights = [38, 58, 44, 75, 54, 92, 64, 82, 48, 72, 96, 57, 78, 101, 62, 88, 48, 77, 98, 65, 83, 55, 72, 92, 52, 76, 48];
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final height in heights) Container(margin: const EdgeInsets.symmetric(horizontal: 3), width: 4, height: height.toDouble(), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)))]);
  }
}

/// Compact processing status retained for image intake and other shared flows.
class ProcessingIndicator extends StatelessWidget {
  const ProcessingIndicator({super.key, required this.controller, required this.label});
  final AiIntakeController controller;
  final String label;
  @override
  Widget build(BuildContext context) => Obx(() => controller.isProcessing.value
      ? Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [LinearProgressIndicator(value: controller.processingProgress.value), const SizedBox(height: 8), Text(label)]))
      : const SizedBox.shrink());
}
