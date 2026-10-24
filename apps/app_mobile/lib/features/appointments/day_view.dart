import 'dart:math' as math;

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

import 'appointment_form_model.dart';
import 'appointment_providers.dart';
import 'day_view_block.dart';

/// Pixel height of one [scheduleSlotMinutes] slot.
const double slotHeight = 14;

/// Height of the chair-name header above each column.
const double columnHeaderHeight = 32;

/// Width of the time gutter.
const double timeGutterWidth = 48;

/// Narrowest a chair column is drawn.
const double minColumnWidth = 150;

/// Pseudo chair id for appointments without a chair.
const String unassignedColumnId = '__unassigned__';

/// One column per chair, 10-minute grid, provider-coloured blocks with a
/// status chip, and a 'now' line on today. Tapping an empty slot books it;
/// tapping a block opens it; cancelled blocks offer 'fill from waitlist'.
class DayView extends StatefulWidget {
  /// Creates the view.
  const DayView({
    super.key,
    required this.day,
    required this.now,
    required this.appointments,
    required this.chairs,
    required this.members,
    required this.patients,
    required this.onTapAppointment,
    required this.onTapSlot,
    required this.onFillCancelled,
  });

  /// Local day shown.
  final DateTime day;

  /// Current time (for the now line).
  final DateTime now;

  /// Appointments starting on [day].
  final List<Appointment> appointments;

  /// Active chairs, one column each.
  final List<Chair> chairs;

  /// Members, for provider colours and names.
  final List<ClinicMember> members;

  /// Patients by id, for names.
  final Map<String, Patient> patients;

  /// Opens an appointment.
  final void Function(Appointment appointment) onTapAppointment;

  /// Books a slot at [DateTime] on a chair (null for the unassigned column).
  final void Function(DateTime at, String? chairId) onTapSlot;

  /// Offers the waitlist for a cancelled or no-show slot.
  final void Function(Appointment appointment) onFillCancelled;

  /// Total drawn height of the time axis.
  static double get gridHeight =>
      (scheduleDayEndHour - scheduleDayStartHour) *
      60 /
      scheduleSlotMinutes *
      slotHeight;

  /// Vertical offset of [time] from the top of the grid; may be out of range.
  static double offsetFor(DateTime time) {
    final minutes =
        (time.hour - scheduleDayStartHour) * 60 +
        time.minute +
        time.second / 60;
    return minutes / scheduleSlotMinutes * slotHeight;
  }

  @override
  State<DayView> createState() => _DayViewState();
}

class _DayViewState extends State<DayView> {
  late final ScrollController _vertical;

  @override
  void initState() {
    super.initState();
    _vertical = ScrollController(initialScrollOffset: _initialOffset());
  }

  double _initialOffset() {
    if (!isSameDay(widget.day, widget.now)) return 0;
    final y = DayView.offsetFor(widget.now) - 120;
    return y.clamp(0, math.max(0, DayView.gridHeight - 200)).toDouble();
  }

  @override
  void dispose() {
    _vertical.dispose();
    super.dispose();
  }

  List<_Column> _columns() {
    final cols = [
      for (final c in widget.chairs) _Column(id: c.id, title: c.name),
    ];
    final chairIds = widget.chairs.map((c) => c.id).toSet();
    final orphan = widget.appointments.any(
      (a) => a.chairId == null || !chairIds.contains(a.chairId),
    );
    if (orphan || cols.isEmpty) {
      cols.add(const _Column(id: unassignedColumnId, title: 'No chair'));
    }
    return cols;
  }

