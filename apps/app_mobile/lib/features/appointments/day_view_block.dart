import 'dart:math' as math;

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

import 'appointment_form_model.dart';
import 'appointment_status.dart';
import 'day_view.dart';

/// Paints the 10-minute grid (hour lines heavier) and the column's right
/// border behind a chair column.
class ScheduleGridPainter extends CustomPainter {
  /// Creates the painter.
  const ScheduleGridPainter({
    required this.hourColor,
    required this.slotColor,
    required this.borderColor,
  });

  final Color hourColor;
  final Color slotColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final hour = Paint()
      ..color = hourColor
      ..strokeWidth = 1;
    final slot = Paint()
      ..color = slotColor
      ..strokeWidth = 1;
    final slots =
        (scheduleDayEndHour - scheduleDayStartHour) * 60 ~/ scheduleSlotMinutes;
    for (var i = 0; i <= slots; i++) {
      final y = columnHeaderHeight + i * slotHeight;
      final onHour = (i * scheduleSlotMinutes) % 60 == 0;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        onHour ? hour : slot,
      );
    }
    canvas.drawLine(
      Offset(size.width - 0.5, 0),
      Offset(size.width - 0.5, size.height),
      Paint()..color = borderColor,
    );
  }

  @override
  bool shouldRepaint(covariant ScheduleGridPainter old) =>
      old.hourColor != hourColor ||
      old.slotColor != slotColor ||
      old.borderColor != borderColor;
}

/// One booked slot drawn inside a chair column: provider colour bar, patient
/// name, status chip and, for cancelled or no-show slots, a 'fill from
/// waitlist' hint.
class AppointmentBlock extends StatelessWidget {
  /// Creates the block.
  const AppointmentBlock({
    super.key,
    required this.appointment,
    required this.lane,
    required this.patient,
    required this.colour,
    required this.onTap,
    required this.onFill,
  });

  final Appointment appointment;
  final int lane;
  final Patient? patient;
  final Color colour;
  final VoidCallback onTap;
  final VoidCallback onFill;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final theme = Theme.of(context);
    final a = appointment;
    final start = a.startsAt.toLocal();
    final top = columnHeaderHeight + DayView.offsetFor(start);
    final height = math.max(
      24.0,
      a.duration.inMinutes / scheduleSlotMinutes * slotHeight - 2,
    );
    final gone =
        a.status == AppointmentStatus.cancelled ||
        a.status == AppointmentStatus.noShow ||
        a.status == AppointmentStatus.rescheduled;
    final fill = gone
        ? theme.colorScheme.surfaceContainerHighest
        : colour.withValues(alpha: 0.18);
    final border = gone ? theme.colorScheme.outline : colour;
    final name = patient?.displayName ?? s.patient;
    final tall = height >= 54;
    return Positioned(
      top: top,
      left: 2.0 + lane * 14,
      right: 2,
      height: height,
      child: Material(
        key: ValueKey('schedule-block-${a.id}'),
        color: fill,
        borderRadius: AppRadii.smAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.smAll,
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 2, 4, 2),
            decoration: BoxDecoration(
              borderRadius: AppRadii.smAll,
              border: Border(left: BorderSide(color: border, width: 4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          decoration: gone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    if (height >= 36)
                      StatusBadge(
                        label: appointmentStatusLabel(a.status, s),
                        tone: appointmentStatusTone(a.status),
                        dense: true,
                      ),
                  ],
                ),
                if (tall)
                  Text(
                    '${AppFormat.time(a.startsAt)} – '
                    '${AppFormat.time(a.endsAt)}'
                    '${a.reason.isEmpty ? '' : ' · ${a.reason}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                if (gone && tall)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      key: ValueKey('schedule-fill-${a.id}'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: onFill,
                      icon: const Icon(Icons.hourglass_bottom, size: 16),
                      label: const Text('Fill from waitlist'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
