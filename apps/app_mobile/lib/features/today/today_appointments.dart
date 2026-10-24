import 'dart:async';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'today_providers.dart';

/// Moves an appointment into the chair and opens (or reuses) the visit.
class VisitStarter {
  /// Creates the starter.
  const VisitStarter({
    required this.appointments,
    required this.ctx,
    this.clock = DateTime.now,
  });

  /// Repository used for both writes.
  final AppointmentRepository appointments;

  /// Actor for the writes.
  final ActorContext ctx;

  /// Clock; override in tests.
  final DateTime Function() clock;

  /// Marks [appointment] in-chair (when it is still open) and returns the
  /// patient's open visit, creating one linked to the appointment if none
  /// exists.
  Future<Visit> start(Appointment appointment) async {
    final now = clock().toUtc();
    if (appointment.status.occupiesChair &&
        appointment.status != AppointmentStatus.inChair) {
      await appointments.changeStatus(
        ctx,
        appointment.id,
        AppointmentStatus.inChair,
        at: now,
      );
    }
    final open = await appointments.openVisit(appointment.patientId);
    if (open != null) return open;
    return appointments.startVisit(
      ctx,
      Visit(
        id: newId(),
        clinicId: appointment.clinicId,
        patientId: appointment.patientId,
        providerId: appointment.providerId,
        appointmentId: appointment.id,
        startedAt: now,
        chiefComplaint: appointment.reason.isEmpty ? null : appointment.reason,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}

/// Badge colour for an appointment status.
BadgeTone appointmentTone(AppointmentStatus status) => switch (status) {
  AppointmentStatus.scheduled => BadgeTone.neutral,
  AppointmentStatus.confirmed => BadgeTone.info,
  AppointmentStatus.arrived => BadgeTone.warning,
  AppointmentStatus.inChair => BadgeTone.planned,
  AppointmentStatus.completed => BadgeTone.completed,
  AppointmentStatus.cancelled => BadgeTone.danger,
  AppointmentStatus.noShow => BadgeTone.danger,
  AppointmentStatus.rescheduled => BadgeTone.neutral,
};

/// Short label for an appointment status.
String appointmentStatusLabel(AppointmentStatus status, AppStrings s) =>
    switch (status) {
      AppointmentStatus.completed => s.completed,
      AppointmentStatus.cancelled => s.cancelled,
      AppointmentStatus.inChair => 'In chair',
      AppointmentStatus.noShow => 'No-show',
      _ => AppFormat.enumLabel(status),
    };

/// Whether the row offers a "Start visit" action.
bool canStartVisit(AppointmentStatus status) =>
    status == AppointmentStatus.scheduled ||
    status == AppointmentStatus.confirmed ||
    status == AppointmentStatus.arrived;

/// Today's appointments with status chips and a one-tap "Start visit".
class TodayAppointmentList extends ConsumerWidget {
  /// Creates the list.
  const TodayAppointmentList({super.key});

  Future<void> _startVisit(
    BuildContext context,
    WidgetRef ref,
    Appointment appointment,
  ) async {
    final starter = VisitStarter(
      appointments: ref.read(appointmentRepositoryProvider),
      ctx: ref.read(actorContextProvider),
      clock: ref.read(clockProvider),
    );
    try {
      await starter.start(appointment);
      if (context.mounted) {
        unawaited(context.push('/patients/${appointment.patientId}'));
      }
    } on Object catch (e) {
      const Logger('today').warning('start visit failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.somethingWentWrong)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final appointments = ref.watch(todaysAppointmentsProvider).value;
    final patients = ref.watch(todaysPatientsProvider).value ?? const {};
    if (appointments == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (appointments.isEmpty) {
      return EmptyState(
        key: const ValueKey('today-no-appointments'),
        icon: Icons.event_available_outlined,
        title: 'No appointments today',
        action: FilledButton.tonal(
          onPressed: () => context.push('/schedule/new'),
          child: Text(s.appointment),
        ),
      );
    }
    return Column(
      children: [
        for (final a in appointments)
          _AppointmentRow(
            key: ValueKey('today-appointment-${a.id}'),
            appointment: a,
            patient: patients[a.patientId],
            onStart: canStartVisit(a.status)
                ? () => _startVisit(context, ref, a)
                : null,
            onOpen: a.status == AppointmentStatus.inChair
                ? () => context.push('/patients/${a.patientId}')
                : null,
          ),
      ],
    );
  }
}

class _AppointmentRow extends StatelessWidget {
  const _AppointmentRow({
    super.key,
    required this.appointment,
    required this.patient,
    required this.onStart,
    required this.onOpen,
  });

  final Appointment appointment;
  final Patient? patient;
  final VoidCallback? onStart;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final theme = Theme.of(context);
    final name = patient?.displayName ?? s.patient;
    final subtitle = [
      AppFormat.time(appointment.startsAt),
      if (appointment.reason.isNotEmpty) appointment.reason,
    ].join('  ·  ');
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        borderRadius: AppRadii.mdAll,
        onTap: () => context.push('/schedule/${appointment.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  StatusBadge(
                    label: appointmentStatusLabel(appointment.status, s),
                    tone: appointmentTone(appointment.status),
                    dense: true,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (onStart != null) ...[
                const SizedBox(height: AppSpacing.sm),
                FilledButton.tonal(
                  key: ValueKey('start-visit-${appointment.id}'),
                  onPressed: onStart,
                  child: const Text('Start visit'),
                ),
              ] else if (onOpen != null) ...[
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(onPressed: onOpen, child: Text(s.chart)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
