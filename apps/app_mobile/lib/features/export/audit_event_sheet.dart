import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

import 'audit_diff.dart';
import 'audit_filters.dart';

/// Badge tone for an audit action.
BadgeTone auditTone(AuditAction action) => switch (action) {
  AuditAction.create => BadgeTone.success,
  AuditAction.update || AuditAction.settingsChange => BadgeTone.info,
  AuditAction.statusChange => BadgeTone.planned,
  AuditAction.softDelete => BadgeTone.danger,
  AuditAction.export ||
  AuditAction.share ||
  AuditAction.print => BadgeTone.warning,
  _ => BadgeTone.neutral,
};

/// Detail sheet for one audit event with its before/after diff.
class AuditEventSheet extends StatelessWidget {
  /// Creates the sheet.
  const AuditEventSheet({super.key, required this.event, this.actorName});

  /// The event.
  final AuditEvent event;

  /// Display name of the actor, when known.
  final String? actorName;

  /// Shows the sheet.
  static Future<void> show(
    BuildContext context, {
    required AuditEvent event,
    String? actorName,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => AuditEventSheet(event: event, actorName: actorName),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final diff = diffSnapshots(event.before, event.after);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: AppSpacing.screenPadding,
        children: [
          Row(
            children: [
              StatusBadge(
                label: auditActionLabel(event.action),
                tone: auditTone(event.action),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  event.entityType,
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LabeledValue(label: 'Entity id', value: event.entityId, dense: true),
          LabeledValue(
            label: 'When',
            value: AppFormat.dateTime(event.occurredAt),
            dense: true,
          ),
          LabeledValue(
            label: 'Actor',
            value: actorName == null
                ? event.actorId
                : '$actorName (${event.actorId})',
            dense: true,
          ),
          LabeledValue(label: 'Device', value: event.deviceId, dense: true),
          if (event.reason != null && event.reason!.isNotEmpty)
            LabeledValue(label: 'Reason', value: event.reason!, dense: true),
          const SizedBox(height: AppSpacing.md),
          Text(
            diff.isEmpty ? 'No field changes recorded' : 'Changes',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final d in diff)
            Padding(
              key: ValueKey('audit-diff-${d.key}'),
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.key, style: theme.textTheme.labelLarge),
                  if (event.before != null)
                    Text(
                      diffValueLabel(d.before),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.danger,
                        decoration: d.after == null
                            ? null
                            : TextDecoration.lineThrough,
                      ),
                    ),
                  if (event.after != null)
                    Text(
                      diffValueLabel(d.after),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.success,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
