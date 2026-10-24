import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

/// Display label for an [AppointmentStatus]; shared table strings where one
/// exists so translations follow automatically.
String appointmentStatusLabel(AppointmentStatus status, AppStrings s) =>
    switch (status) {
      AppointmentStatus.scheduled => 'Scheduled',
      AppointmentStatus.confirmed => 'Confirmed',
      AppointmentStatus.arrived => 'Arrived',
      AppointmentStatus.inChair => 'In chair',
      AppointmentStatus.completed => s.completed,
      AppointmentStatus.cancelled => s.cancelled,
      AppointmentStatus.noShow => 'No-show',
      AppointmentStatus.rescheduled => 'Rescheduled',
    };

/// Badge tone for an [AppointmentStatus].
BadgeTone appointmentStatusTone(AppointmentStatus status) => switch (status) {
  AppointmentStatus.scheduled => BadgeTone.planned,
  AppointmentStatus.confirmed => BadgeTone.info,
  AppointmentStatus.arrived => BadgeTone.warning,
  AppointmentStatus.inChair => BadgeTone.existing,
  AppointmentStatus.completed => BadgeTone.completed,
  AppointmentStatus.cancelled => BadgeTone.danger,
  AppointmentStatus.noShow => BadgeTone.danger,
  AppointmentStatus.rescheduled => BadgeTone.neutral,
};

/// Icon used on the status flow buttons.
IconData appointmentStatusIcon(AppointmentStatus status) => switch (status) {
  AppointmentStatus.scheduled => Icons.schedule,
  AppointmentStatus.confirmed => Icons.check_circle_outline,
  AppointmentStatus.arrived => Icons.login,
  AppointmentStatus.inChair => Icons.chair_outlined,
  AppointmentStatus.completed => Icons.task_alt,
  AppointmentStatus.cancelled => Icons.cancel_outlined,
  AppointmentStatus.noShow => Icons.person_off_outlined,
  AppointmentStatus.rescheduled => Icons.update,
};

/// Label for the action that moves an appointment into [status]
/// ('Confirm', 'Mark arrived', ...).
String appointmentActionLabel(AppointmentStatus status, AppStrings s) =>
    switch (status) {
      AppointmentStatus.scheduled => 'Re-open',
      AppointmentStatus.confirmed => s.confirm,
      AppointmentStatus.arrived => 'Arrived',
      AppointmentStatus.inChair => 'In chair',
      AppointmentStatus.completed => 'Completed',
      AppointmentStatus.cancelled => s.cancel,
      AppointmentStatus.noShow => 'No-show',
      AppointmentStatus.rescheduled => 'Rescheduled',
    };

/// Statuses an appointment in [current] may move to, in button order.
/// Terminal states (completed, cancelled, no-show, rescheduled) offer no
/// transitions: the row stays as history and a new slot is booked instead.
List<AppointmentStatus> nextAppointmentStatuses(AppointmentStatus current) =>
    switch (current) {
      AppointmentStatus.scheduled => const [
        AppointmentStatus.confirmed,
        AppointmentStatus.arrived,
        AppointmentStatus.noShow,
        AppointmentStatus.cancelled,
      ],
      AppointmentStatus.confirmed => const [
        AppointmentStatus.arrived,
        AppointmentStatus.noShow,
        AppointmentStatus.cancelled,
      ],
      AppointmentStatus.arrived => const [
        AppointmentStatus.inChair,
        AppointmentStatus.completed,
        AppointmentStatus.cancelled,
      ],
      AppointmentStatus.inChair => const [AppointmentStatus.completed],
      AppointmentStatus.completed ||
      AppointmentStatus.cancelled ||
      AppointmentStatus.noShow ||
      AppointmentStatus.rescheduled => const [],
    };

/// Whether moving to [status] needs a reason from the user.
bool appointmentStatusNeedsReason(AppointmentStatus status) =>
    status == AppointmentStatus.cancelled;

/// Whether the appointment is still a live booking that can be moved or
/// messaged about.
bool appointmentIsLive(AppointmentStatus status) =>
    status == AppointmentStatus.scheduled ||
    status == AppointmentStatus.confirmed;

/// Display label for an [AppointmentSource].
String appointmentSourceLabel(AppointmentSource source) => switch (source) {
  AppointmentSource.walkIn => 'Walk-in',
  AppointmentSource.phone => 'Phone',
  AppointmentSource.whatsapp => 'WhatsApp',
  AppointmentSource.online => 'Online',
  AppointmentSource.practo => 'Practo',
  AppointmentSource.recall => 'Recall',
};
