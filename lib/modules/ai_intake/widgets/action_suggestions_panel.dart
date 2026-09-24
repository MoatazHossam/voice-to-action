import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ai_intake_controller.dart';
import '../models/action_suggestion.dart';

String actionTypeLabel(ActionType type) => switch (type) {
      ActionType.newRequest => 'طلب جديد',
      ActionType.meeting => 'اجتماع',
      ActionType.email => 'بريد إلكتروني',
      ActionType.task => 'مهمة',
    };

IconData actionTypeIcon(ActionType type) => switch (type) {
      ActionType.newRequest => Icons.assignment_outlined,
      ActionType.meeting => Icons.event_outlined,
      ActionType.email => Icons.email_outlined,
      ActionType.task => Icons.check_circle_outline,
    };

class ActionSuggestionsList extends StatelessWidget {
  const ActionSuggestionsList({super.key, required this.controller});

  final AiIntakeController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.suggestions.isEmpty) {
        return Text(
          controller.reviewedText.value.trim().isEmpty
              ? 'اكتب نصًا ثم اضغط "تحليل" لاكتشاف الإجراءات المحتملة.'
              : 'لم يتم اكتشاف أي إجراء في النص الحالي.',
          style: Theme.of(context).textTheme.bodySmall,
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الإجراءات المقترحة', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          for (final suggestion in controller.suggestions)
            _SuggestionTile(suggestion: suggestion, controller: controller),
        ],
      );
    });
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.suggestion, required this.controller});

  final ActionSuggestion suggestion;
  final AiIntakeController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selected = controller.selectedSuggestionIds.contains(suggestion.id);
      return Card(
        child: CheckboxListTile(
          value: selected,
          onChanged: (_) => controller.toggleSuggestionSelected(suggestion.id),
          controlAffinity: ListTileControlAffinity.leading,
          title: Row(
            children: [
              Icon(actionTypeIcon(suggestion.type), size: 18),
              const SizedBox(width: 8),
              Text(actionTypeLabel(suggestion.type), style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text('"${suggestion.evidenceText}"', style: Theme.of(context).textTheme.bodySmall),
              if (suggestion.extractedFields.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final entry in suggestion.extractedFields.entries)
                      Chip(
                        label: Text('${entry.key}: ${entry.value}'),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
              if (suggestion.missingRequiredFields.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final field in suggestion.missingRequiredFields)
                      Chip(
                        label: Text('ناقص: $field'),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Theme.of(context).colorScheme.errorContainer,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}
