import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/features/patients/patient_providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'patient_messenger.dart';
import 'reason_sheet.dart';
import 'recall_actions.dart';
import 'recall_model.dart';
import 'recall_providers.dart';

/// Shows the outcome of a patient message as a snackbar.
void showMessageResult(BuildContext context, PatientMessageResult result) {
  final text = !result.decision.allowed
      ? sendDenialText(result.decision.reason)
      : result.queued
      ? MobileStrings.queuedForDelivery
      : result.launched
      ? 'Opened WhatsApp with the message'
      : 'Message saved to the outbox; WhatsApp could not be opened';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// One recall on the list: patient, phone, last visit, due date, value and
/// the WhatsApp / Book / Dismiss actions.
class RecallRow extends ConsumerWidget {
  /// Creates the row.
  const RecallRow({super.key, required this.recall, required this.group});

  /// The recall.
  final Recall recall;

  /// Group it is shown under (drives the badge and template).
  final RecallGroup group;

  Future<void> _whatsapp(
    BuildContext context,
    WidgetRef ref,
    Patient patient,
    Clinic clinic,
  ) async {
    final result = await ref
        .read(recallActionsProvider)
        .sendReminder(recall: recall, patient: patient, clinic: clinic);
    if (context.mounted) showMessageResult(context, result);
  }

  Future<void> _dismiss(BuildContext context, WidgetRef ref) async {
    final reason = await ReasonSheet.show(
      context,
      title: 'Dismiss recall?',
      message: 'The recall stays in the record with this reason.',
      suggestions: recallDismissReasons,
      confirmLabel: 'Dismiss',
      destructive: true,
    );
    if (reason == null) return;
    await ref.read(recallActionsProvider).dismiss(recall.id, reason);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final theme = Theme.of(context);
    final now = ref.watch(clockProvider)();
    final patient = ref.watch(patientProvider(recall.patientId)).value;
    final clinic = ref.watch(currentClinicProvider).value;
    final lastVisit = ref.watch(lastVisitProvider(recall.patientId)).value;
    final muted = theme.colorScheme.onSurfaceVariant;
    return Card(
      key: ValueKey('recall-row-${recall.id}'),
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: AppSpacing.xs,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: patient == null
                        ? null
                        : () => context.push('/patients/${patient.id}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient?.displayName ?? s.loading,
                          style: theme.textTheme.titleMedium,
                        ),
                        if (patient != null)
                          Text(
                            AppFormat.phone(patient.messagingPhone(now)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                StatusBadge(
                  label: recallTypeLabel(recall.type),
                  tone: group.tone,
                  dense: true,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                _Fact(
                  icon: Icons.event_outlined,
                  text: '${s.due} ${AppFormat.date(recall.dueAt)}',
                  color: muted,
                ),
                _Fact(
                  icon: Icons.history,
                  text: lastVisit == null
                      ? 'No visit recorded'
                      : 'Last visit ${AppFormat.date(lastVisit.startedAt)}',
                  color: muted,
                ),
                if (!recall.estimatedValue.isZero)
                  _Fact(
                    icon: Icons.currency_rupee,
                    text: AppFormat.money(
                      recall.estimatedValue,
                      showPaise: false,
                    ),
                    color: muted,
                  ),
                if (recall.notifyCount > 0)
                  _Fact(
                    icon: Icons.send_outlined,
                    text: 'Reminded ${recall.notifyCount}x',
                    color: muted,
                  ),
              ],
            ),
            if (recall.note != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  recall.note!,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    key: ValueKey('recall-whatsapp-${recall.id}'),
                    onPressed: patient == null || clinic == null
                        ? null
                        : () => _whatsapp(context, ref, patient, clinic),
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('WhatsApp'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    key: ValueKey('recall-book-${recall.id}'),
                    onPressed: () => context.push(
                      '/schedule/new?patientId=${recall.patientId}'
                      '&recallId=${recall.id}',
                    ),
                    icon: const Icon(Icons.event_available_outlined),
                    label: const Text('Book'),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                IconButton(
                  key: ValueKey('recall-dismiss-${recall.id}'),
                  tooltip: 'Dismiss',
                  onPressed: () => _dismiss(context, ref),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: AppSpacing.xs),
      Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
      ),
    ],
  );
}
