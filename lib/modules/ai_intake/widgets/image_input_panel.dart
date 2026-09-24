import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ai_intake_controller.dart';
import 'status_banner.dart';

class ImageIdleView extends StatelessWidget {
  const ImageIdleView({super.key, required this.controller});

  final AiIntakeController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        Icon(Icons.image_outlined, size: 96, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 24),
        Text('التقط صورة أو اخترها من المعرض', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
        const Spacer(),
        Obx(() => controller.errorMessage.value.isEmpty
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: StatusBanner(kind: StatusBannerKind.error, message: controller.errorMessage.value),
              )),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => controller.pickImage(fromCamera: true),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('الكاميرا'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => controller.pickImage(fromCamera: false),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('المعرض'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ImagePreviewView extends StatelessWidget {
  const ImagePreviewView({super.key, required this.controller, required this.onContinue});

  final AiIntakeController controller;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Obx(() {
            final path = controller.imagePath.value;
            if (path == null) return const SizedBox.shrink();
            return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(File(path), fit: BoxFit.contain, width: double.infinity),
            );
          }),
        ),
        const SizedBox(height: 16),
        const StatusBanner(
          kind: StatusBannerKind.stub,
          message: 'التعرف الضوئي على النص العربي (OCR) غير مفعّل بعد في هذه المرحلة.',
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(onPressed: controller.retakeImage, child: const Text('إعادة الاختيار')),
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
      ],
    );
  }
}
