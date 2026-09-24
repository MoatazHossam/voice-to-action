import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ai_intake_controller.dart';
import '../models/model_setup_progress.dart';
import 'voice_flow_header.dart';

/// Shown while the on-device Arabic speech model is being downloaded,
/// verified, and installed — a one-time step per install. Every string here
/// is written for a non-technical user: no file paths, host names, script
/// names, or other implementation detail ever appears.
class ModelSetupView extends StatelessWidget {
  const ModelSetupView({super.key, required this.controller, required this.onRetry});

  final AiIntakeController controller;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return VoiceGradientBackground(
      child: Column(
        children: [
          VoiceFlowHeader(onClose: controller.cancelProcessing),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Obx(() {
              final progress = controller.modelSetup.value;
              return switch (progress.status) {
                ModelSetupStatus.offline => _ErrorBody(
                    icon: Icons.wifi_off_rounded,
                    title: 'لا يوجد اتصال بالإنترنت',
                    message:
                        'يلزم اتصال بالإنترنت لتجهيز ميزة تحويل الصوت إلى نص لأول مرة فقط. '
                        'تحقّق من الشبكة ثم أعد المحاولة.',
                    onRetry: onRetry,
                  ),
                ModelSetupStatus.insufficientStorage => _ErrorBody(
                    icon: Icons.sd_storage_outlined,
                    title: 'مساحة التخزين غير كافية',
                    message: 'حرِّر بعض المساحة على جهازك ثم أعد المحاولة.',
                    onRetry: onRetry,
                  ),
                ModelSetupStatus.failed => _ErrorBody(
                    icon: Icons.error_outline,
                    title: 'تعذّر تجهيز الميزة',
                    message: 'حدث خطأ أثناء تجهيز تحويل الصوت إلى نص. حاول مرة أخرى.',
                    onRetry: onRetry,
                  ),
                ModelSetupStatus.downloading ||
                ModelSetupStatus.notStarted ||
                ModelSetupStatus.ready =>
                  _DownloadingBody(progress: progress),
              };
            }),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _DownloadingBody extends StatelessWidget {
  const _DownloadingBody({required this.progress});

  final ModelSetupProgress progress;

  @override
  Widget build(BuildContext context) {
    final fraction = progress.fraction;
    final percent = fraction == null ? null : (fraction * 100).round();
    final total = progress.totalBytes;
    return Column(
      children: [
        const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 48),
        const SizedBox(height: 20),
        const Text(
          'جارٍ تجهيز تحويل الصوت إلى نص لأول مرة',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'يحدث هذا مرة واحدة فقط؛ سيعمل التعرف على الصوت بدون إنترنت بعد ذلك.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: .65), fontSize: 14),
        ),
        const SizedBox(height: 28),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 9,
            backgroundColor: Colors.white.withValues(alpha: .18),
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          percent == null || total == null
              ? 'جارٍ البدء...'
              : '$percent٪ — ${_formatMegabytes(progress.receivedBytes)} من ${_formatMegabytes(total)}',
          style: TextStyle(color: Colors.white.withValues(alpha: .8), fontSize: 13),
        ),
      ],
    );
  }

  static String _formatMegabytes(int bytes) {
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} م.ب.';
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 48),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: .75), fontSize: 14),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black87),
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('إعادة المحاولة'),
        ),
      ],
    );
  }
}