  @override
  Widget build(BuildContext context) {
    final columns = _columns();
    final chairIds = widget.chairs.map((c) => c.id).toSet();
    final showNow =
        isSameDay(widget.day, widget.now) &&
        widget.now.hour >= scheduleDayStartHour &&
        widget.now.hour < scheduleDayEndHour;
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - timeGutterWidth;
        final width = math.max(minColumnWidth, available / columns.length);
        return SingleChildScrollView(
          controller: _vertical,
          child: SizedBox(
            height: DayView.gridHeight + columnHeaderHeight + AppSpacing.lg,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TimeGutter(now: showNow ? widget.now : null),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final col in columns)
                          SizedBox(
                            width: width,
                            child: _ChairColumn(
                              column: col,
                              day: widget.day,
                              now: showNow ? widget.now : null,
                              appointments: widget.appointments
                                  .where(
                                    (a) => col.id == unassignedColumnId
                                        ? a.chairId == null ||
                                              !chairIds.contains(a.chairId)
                                        : a.chairId == col.id,
                                  )
                                  .toList(),
                              members: widget.members,
                              patients: widget.patients,
                              onTapAppointment: widget.onTapAppointment,
                              onTapSlot: (at) => widget.onTapSlot(
                                at,
                                col.id == unassignedColumnId ? null : col.id,
                              ),
                              onFillCancelled: widget.onFillCancelled,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Column {
  const _Column({required this.id, required this.title});
  final String id;
  final String title;
}

class _TimeGutter extends StatelessWidget {
  const _TimeGutter({this.now});

  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return SizedBox(
      width: timeGutterWidth,
      height: DayView.gridHeight + columnHeaderHeight,
      child: Stack(
        children: [
          for (var h = scheduleDayStartHour; h < scheduleDayEndHour; h++)
            Positioned(
              top:
                  columnHeaderHeight +
                  DayView.offsetFor(DateTime(2000, 1, 1, h)) -
                  6,
              right: 6,
              child: Text(_hourLabel(h), style: style),
            ),
          if (now != null)
            Positioned(
              top: columnHeaderHeight + DayView.offsetFor(now!) - 8,
              right: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  borderRadius: AppRadii.smAll,
                ),
                child: Text(
                  AppFormat.time(now!),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onError,
                    fontSize: 9,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _hourLabel(int hour) {
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$h12 ${hour < 12 ? 'AM' : 'PM'}';
  }
}

class _ChairColumn extends StatelessWidget {
  const _ChairColumn({
    required this.column,
    required this.day,
    required this.now,
    required this.appointments,
    required this.members,
    required this.patients,
    required this.onTapAppointment,
    required this.onTapSlot,
    required this.onFillCancelled,
  });

  final _Column column;
  final DateTime day;
  final DateTime? now;
  final List<Appointment> appointments;
  final List<ClinicMember> members;
  final Map<String, Patient> patients;
  final void Function(Appointment) onTapAppointment;
  final void Function(DateTime at) onTapSlot;
  final void Function(Appointment) onFillCancelled;

  void _handleTap(TapUpDetails details) {
    final y = details.localPosition.dy - columnHeaderHeight;
    if (y < 0 || y >= DayView.gridHeight) return;
    final slot = (y / slotHeight).floor();
    final at = DateTime(
      day.year,
      day.month,
      day.day,
      scheduleDayStartHour,
      slot * scheduleSlotMinutes,
    );
    onTapSlot(at);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sorted = appointments.toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final lanes = <String, int>{};
    for (var i = 0; i < sorted.length; i++) {
      var lane = 0;
      for (var j = 0; j < i; j++) {
        if (sorted[j].status.occupiesChair &&
            sorted[i].status.occupiesChair &&
            sorted[j].overlaps(sorted[i])) {
          lane = math.max(lane, (lanes[sorted[j].id] ?? 0) + 1);
        }
      }
      lanes[sorted[i].id] = lane % 3;
    }
    return GestureDetector(
      key: ValueKey('schedule-column-${column.id}'),
      behavior: HitTestBehavior.opaque,
      onTapUp: _handleTap,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: ScheduleGridPainter(
                hourColor: scheme.outlineVariant,
                slotColor: scheme.outlineVariant.withValues(alpha: 0.35),
                borderColor: scheme.outlineVariant,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: columnHeaderHeight,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                border: Border(bottom: BorderSide(color: scheme.outline)),
              ),
              child: Text(
                column.title,
                style: Theme.of(context).textTheme.labelLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          for (final a in sorted)
            AppointmentBlock(
              appointment: a,
              lane: lanes[a.id] ?? 0,
              patient: patients[a.patientId],
              colour: providerColour(a.providerId, members),
              onTap: () => onTapAppointment(a),
              onFill: () => onFillCancelled(a),
            ),
          if (now != null)
            Positioned(
              top: columnHeaderHeight + DayView.offsetFor(now!) - 1,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  key: const ValueKey('schedule-now-line'),
                  height: 2,
                  color: scheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
