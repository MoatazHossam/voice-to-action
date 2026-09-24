import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';

enum StatusBannerKind { real, stub, unsupported, error, warning }

/// Keeps the "real vs. stub vs. unsupported vs. error" distinction visually
/// consistent everywhere ai_intake needs to be honest about capability.
class StatusBanner extends StatelessWidget {
  const StatusBanner({super.key, required this.kind, required this.message});

  final StatusBannerKind kind;
  final String message;

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (kind) {
      StatusBannerKind.real => (AppStatusColors.realFeature, Icons.check_circle_outline, 'حقيقي'),
      StatusBannerKind.stub => (AppStatusColors.stubFeature, Icons.build_circle_outlined, 'قيد التطوير'),
      StatusBannerKind.unsupported => (
          AppStatusColors.unsupportedFeature,
          Icons.block_outlined,
          'غير مدعوم'
        ),
      StatusBannerKind.error => (AppTheme.recordingRed, Icons.error_outline, 'خطأ'),
      StatusBannerKind.warning => (AppTheme.warningAmber, Icons.info_outline, 'تنبيه'),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 2),
                Text(message, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
