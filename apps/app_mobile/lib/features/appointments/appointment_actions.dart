import 'dart:async';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'appointment_messaging.dart';
import 'appointment_providers.dart';
import 'appointment_status.dart';
import 'move_slot_sheet.dart';

/// WhatsApp confirmation / reminder, move, and start-visit actions for one
/// appointment. Messaging buttons are disabled when the opt-in policy denies
/// the send, with the reason shown underneath.
class AppointmentActionsCard extends ConsumerStatefulWidget {
  /// Creates the card.
  const AppointmentActionsCard({
    super.key,
    required this.appointment,
    required this.patient,
  });

  /// Appointment acted on.
  final Appointment appointment;

  /// Its patient (null while loading).
  final Patient? patient;

  @override
  ConsumerState<AppointmentActionsCard> createState() =>
      _AppointmentActionsCardState();
}

class _AppointmentActionsCardState
    extends ConsumerState<AppointmentActionsCard> {
  bool _busy = false;

  Future<void> _send(AppointmentMessageKind kind) async {
    final patient = widget.patient;
    if (patient == null) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Read through the repositories rather than stream providers: nothing
      // on this page is guaranteed to keep the clinic stream alive.
      final ctx = ref.read(actorContextProvider);
      final clinics = ref.read(clinicRepositoryProvider);
      final clinic = await clinics.getClinic(ctx.clinicId);
      final provider = await clinics.getMember(widget.appointment.providerId);
      if (clinic == null || provider == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Dentist not found for this slot')),
        );
        return;
      }
      final consents = await ref
          .read(consentRepositoryProvider)
          .dataConsentsForPatient(patient.id);
      final outcome = await ref
          .read(appointmentMessengerProvider)
          .send(
            kind: kind,
            appointment: widget.appointment,
            patient: patient,
            consents: consents,
            clinic: clinic,
            provider: provider,
          );
      final text = !outcome.decision.allowed
          ? sendDenialMessage(outcome.decision.reason)
          : outcome.sent
          ? 'WhatsApp opened for ${AppFormat.phone(outcome.log!.toPhone)}'
          : 'Could not open WhatsApp; logged as not sent';
      messenger.showSnackBar(SnackBar(content: Text(text)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _move() async {
    final moved = await MoveSlotSheet.show(
      context,
      appointment: widget.appointment,
      patient: widget.patient,
    );
    if (moved != null && mounted) {
      ref.read(selectedDayProvider.notifier).select(moved.startsAt.toLocal());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Moved to ${AppFormat.weekdayDate(moved.startsAt)}, '
            '${AppFormat.time(moved.startsAt)}',
          ),
        ),
      );
    }
  }

  Future<void> _startVisit() async {
    final a = widget.appointment;
    final ctx = ref.read(actorContextProvider);
    final repo = ref.read(appointmentRepositoryProvider);
    final now = ref.read(clockProvider)().toUtc();
    setState(() => _busy = true);
    try {
      var visit = await repo.openVisit(a.patientId);
      visit ??= await repo.startVisit(
        ctx,
        Visit(
          id: newId(),
          clinicId: ctx.clinicId,
          patientId: a.patientId,
          providerId: a.providerId,
          appointmentId: a.id,
          startedAt: now,
          chiefComplaint: a.reason.isEmpty ? null : a.reason,
          createdAt: now,
          updatedAt: now,
        ),
      );
      if (a.status != AppointmentStatus.inChair && a.status.occupiesChair) {
        await repo.changeStatus(ctx, a.id, AppointmentStatus.inChair, at: now);
      }
      ref.invalidate(openVisitProvider(a.patientId));
      if (!mounted) return;
      unawaited(context.push('/patients/${a.patientId}'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final a = widget.appointment;
    final patient = widget.patient;
    final now = ref.watch(clockProvider)();
    final consents = patient == null
        ? const <DataConsent>[]
        : ref.watch(patientDataConsentsProvider(patient.id)).value;
    final decision = patient == null || consents == null
        ? null
        : AppointmentMessenger.decide(
            patient: patient,
            consents: consents,
            now: now,
          );
    final live = appointmentIsLive(a.status);
    final canMessage = live && (decision?.allowed ?? false) && !_busy;
    final openVisit = ref.watch(openVisitProvider(a.patientId)).value;
    final canStart = a.status.occupiesChair && !_busy;
    final theme = Theme.of(context);
    return SectionCard(
      title: 'Actions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  key: const ValueKey('appt-send-confirmation'),
                  onPressed: canMessage
                      ? () => _send(AppointmentMessageKind.confirmation)
                      : null,
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('Send confirmation'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.tonalIcon(
                  key: const ValueKey('appt-send-reminder'),
                  onPressed: canMessage
                      ? () => _send(AppointmentMessageKind.reminder24h)
                      : null,
                  icon: const Icon(Icons.alarm_outlined),
                  label: Text(
                    a.reminder24hSentAt == null
                        ? 'Send reminder'
                        : 'Resend reminder',
                  ),
                ),
              ),
            ],
          ),
          if (patient != null && decision != null && !decision.allowed)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                sendDenialMessage(decision.reason),
                key: const ValueKey('appt-messaging-blocked'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            )
          else if (patient != null && patient.ageStatus(now) == AgeStatus.minor)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'Minor: messages go to the guardian, '
                '${AppFormat.phone(patient.messagingPhone(now))}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('appt-move'),
                  onPressed: live && !_busy ? _move : null,
                  icon: const Icon(Icons.drive_file_move_outline),
                  label: const Text('Move'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('appt-start-visit'),
                  onPressed: canStart ? _startVisit : null,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(openVisit != null ? 'Open visit' : 'Start visit'),
                ),
              ),
            ],
          ),
          if (openVisit != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'Visit open since ${AppFormat.time(openVisit.startedAt)}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (!live && a.status.occupiesChair == false)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                '${appointmentStatusLabel(a.status, s)} appointments cannot '
                'be moved or messaged; book a new slot instead.',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
