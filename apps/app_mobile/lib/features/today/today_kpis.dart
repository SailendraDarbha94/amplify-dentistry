/// Pure KPI arithmetic for the Today dashboard. Every function takes plain
/// entity lists and a reference instant so tests can pin the clock; the
/// providers in `today_providers.dart` feed them live data.
///
/// The five home-screen numbers come from docs/research/02-product-spec.md
/// ("Reports and KPIs"): today's production, this month's collections,
/// overdue recall value, accepted-but-unscheduled value and no-show rate.
library;

import 'package:ampdent_core/ampdent_core.dart';
import 'package:flutter/foundation.dart';

/// Whether [a] and [b] fall on the same local calendar day.
bool sameLocalDay(DateTime a, DateTime b) {
  final la = a.toLocal();
  final lb = b.toLocal();
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}

/// Whether [a] and [b] fall in the same local calendar month.
bool sameLocalMonth(DateTime a, DateTime b) {
  final la = a.toLocal();
  final lb = b.toLocal();
  return la.year == lb.year && la.month == lb.month;
}

/// Local midnight at the start of [day].
DateTime startOfLocalDay(DateTime day) {
  final l = day.toLocal();
  return DateTime(l.year, l.month, l.day);
}

/// Local midnight on the first day of the month containing [day].
DateTime startOfLocalMonth(DateTime day) {
  final l = day.toLocal();
  return DateTime(l.year, l.month);
}

/// Local midnight on the first day of the month after [day]'s month.
DateTime startOfNextLocalMonth(DateTime day) {
  final l = day.toLocal();
  return DateTime(l.year, l.month + 1);
}

/// Today's production: net fees of procedures completed on the local day of
/// [day]. Deleted and non-completed rows never count.
Money productionOn(Iterable<ProcedureRecord> procedures, DateTime day) =>
    procedures
        .where(
          (p) =>
              p.status == ProcedureStatus.completed &&
              p.completedAt != null &&
              sameLocalDay(p.completedAt!, day),
        )
        .map((p) => p.netFee)
        .total;

/// Collections in the local month of [month]: payments received minus
/// refunds issued.
Money collectionsInMonth(Iterable<Payment> payments, DateTime month) => payments
    .where((p) => sameLocalMonth(p.receivedAt, month))
    .map((p) => p.isRefund ? -p.amount : p.amount)
    .total;

/// Attendance tallies for a month: how many appointments completed and how
/// many were no-shows.
@immutable
class AttendanceTally {
  /// Creates a tally.
  const AttendanceTally({required this.completed, required this.noShow});

  /// Appointments marked completed.
  final int completed;

  /// Appointments marked no-show.
  final int noShow;

  /// `noShow / (completed + noShow)`, or null when nothing happened yet.
  double? get noShowRate {
    final total = completed + noShow;
    return total == 0 ? null : noShow / total;
  }
}

/// Counts completed and no-show appointments whose start falls in the local
/// month of [month].
AttendanceTally attendanceInMonth(
  Iterable<Appointment> appointments,
  DateTime month,
) {
  var completed = 0;
  var noShow = 0;
  for (final a in appointments) {
    if (!sameLocalMonth(a.startsAt, month)) continue;
    if (a.status == AppointmentStatus.completed) completed++;
    if (a.status == AppointmentStatus.noShow) noShow++;
  }
  return AttendanceTally(completed: completed, noShow: noShow);
}

/// Value of accepted treatment that has no appointment yet.
///
/// A line counts when its plan is accepted, it is not an alternative, and
/// the work is still open: its procedure (if any) is neither completed nor
/// in progress, and no live appointment (scheduled, confirmed, arrived or in
/// chair) lists that procedure among its planned procedures.
Money unscheduledAcceptedValue({
  required Iterable<TreatmentPlan> plans,
  required Iterable<TreatmentPlanLine> lines,
  required Iterable<ProcedureRecord> procedures,
  required Iterable<Appointment> appointments,
}) {
  final acceptedPlanIds = {
    for (final p in plans)
      if (p.status == TreatmentPlanStatus.accepted) p.id,
  };
  if (acceptedPlanIds.isEmpty) return const Money.zero();
  final proceduresById = {for (final p in procedures) p.id: p};
  final scheduledProcedureIds = <String>{
    for (final a in appointments)
      if (a.status.occupiesChair) ...a.plannedProcedureIds,
  };
  var total = const Money.zero();
  for (final line in lines) {
    if (line.isAlternative || !acceptedPlanIds.contains(line.planId)) continue;
    final procedureId = line.procedureId;
    if (procedureId != null) {
      final procedure = proceduresById[procedureId];
      if (procedure != null &&
          (procedure.status == ProcedureStatus.completed ||
              procedure.status == ProcedureStatus.inProgress ||
              procedure.status == ProcedureStatus.deleted)) {
        continue;
      }
      if (scheduledProcedureIds.contains(procedureId)) continue;
    }
    total += line.net;
  }
  return total;
}

/// The five dashboard numbers, computed once per data change.
@immutable
class TodayKpis {
  /// Creates the KPI set.
  const TodayKpis({
    required this.productionToday,
    required this.collectionsThisMonth,
    required this.overdueRecallValue,
    required this.acceptedUnscheduledValue,
    required this.attendance,
  });

  /// Net fees of procedures completed today.
  final Money productionToday;

  /// Payments received this month, net of refunds.
  final Money collectionsThisMonth;

  /// Estimated value of recalls that are due or overdue.
  final Money overdueRecallValue;

  /// Accepted plan lines with no appointment.
  final Money acceptedUnscheduledValue;

  /// Completed vs no-show tallies for this month.
  final AttendanceTally attendance;

  /// No-show rate this month, or null when nothing happened yet.
  double? get noShowRate => attendance.noShowRate;

  /// Computes every KPI from entity lists at [now].
  factory TodayKpis.compute({
    required DateTime now,
    required Iterable<ProcedureRecord> procedures,
    required Iterable<Payment> payments,
    required Iterable<Recall> dueRecalls,
    required Iterable<TreatmentPlan> plans,
    required Iterable<TreatmentPlanLine> lines,
    required Iterable<Appointment> appointments,
  }) => TodayKpis(
    productionToday: productionOn(procedures, now),
    collectionsThisMonth: collectionsInMonth(payments, now),
    overdueRecallValue: dueRecalls.map((r) => r.estimatedValue).total,
    acceptedUnscheduledValue: unscheduledAcceptedValue(
      plans: plans,
      lines: lines,
      procedures: procedures,
      appointments: appointments,
    ),
    attendance: attendanceInMonth(appointments, now),
  );
}

/// `12%` style label for a rate in `[0, 1]`; `-` when null.
String formatRate(double? rate) =>
    rate == null ? '-' : '${(rate * 100).round()}%';
