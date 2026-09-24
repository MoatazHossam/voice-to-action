import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ai_intake_controller.dart';
import '../models/ai_intake_input.dart';
import '../models/text_correction.dart';
import 'status_banner.dart';

/// Shows the original extraction honestly: a real success banner only for a
/// genuine, non-empty result; a distinct warning when a real engine ran but
/// recognized nothing; and the existing stub banner when no real engine is
/// wired up. Wording is source-aware (audio vs. image) — never a generic
/// "recording converted" message for an image, or vice versa.
class ExtractionSummary extends StatelessWidget {
  const ExtractionSummary({super.key, required this.controller});

  final AiIntakeController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final extraction = controller.extraction.value;
      if (extraction == null) return const SizedBox.shrink();
      final isAudio = controller.lastSourceType == AiIntakeSourceType.audio;
      final hasText = extraction.originalText.trim().isNotEmpty;

      final banners = <Widget>[];
      if (extraction.isStub) {
        for (final warning in extraction.warnings) {
          banners.add(StatusBanner(kind: StatusBannerKind.stub, message: warning));
        }
      } else if (!hasText) {
        banners.add(StatusBanner(
          kind: StatusBannerKind.warning,
          message: isAudio
              ? 'لم يتم التعرف على أي كلام واضح في التسجيل. حاول التسجيل من جديد أو اكتب النص يدويًا.'
              : 'لم يتم العثور على نص في الصورة. جرّب صورة أوضح أو اكتب النص يدويًا.',
        ));
      } else {
        banners.add(StatusBanner(
          kind: StatusBannerKind.real,
          message: isAudio ? 'تم تحويل التسجيل إلى نص بنجاح.' : 'تم استخراج النص من الصورة بنجاح.',
        ));
        for (final warning in extraction.warnings) {
          banners.add(StatusBanner(kind: StatusBannerKind.warning, message: warning));
        }
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final banner in banners) ...[banner, const SizedBox(height: 8)],
          if (!extraction.isStub && hasText) ...[
            Text('النص الأصلي المستخرج', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            SelectableText(extraction.originalText),
            const SizedBox(height: 16),
          ],
        ],
      );
    });
  }
}

class ReviewedTextField extends StatefulWidget {
  const ReviewedTextField({super.key, required this.controller});

  final AiIntakeController controller;

  @override
  State<ReviewedTextField> createState() => _ReviewedTextFieldState();
}

class _ReviewedTextFieldState extends State<ReviewedTextField> {
  late final TextEditingController _textController =
      TextEditingController(text: widget.controller.reviewedText.value);
  Worker? _worker;

  @override
  void initState() {
    super.initState();
    _worker = ever<String>(widget.controller.reviewedText, (value) {
      if (value != _textController.text) {
        _textController.value = _textController.value.copyWith(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        );
      }
    });
  }

  @override
  void dispose() {
    _worker?.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _textController,
      onChanged: widget.controller.updateReviewedText,
      maxLines: 5,
      minLines: 3,
      textDirection: TextDirection.rtl,
      decoration: const InputDecoration(
        hintText: 'اكتب أو عدّل النص هنا للمتابعة',
      ),
    );
  }
}

class CorrectionsList extends StatelessWidget {
  const CorrectionsList({super.key, required this.controller});

  final AiIntakeController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.corrections.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('اقتراحات تصحيح (اختيارية)', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          for (final correction in controller.corrections)
            _CorrectionTile(correction: correction, controller: controller),
        ],
      );
    });
  }
}

class _CorrectionTile extends StatelessWidget {
  const _CorrectionTile({required this.correction, required this.controller});

  final TextCorrection correction;
  final AiIntakeController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        correction.originalSpan.isEmpty ? '∅' : correction.originalSpan,
                        style: const TextStyle(decoration: TextDecoration.lineThrough),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_back, size: 14),
                      const SizedBox(width: 6),
                      Text(correction.proposedSpan.isEmpty ? '∅' : correction.proposedSpan),
                    ],
                  ),
                  Text(correction.reason, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Switch(
              value: correction.accepted,
              onChanged: (v) => controller.setCorrectionAccepted(correction.id, v),
            ),
          ],
        ),
      ),
    );
  }
}
