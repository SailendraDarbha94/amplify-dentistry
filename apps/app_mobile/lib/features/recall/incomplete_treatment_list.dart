import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/features/patients/patient_providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'incomplete_treatment.dart';
import 'recall_actions.dart';
import 'recall_providers.dart';
import 'recall_row.dart';

/// Procedures left incomplete: stalled multi-sitting work and root canals
/// without a crown, each with a TREATMENT_INCOMPLETE nudge and a Book action.
class IncompleteTreatmentList extends ConsumerWidget {
  /// Creates the list.
  const IncompleteTreatmentList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final items = ref.watch(incompleteTreatmentsProvider);
    return items.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(clinicProceduresProvider),
      ),
      data: (list) => list.isEmpty
          ? EmptyState(
              icon: Icons.task_alt,
              title: s.nothingHere,
              message:
                  'No stalled procedures and every completed root canal has '
                  'a crown planned.',
            )
          : ListView.builder(
              padding: const EdgeInsets.only(
                top: AppSpacing.sm,
                bottom: AppSpacing.xxl,
              ),
              itemCount: list.length,
              itemBuilder: (context, i) =>
                  IncompleteTreatmentTile(item: list[i]),
            ),
    );
  }
}

/// One incomplete-treatment card.
class IncompleteTreatmentTile extends ConsumerWidget {
  /// Creates the tile.
  const IncompleteTreatmentTile({super.key, required this.item});

  /// The finding.
  final IncompleteTreatment item;

  Future<void> _nudge(
    BuildContext context,
    WidgetRef ref,
    Patient patient,
    Clinic clinic,
  ) async {
    final result = await ref
        .read(recallActionsProvider)
        .sendIncompleteNudge(
          item: item,
          patient: patient,
          clinic: clinic,
          notation: ref.read(notationProvider),
        );
    if (context.mounted) showMessageResult(context, result);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final theme = Theme.of(context);
    final notation = ref.watch(notationProvider);
    final now = ref.watch(clockProvider)();
    final patient = ref.watch(patientProvider(item.patientId)).value;
    final clinic = ref.watch(currentClinicProvider).value;
    final muted = theme.colorScheme.onSurfaceVariant;
    final p = item.procedure;
    final toothText = item.tooth == null
        ? ''
        : '  ·  ${s.tooth} ${notation.formatPlain(item.tooth!)}';
    final days = now.difference(item.since).inDays;
    return Card(
      key: ValueKey('incomplete-row-${p.id}'),
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
                  label: item.kind.label,
                  tone: item.kind == IncompleteTreatmentKind.rctWithoutCrown
                      ? BadgeTone.danger
                      : BadgeTone.warning,
                  dense: true,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('${p.name}$toothText', style: theme.textTheme.bodyMedium),
            Text(
              '${item.kind == IncompleteTreatmentKind.rctWithoutCrown ? 'Completed' : 'Started'} '
              '${AppFormat.date(item.since)} ($days days ago)  ·  '
              'Next: ${item.nextStep(notation)}',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    key: ValueKey('incomplete-whatsapp-${p.id}'),
                    onPressed: patient == null || clinic == null
                        ? null
                        : () => _nudge(context, ref, patient, clinic),
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('WhatsApp'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    key: ValueKey('incomplete-book-${p.id}'),
                    onPressed: () => context.push(
                      '/schedule/new?patientId=${item.patientId}',
                    ),
                    icon: const Icon(Icons.event_available_outlined),
                    label: const Text('Book'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
