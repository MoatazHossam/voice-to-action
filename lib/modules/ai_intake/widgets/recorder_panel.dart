import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ai_intake_controller.dart';
import 'status_banner.dart';
import 'waveform_bar.dart';

class VoiceIdleView extends StatelessWidget {
  const VoiceIdleView({super.key, required this.controller});

  final AiIntakeController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        Icon(Icons.mic_none, size: 96, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 24),
        Text('اضغط للبدء بتسجيل صوتك', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          'يبقى التسجيل على جهازك فقط.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const Spacer(),
        Obx(() => controller.errorMessage.value.isEmpty
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: StatusBanner(kind: StatusBannerKind.error, message: controller.errorMessage.value),
              )),
        FilledButton.icon(
          onPressed: controller.beginRecording,
          icon: const Icon(Icons.fiber_manual_record),
          label: const Text('ابدأ التسجيل'),
        ),
      ],
    );
  }
}

class PermissionDeniedView extends StatelessWidget {
  const PermissionDeniedView({super.key, required this.controller, required this.onRetry});

  final AiIntakeController controller;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.mic_off_outlined, size: 72, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: 16),
        Text('صلاحية الميكروفون مطلوبة', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'فعّل الصلاحية من إعدادات الجهاز للمتابعة.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        OutlinedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
      ],
    );
  }
}

class RecordingView extends StatelessWidget {
  const RecordingView({super.key, required this.controller});

  final AiIntakeController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        Obx(() => Text(
              _formatDuration(controller.elapsed.value),
              style: Theme.of(context).textTheme.displaySmall,
            )),
        const SizedBox(height: 16),
        LiveWaveform(amplitude: controller.amplitude),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(onPressed: controller.cancelRecording, child: const Text('إلغاء')),
            FilledButton.icon(
              onPressed: controller.stopRecording,
              icon: const Icon(Icons.stop),
              label: const Text('إيقاف'),
            ),
          ],
        ),
      ],
    );
  }

  static String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes)}:${two(d.inSeconds.remainder(60))}';
  }
}

class RecordingPreviewView extends StatelessWidget {
  const RecordingPreviewView({super.key, required this.controller, required this.onContinue});

  final AiIntakeController controller;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        Text('تم التسجيل. يمكنك الاستماع قبل المتابعة.', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        Obx(() => IconButton(
              iconSize: 64,
              onPressed: controller.toggleClipPlayback,
              icon: Icon(controller.isPlayingClip.value ? Icons.pause_circle : Icons.play_circle),
            )),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(onPressed: controller.discardClipAndRetry, child: const Text('إعادة التسجيل')),
            Obx(() => FilledButton(
                  onPressed: controller.isProcessing.value ? null : onContinue,
                  child: controller.isProcessing.value
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('متابعة'),
                )),
          ],
        ),
        const SizedBox(height: 8),
        const StatusBanner(
          kind: StatusBannerKind.stub,
          message: 'تحويل الصوت إلى نص عربي غير مفعّل بعد في هذه المرحلة.',
        ),
      ],
    );
  }
}

class FailureView extends StatelessWidget {
  const FailureView({super.key, required this.controller, required this.onRetry});

  final AiIntakeController controller;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: 16),
        Obx(() => Text(controller.errorMessage.value, textAlign: TextAlign.center)),
        const SizedBox(height: 24),
        OutlinedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
      ],
    );
  }
}
