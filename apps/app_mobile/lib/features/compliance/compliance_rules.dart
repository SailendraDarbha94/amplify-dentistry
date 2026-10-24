/// Pure compliance rules: when the spore test is overdue and how close a
/// licence is to expiry. No Flutter, no repositories; the providers and
/// widgets feed these with entity lists.
library;

import 'package:ampdent_core/ampdent_core.dart';

/// A biological (spore) indicator must be run at least this often.
const int sporeTestIntervalDays = 7;

/// Licences expiring within this many days raise a banner.
const int licenceWarningDays = 60;

/// Whether a cycle carried a biological indicator (a spore test was run,
/// whatever its outcome).
bool hasSporeTest(SterilisationCycle cycle) {
  final r = cycle.biologicalIndicatorResult;
  return r != null && r != BiologicalIndicatorResult.notDone;
}

/// When the most recent spore test was run, or null when none is recorded.
DateTime? lastSporeTestAt(Iterable<SterilisationCycle> cycles) {
  DateTime? latest;
  for (final c in cycles) {
    if (!hasSporeTest(c)) continue;
    if (latest == null || c.cycledAt.isAfter(latest)) latest = c.cycledAt;
  }
  return latest;
}

/// Whether a spore test is due: none recorded, or the last one is
/// [intervalDays] or more days old at [now].
bool sporeTestOverdue(
  Iterable<SterilisationCycle> cycles,
  DateTime now, {
  int intervalDays = sporeTestIntervalDays,
}) {
  final last = lastSporeTestAt(cycles);
  if (last == null) return true;
  return now.difference(last).inDays >= intervalDays;
}

/// Whether the latest spore test failed (the autoclave must not be used).
bool lastSporeTestFailed(Iterable<SterilisationCycle> cycles) {
  SterilisationCycle? latest;
  for (final c in cycles) {
    if (!hasSporeTest(c)) continue;
    if (latest == null || c.cycledAt.isAfter(latest.cycledAt)) latest = c;
  }
  return latest?.biologicalIndicatorResult == BiologicalIndicatorResult.fail;
}

/// How urgently a licence needs attention.
enum LicenceAlertLevel {
  /// No expiry or QA date recorded.
  none,

  /// More than [licenceWarningDays] away.
  ok,

  /// Due within [licenceWarningDays].
  expiringSoon,

  /// Expiry or QA date has passed.
  expired,
}

/// The earliest of a licence's expiry and QA-due dates, or null.
DateTime? licenceNextDue(Licence licence) {
  final dates = [licence.expiresAt, licence.qaDueAt].whereType<DateTime>();
  if (dates.isEmpty) return null;
  return dates.reduce((a, b) => a.isBefore(b) ? a : b);
}

/// Alert level of [licence] at [now].
LicenceAlertLevel licenceAlertLevel(
  Licence licence,
  DateTime now, {
  int withinDays = licenceWarningDays,
}) {
  final due = licenceNextDue(licence);
  if (due == null) return LicenceAlertLevel.none;
  if (due.isBefore(now)) return LicenceAlertLevel.expired;
  if (!due.isAfter(now.add(Duration(days: withinDays)))) {
    return LicenceAlertLevel.expiringSoon;
  }
  return LicenceAlertLevel.ok;
}

/// Whole days from [now] to the licence's next due date; negative when past.
int? licenceDaysToDue(Licence licence, DateTime now) {
  final due = licenceNextDue(licence);
  if (due == null) return null;
  return due.difference(now).inDays;
}

/// Licences expired or expiring within [withinDays], soonest first.
List<Licence> licencesNeedingAttention(
  Iterable<Licence> licences,
  DateTime now, {
  int withinDays = licenceWarningDays,
}) {
  final list = licences.where((l) {
    final level = licenceAlertLevel(l, now, withinDays: withinDays);
    return level == LicenceAlertLevel.expired ||
        level == LicenceAlertLevel.expiringSoon;
  }).toList();
  list.sort((a, b) => licenceNextDue(a)!.compareTo(licenceNextDue(b)!));
  return list;
}

/// Licences sorted for the wallet: those with a due date soonest first,
/// then the rest by kind.
List<Licence> sortLicences(Iterable<Licence> licences) {
  final list = licences.toList();
  list.sort((a, b) {
    final da = licenceNextDue(a);
    final db = licenceNextDue(b);
    if (da == null && db == null) return a.kind.index.compareTo(b.kind.index);
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  });
  return list;
}

/// Number of compliance alerts to badge on the dashboard: one for an overdue
/// or failed spore test plus one per licence needing attention.
int complianceAlertCount({
  required Iterable<SterilisationCycle> cycles,
  required Iterable<Licence> licences,
  required DateTime now,
}) {
  var count = licencesNeedingAttention(licences, now).length;
  if (sporeTestOverdue(cycles, now) || lastSporeTestFailed(cycles)) count++;
  return count;
}

/// Cycles run in the local calendar month ([year], [month]), oldest first.
List<SterilisationCycle> cyclesInMonth(
  Iterable<SterilisationCycle> cycles,
  int year,
  int month,
) {
  final list = cycles.where((c) {
    final l = c.cycledAt.toLocal();
    return l.year == year && l.month == month;
  }).toList();
  list.sort((a, b) => a.cycledAt.compareTo(b.cycledAt));
  return list;
}
