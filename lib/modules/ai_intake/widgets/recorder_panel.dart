import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ai_intake_controller.dart';
import 'status_banner.dart';
import 'waveform_bar.dart';
import 'voice_flow_header.dart';

class VoiceIdleView extends StatelessWidget {
  const VoiceIdleView({super.key, required this.controller});
  final AiIntakeController controller;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(children: [
          const SizedBox(height: 58),
          GestureDetector(
            onTap: controller.beginRecording,
            child: Container(
              width: 118,
              height: 118,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2589DE), Color(0xFF07589C)]),
                boxShadow: [BoxShadow(color: Color(0x550B65AC), blurRadius: 25, offset: Offset(0, 14))],
              ),
              child: const Icon(Icons.mic_none_rounded, color: Colors.white, size: 48),
            ),
          ),
          const SizedBox(height: 25),
          const Text('اضغط لبدء التسجيل', style: TextStyle(fontSize: 20, color: Color(0xFF20242B), fontWeight: FontWeight.w500)),
          const SizedBox(height: 15),
          const Text('تحدّث بوضوح — سنحوّل كلامك إلى مهمة أو اجتماع', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Color(0xFF858B98))),
          const Spacer(),
          Obx(() => controller.errorMessage.value.isEmpty
              ? const SizedBox.shrink()
              : Padding(padding: const EdgeInsets.only(bottom: 24), child: StatusBanner(kind: StatusBannerKind.error, message: controller.errorMessage.value))),
        ]),
      );
}

class PermissionDeniedView extends StatelessWidget {
  const PermissionDeniedView({super.key, required this.controller, required this.onRetry});
  final AiIntakeController controller;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.mic_off_outlined, size: 72, color: Color(0xFFE62E35)),
    const SizedBox(height: 18),
    const Text('صلاحية الميكروفون مطلوبة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
    const SizedBox(height: 8),
    const Text('فعّل الصلاحية من إعدادات الجهاز للمتابعة.', textAlign: TextAlign.center),
    const SizedBox(height: 24),
    OutlinedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
  ])));
}

class RecordingView extends StatelessWidget {
  const RecordingView({super.key, required this.controller});
  final AiIntakeController controller;

  @override
  Widget build(BuildContext context) => VoiceGradientBackground(
        child: Column(children: [
          VoiceFlowHeader(onClose: controller.cancelRecording),
          const Spacer(),
          Stack(alignment: Alignment.center, children: [
            Container(width: 350, height: 350, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .035))),
            Container(width: 158, height: 158, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .09))),
            Container(width: 138, height: 138, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFFFF4545), Color(0xFFD7131E)])), child: const Icon(Icons.mic_none_rounded, size: 55, color: Colors.white)),
          ]),
          Obx(() => Text(_formatDuration(controller.elapsed.value), style: const TextStyle(fontSize: 48, height: 1, fontWeight: FontWeight.w800, color: Colors.white))),
          const SizedBox(height: 55),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 68), child: LiveWaveform(amplitude: controller.amplitude)),
          const SizedBox(height: 36),
          Text('جارِ الاستماع — تحدّث بوضوح', style: TextStyle(color: Colors.white.withValues(alpha: .55), fontSize: 16)),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: voiceBlue, minimumSize: const Size.fromHeight(66)),
              onPressed: controller.stopRecording,
              icon: const Icon(Icons.check_rounded),
              label: const Text('إيقاف والتحويل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      );

  static String _formatDuration(Duration d) => '${d.inMinutes.toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
}

class RecordingPreviewView extends StatelessWidget {
  const RecordingPreviewView({super.key, required this.controller, required this.onContinue});
  final AiIntakeController controller;
  final VoidCallback onContinue;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(children: [
          const Spacer(),
          const Text('تم التسجيل بنجاح', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          Obx(() => IconButton(iconSize: 78, color: voiceBlue, onPressed: controller.toggleClipPlayback, icon: Icon(controller.isPlayingClip.value ? Icons.pause_circle_filled : Icons.play_circle_fill))),
          const Spacer(),
          FilledButton(onPressed: onContinue, child: const Text('تحويل الصوت إلى نص')),
          TextButton(onPressed: controller.discardClipAndRetry, child: const Text('إعادة التسجيل')),
        ]),
      );
}

class FailureView extends StatelessWidget {
  const FailureView({super.key, required this.controller, required this.onRetry});
  final AiIntakeController controller;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.error_outline, size: 64, color: Color(0xFFE62E35)),
    const SizedBox(height: 16),
    Obx(() => Text(controller.errorMessage.value, textAlign: TextAlign.center)),
    const SizedBox(height: 24),
    OutlinedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
  ])));
}
