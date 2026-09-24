import 'package:flutter/material.dart';

import '../../ai_intake/models/action_suggestion.dart';
import '../../ai_intake/models/ai_action_draft.dart';

/// Renders one [AiActionDraft] as a read-only card shaped like the host
/// form it would eventually become. Every field here is display-only:
/// nothing in this widget tree can submit a request, send an email,
/// schedule a meeting, or create a task.
class DraftPreviewCard extends StatelessWidget {
  const DraftPreviewCard({super.key, required this.draft, required this.index});

  final AiActionDraft draft;
  final int index;

  @override
  Widget build(BuildContext context) {
    final (title, icon, fieldOrder) = switch (draft.type) {
      ActionType.newRequest => ('طلب جديد', Icons.assignment_outlined, const ['category', 'description']),
      ActionType.meeting => ('اجتماع', Icons.event_outlined, const ['date', 'attendees']),
      ActionType.email => ('بريد إلكتروني', Icons.email_outlined, const ['recipient', 'subject']),
      ActionType.task => ('مهمة', Icons.check_circle_outline, const ['title', 'dueDate']),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text('$title #${index + 1}', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const Divider(),
            for (final key in fieldOrder) _ReadOnlyField(label: key, value: draft.extractedFields[key]),
            if (draft.unresolvedFields.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  children: [
                    for (final field in draft.unresolvedFields)
                      Chip(
                        label: Text('يحتاج استكمال: $field'),
                        backgroundColor: Theme.of(context).colorScheme.errorContainer,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text('النص المعتمد', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            SelectableText(draft.reviewedText.isEmpty ? '(فارغ)' : draft.reviewedText),
            if (draft.acceptedCorrections.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'تم قبول ${draft.acceptedCorrections.length} تصحيح/تصحيحات نصية.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextFormField(
        initialValue: value ?? '',
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          hintText: value == null ? 'غير متوفر' : null,
        ),
      ),
    );
  }
}
