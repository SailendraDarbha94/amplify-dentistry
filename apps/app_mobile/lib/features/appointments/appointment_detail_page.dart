import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'appointment_actions.dart';
import 'appointment_providers.dart';
import 'appointment_status.dart';

/// One appointment: who, when, where, status flow, messaging, move and
/// start-visit actions, with a quick link to the patient record.
class AppointmentDetailPage extends ConsumerWidget {
  /// Creates the page.
  const AppointmentDetailPage({super.key, required this.appointmentId});

  /// Appointment to show.
  final String appointmentId;

  Future<void> _changeStatus(
    BuildContext context,
    WidgetRef ref,
    Appointment a,
    AppointmentStatus status,
  ) async {
    String? reason;
    if (appointmentStatusNeedsReason(status)) {
      reason = await _askReason(context);
      if (reason == null) return;
    }
    await ref
        .read(appointmentRepositoryProvider)
        .changeStatus(
          ref.read(actorContextProvider),
          a.id,
          status,
          reason: reason,
          at: ref.read(clockProvider)().toUtc(),
        );
  }

  Future<String?> _askReason(BuildContext context) => showDialog<String>(
    context: context,
    builder: (_) => const CancelReasonDialog(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final appointment = ref.watch(appointmentProvider(appointmentId));
    return appointment.when(
      loading: () =>
          LoadingScaffold(appBar: AppBar(title: Text(s.appointment))),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(s.appointment)),
        body: ErrorView(message: e.toString()),
      ),
      data: (a) => a == null
          ? Scaffold(
              appBar: AppBar(title: Text(s.appointment)),
              body: EmptyState(
                icon: Icons.event_busy_outlined,
                title: s.nothingHere,
                message: 'This appointment no longer exists on this device.',
              ),
            )
          : _Body(
              appointment: a,
              onStatus: (status) => _changeStatus(context, ref, a, status),
            ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.appointment, required this.onStatus});

  final Appointment appointment;
  final ValueChanged<AppointmentStatus> onStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final a = appointment;
    final patient = ref
        .watch(patientsByIdsProvider(patientIdsKey([a.patientId])))
        .value?[a.patientId];
    final members = ref.watch(clinicMembersProvider).value ?? const [];
    final provider = members.where((m) => m.id == a.providerId).firstOrNull;
    final chairs = ref.watch(chairsProvider).value ?? const <Chair>[];
    final chair = chairs.where((c) => c.id == a.chairId).firstOrNull;
    final now = ref.watch(clockProvider)();
    final next = nextAppointmentStatuses(a.status);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.appointment),
        actions: [
          StatusBadge(
            label: appointmentStatusLabel(a.status, s),
            tone: appointmentStatusTone(a.status),
          ),
          const SizedBox(width: AppSpacing.gutter),
        ],
      ),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              key: const ValueKey('appt-patient-link'),
              leading: CircleAvatar(
                backgroundColor: providerColour(a.providerId, members),
                foregroundColor: Colors.white,
                child: Text(
                  (patient?.firstName ?? '?').substring(0, 1).toUpperCase(),
                ),
              ),
              title: Text(patient?.displayName ?? s.patient),
              subtitle: patient == null
                  ? null
                  : Text(
                      '${patient.patientNumber} · '
                      '${AppFormat.ageSex(patient, now)} · '
                      '${AppFormat.phone(patient.phone)}',
                    ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/patients/${a.patientId}'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            title: AppFormat.weekdayDate(a.startsAt),
            subtitle:
                '${AppFormat.time(a.startsAt)} – ${AppFormat.time(a.endsAt)} '
                '· ${a.duration.inMinutes} min',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LabeledValue(
                  label: 'Dentist',
                  value: provider?.displayName ?? '-',
                  dense: true,
                ),
                LabeledValue(
                  label: 'Chair',
                  value: chair?.name ?? 'No chair',
                  dense: true,
                ),
                LabeledValue(
                  label: 'Reason',
                  value: a.reason.isEmpty ? '-' : a.reason,
                  dense: true,
                ),
                LabeledValue(
                  label: 'Booked via',
                  value: appointmentSourceLabel(a.source),
                  dense: true,
                ),
                if ((a.notes ?? '').isNotEmpty)
                  LabeledValue(label: s.notes, value: a.notes!, dense: true),
                if (a.plannedProcedureIds.isNotEmpty)
                  _PlannedProcedures(ids: a.plannedProcedureIds),
                if (a.cancelledReason != null)
                  LabeledValue(
                    label: 'Cancelled because',
                    value: a.cancelledReason!,
                    dense: true,
                  ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _stamps(a),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (next.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            SectionCard(
              title: 'Status',
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final status in next)
                    _StatusButton(
                      key: ValueKey('appt-status-${status.name}'),
                      status: status,
                      onPressed: () => onStatus(status),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          AppointmentActionsCard(appointment: a, patient: patient),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  static String _stamps(Appointment a) {
    final parts = <String>[];
    if (a.confirmedAt != null) {
      parts.add('Confirmed ${AppFormat.dateTime(a.confirmedAt!)}');
    }
    if (a.reminder24hSentAt != null) {
      parts.add('Reminder sent ${AppFormat.dateTime(a.reminder24hSentAt!)}');
    }
    if (a.arrivedAt != null) {
      parts.add('Arrived ${AppFormat.time(a.arrivedAt!)}');
    }
    parts.add('Booked ${AppFormat.dateTime(a.createdAt)}');
    return parts.join(' · ');
  }
}

/// Asks why an appointment is being cancelled; pops with the reason text
/// ('Not given' when left blank) or null when dismissed.
class CancelReasonDialog extends StatefulWidget {
  /// Creates the dialog.
  const CancelReasonDialog({super.key});

  @override
  State<CancelReasonDialog> createState() => _CancelReasonDialogState();
}

class _CancelReasonDialogState extends State<CancelReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    Navigator.of(context).pop(text.isEmpty ? 'Not given' : text);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Cancel appointment'),
    content: TextField(
      key: const ValueKey('appt-cancel-reason'),
      controller: _controller,
      autofocus: true,
      decoration: const InputDecoration(
        labelText: 'Reason',
        hintText: 'Patient request, dentist unavailable, ...',
      ),
      textCapitalization: TextCapitalization.sentences,
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.strings.back),
      ),
      FilledButton(
        key: const ValueKey('appt-cancel-confirm'),
        onPressed: _submit,
        child: Text(context.strings.confirm),
      ),
    ],
  );
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    super.key,
    required this.status,
    required this.onPressed,
  });

  final AppointmentStatus status;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final destructive =
        status == AppointmentStatus.cancelled ||
        status == AppointmentStatus.noShow;
    final label = appointmentActionLabel(status, s);
    final icon = Icon(appointmentStatusIcon(status));
    if (destructive) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
        ),
        icon: icon,
        label: Text(label),
      );
    }
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: icon,
      label: Text(label),
    );
  }
}

class _PlannedProcedures extends ConsumerWidget {
  const _PlannedProcedures({required this.ids});

  final List<String> ids;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chart = ref.watch(chartRepositoryProvider);
    return FutureBuilder<List<ProcedureRecord?>>(
      future: Future.wait(ids.map(chart.getProcedure)),
      builder: (context, snap) {
        final names = (snap.data ?? const <ProcedureRecord?>[])
            .whereType<ProcedureRecord>()
            .map((p) => p.name)
            .toList();
        return LabeledValue(
          label: context.strings.procedures,
          value: names.isEmpty ? '${ids.length} planned' : names.join(', '),
          dense: true,
        );
      },
    );
  }
}
