import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/features/patients/patient_providers.dart';
import 'package:ampdent_mobile/features/recall/reason_sheet.dart';
import 'package:ampdent_mobile/features/recall/recall_row.dart'
    show showMessageResult;
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'lab_actions.dart';
import 'lab_guards.dart';
import 'lab_model.dart';
import 'lab_providers.dart';
import 'lab_slip_actions.dart';

/// One lab case: details, timestamped status steps, remake, slip print/share
/// and the lab-ready message to the patient.
class LabCaseDetailPage extends ConsumerWidget {
  /// Creates the page for [caseId].
  const LabCaseDetailPage({super.key, required this.caseId});

  /// The case.
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final labCase = ref.watch(labCaseProvider(caseId));
    return labCase.when(
      loading: () => LoadingScaffold(message: s.loading),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(labCaseProvider(caseId)),
        ),
      ),
      data: (c) => c == null
          ? Scaffold(
              appBar: AppBar(),
              body: const ErrorView(message: 'Lab case not found'),
            )
          : _Body(labCase: c),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.labCase});

  final LabCase labCase;

  void _snack(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _transition(
    BuildContext context,
    WidgetRef ref,
    LabCaseStatus next,
  ) async {
    final actions = ref.read(labCaseActionsProvider);
    switch (next) {
      case LabCaseStatus.sent:
        await actions.markSent(labCase.id);
      case LabCaseStatus.received:
        await actions.markReceived(labCase.id);
      case LabCaseStatus.qualityChecked:
        await actions.markQualityChecked(labCase.id);
      case LabCaseStatus.fitted:
        await actions.markFitted(labCase.id);
      case LabCaseStatus.created:
      case LabCaseStatus.remakeRequested:
      case LabCaseStatus.cancelled:
        return;
    }
    ref.invalidate(labCaseProvider(labCase.id));
    ref.invalidate(patientLabCasesProvider(labCase.patientId));
  }

  Future<void> _remake(BuildContext context, WidgetRef ref) async {
    final reason = await ReasonSheet.show(
      context,
      title: 'Request remake?',
      message: 'This case is closed as a remake and a new linked case opens.',
      suggestions: remakeReasons,
      confirmLabel: 'Request remake',
      destructive: true,
    );
    if (reason == null) return;
    final remake = await ref
        .read(labCaseActionsProvider)
        .requestRemake(labCase.id, reason);
    ref.invalidate(labCaseProvider(labCase.id));
    if (context.mounted) context.pushReplacement('/lab/${remake.id}');
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final reason = await ReasonSheet.show(
      context,
      title: 'Cancel lab case?',
      confirmLabel: 'Cancel case',
      destructive: true,
    );
    if (reason == null) return;
    await ref.read(labCaseActionsProvider).cancel(labCase.id, reason);
    ref.invalidate(labCaseProvider(labCase.id));
  }

  Future<void> _notify(
    BuildContext context,
    WidgetRef ref,
    Patient patient,
    Clinic clinic,
  ) async {
    final result = await ref
        .read(labCaseActionsProvider)
        .notifyReady(labCase: labCase, patient: patient, clinic: clinic);
    if (context.mounted) showMessageResult(context, result);
  }

  Future<void> _slip(
    BuildContext context,
    WidgetRef ref, {
    required Patient patient,
    required Lab lab,
    required bool share,
  }) async {
    try {
      final slipCtx = await LabSlipContext.load(
        ref,
        patient: patient,
        lab: lab,
      );
      if (share) {
        await shareLabSlip(labCase, slipCtx);
      } else {
        await printLabSlip(labCase, slipCtx);
      }
    } on Exception catch (e) {
      if (context.mounted) _snack(context, 'Could not render the slip: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final theme = Theme.of(context);
    final notation = ref.watch(notationProvider);
    final now = ref.watch(clockProvider)();
    final patient = ref.watch(patientProvider(labCase.patientId)).value;
    final lab = ref.watch(labProvider(labCase.labId)).value;
    final clinic = ref.watch(currentClinicProvider).value;
    final next = LabCaseActions.nextStatus(labCase);
    final overdue = labCase.isOverdue(now);
    final c = labCase;
    return Scaffold(
      appBar: AppBar(
        title: Text(labCaseTypeLabel(c.caseType)),
        actions: [
          IconButton(
            key: const ValueKey('labcase-print'),
            tooltip: 'Print slip',
            icon: const Icon(Icons.print_outlined),
            onPressed: patient == null || lab == null
                ? null
                : () => _slip(
                    context,
                    ref,
                    patient: patient,
                    lab: lab,
                    share: false,
                  ),
          ),
          IconButton(
            key: const ValueKey('labcase-share'),
            tooltip: 'Share slip',
            icon: const Icon(Icons.share_outlined),
            onPressed: patient == null || lab == null
                ? null
                : () => _slip(
                    context,
                    ref,
                    patient: patient,
                    lab: lab,
                    share: true,
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          Row(
            children: [
              StatusBadge(
                key: ValueKey('labcase-status-${c.status.name}'),
                label: labCaseStatusLabel(c.status),
                tone: labCaseStatusTone(c.status),
              ),
              if (overdue) ...[
                const SizedBox(width: AppSpacing.sm),
                StatusBadge(
                  key: const ValueKey('labcase-overdue'),
                  label: s.overdue,
                  tone: BadgeTone.danger,
                  icon: Icons.warning_amber_outlined,
                ),
              ],
              if (c.remakeOfCaseId != null) ...[
                const SizedBox(width: AppSpacing.sm),
                const StatusBadge(label: 'Remake', tone: BadgeTone.warning),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (patient != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: Text(patient.displayName),
              subtitle: Text(AppFormat.phone(patient.phone)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/patients/${patient.id}'),
            ),
          SectionCard(
            title: 'Case',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LabeledValue(label: s.lab, value: lab?.name ?? '-'),
                LabeledValue(
                  label: s.teeth,
                  value: c.teeth.isEmpty
                      ? '-'
                      : notation.formatAll(c.teeth, plain: true),
                ),
                LabeledValue(label: 'Material', value: c.material ?? '-'),
                LabeledValue(label: 'Shade', value: c.shade ?? '-'),
                LabeledValue(
                  label: 'Impression',
                  value: c.impressionType ?? '-',
                ),
                if (c.instructions != null)
                  LabeledValue(label: 'Instructions', value: c.instructions!),
                LabeledValue(
                  label: 'Lab fee',
                  value: c.labFee.isZero ? '-' : AppFormat.money(c.labFee),
                ),
                if (c.remakeReason != null)
                  LabeledValue(label: 'Remake reason', value: c.remakeReason!),
                if (c.remakeOfCaseId != null)
                  LabeledValue(
                    label: 'Remake of',
                    value: c.remakeOfCaseId!,
                    trailing: IconButton(
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => context.push('/lab/${c.remakeOfCaseId}'),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            title: 'Timeline',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Step(label: 'Created', at: c.createdAt),
                _Step(label: 'Sent', at: c.sentAt),
                _Step(
                  label: s.due,
                  at: c.dueAt,
                  color: overdue ? AppColors.of(context).danger : null,
                ),
                _Step(label: 'Received', at: c.receivedAt),
                _Step(label: 'Quality checked', at: c.qualityCheckedAt),
                _Step(label: 'Fitted', at: c.fittedAt),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (next != null)
            BigActionButton(
              key: ValueKey('labcase-mark-${next.name}'),
              label: 'Mark ${labCaseStatusLabel(next).toLowerCase()}',
              icon: Icons.check_circle_outline,
              onPressed: () => _transition(context, ref, next),
            ),
          if (canSeat(c)) ...[
            const SizedBox(height: AppSpacing.sm),
            BigActionButton(
              key: const ValueKey('labcase-notify'),
              label: 'WhatsApp patient: ready to fit',
              icon: Icons.chat_outlined,
              tonal: true,
              onPressed: patient == null || clinic == null
                  ? null
                  : () => _notify(context, ref, patient, clinic),
            ),
            const SizedBox(height: AppSpacing.sm),
            BigActionButton(
              key: const ValueKey('labcase-book'),
              label: 'Book seat appointment',
              icon: Icons.event_available_outlined,
              tonal: true,
              onPressed: () => context.push(
                '/schedule/new?patientId=${c.patientId}&labCaseId=${c.id}',
              ),
            ),
          ],
          if (c.status.isOpen) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                if (c.status != LabCaseStatus.created &&
                    c.status != LabCaseStatus.remakeRequested)
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('labcase-remake'),
                      onPressed: () => _remake(context, ref),
                      icon: const Icon(Icons.replay),
                      label: const Text('Remake'),
                    ),
                  ),
                if (c.status != LabCaseStatus.created &&
                    c.status != LabCaseStatus.remakeRequested)
                  const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextButton.icon(
                    key: const ValueKey('labcase-cancel'),
                    onPressed: () => _cancel(context, ref),
                    icon: const Icon(Icons.close),
                    label: Text(s.cancel),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Case id ${c.id}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.at, this.color});

  final String label;
  final DateTime? at;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = at != null;
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: color ?? (done ? theme.colorScheme.primary : muted),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label)),
          Text(
            done ? AppFormat.dateTime(at!) : '-',
            style: theme.textTheme.bodySmall?.copyWith(color: color ?? muted),
          ),
        ],
      ),
    );
  }
}
