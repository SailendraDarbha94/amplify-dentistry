/// Live data behind the Today dashboard.
///
/// Repositories are patient-scoped by design, so the clinic-wide aggregates
/// (production, collections, accepted plans) read the Drift tables directly
/// through [databaseProvider] and filter in Dart; these are read-only
/// streams and every write still goes through a repository.
library;

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'today_kpis.dart';

/// Appointments whose start falls on the local calendar day of now.
final StreamProvider<List<Appointment>> todaysAppointmentsProvider =
    StreamProvider<List<Appointment>>((ref) {
      final clinicId = ref.watch(currentClinicIdProvider);
      if (clinicId == null) return Stream.value(const []);
      final now = ref.watch(clockProvider)();
      final start = startOfLocalDay(now);
      final end = start.add(const Duration(days: 1));
      return ref
          .watch(appointmentRepositoryProvider)
          .watchRange(clinicId, start.toUtc(), end.toUtc())
          .map((list) {
            final sorted = list.toList()
              ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
            return sorted;
          });
    });

/// Patients of today's appointments, keyed by id.
final StreamProvider<Map<String, Patient>> todaysPatientsProvider =
    StreamProvider<Map<String, Patient>>((ref) {
      final appointments = ref.watch(todaysAppointmentsProvider).value;
      if (appointments == null || appointments.isEmpty) {
        return Stream.value(const {});
      }
      final ids = appointments.map((a) => a.patientId).toSet();
      return ref
          .watch(patientRepositoryProvider)
          .watchByIds(ids)
          .map((list) => {for (final p in list) p.id: p});
    });

/// Recalls that are due or overdue right now (due / notified, not yet
/// scheduled).
final StreamProvider<List<Recall>> dueRecallsProvider =
    StreamProvider<List<Recall>>((ref) {
      final clinicId = ref.watch(currentClinicIdProvider);
      if (clinicId == null) return Stream.value(const []);
      final now = ref.watch(clockProvider)();
      return ref
          .watch(recallRepositoryProvider)
          .watchDue(clinicId, until: now.toUtc());
    });

/// Rupee value of recalls that are due or overdue right now.
final StreamProvider<Money> overdueRecallValueProvider = StreamProvider<Money>((
  ref,
) {
  final clinicId = ref.watch(currentClinicIdProvider);
  if (clinicId == null) return Stream.value(const Money.zero());
  final now = ref.watch(clockProvider)();
  return ref
      .watch(recallRepositoryProvider)
      .watchDue(clinicId, until: now.toUtc())
      .map((list) => list.map((r) => r.estimatedValue).total);
});

/// Appointments from the start of this month to a year ahead: enough for the
/// no-show rate and for the "already scheduled" check on accepted plans.
final StreamProvider<List<Appointment>> horizonAppointmentsProvider =
    StreamProvider<List<Appointment>>((ref) {
      final clinicId = ref.watch(currentClinicIdProvider);
      if (clinicId == null) return Stream.value(const []);
      final now = ref.watch(clockProvider)();
      final from = startOfLocalMonth(now);
      final to = from.add(const Duration(days: 400));
      return ref
          .watch(appointmentRepositoryProvider)
          .watchRange(clinicId, from.toUtc(), to.toUtc());
    });

/// Every procedure row of the clinic (live, read-only).
final StreamProvider<List<ProcedureRecord>> clinicProceduresProvider =
    StreamProvider<List<ProcedureRecord>>((ref) {
      final clinicId = ref.watch(currentClinicIdProvider);
      if (clinicId == null) return Stream.value(const []);
      final db = ref.watch(databaseProvider);
      return db
          .select(db.procedures)
          .watch()
          .map((rows) => rows.where((p) => p.clinicId == clinicId).toList());
    });

/// Payments received by the clinic this month (live, read-only).
final StreamProvider<List<Payment>> monthPaymentsProvider =
    StreamProvider<List<Payment>>((ref) {
      final clinicId = ref.watch(currentClinicIdProvider);
      if (clinicId == null) return Stream.value(const []);
      final now = ref.watch(clockProvider)();
      final db = ref.watch(databaseProvider);
      return db
          .select(db.payments)
          .watch()
          .map(
            (rows) => rows
                .where(
                  (p) =>
                      p.clinicId == clinicId &&
                      sameLocalMonth(p.receivedAt, now),
                )
                .toList(),
          );
    });

/// Accepted treatment plans of the clinic (live, read-only).
final StreamProvider<List<TreatmentPlan>> acceptedPlansProvider =
    StreamProvider<List<TreatmentPlan>>((ref) {
      final clinicId = ref.watch(currentClinicIdProvider);
      if (clinicId == null) return Stream.value(const []);
      final db = ref.watch(databaseProvider);
      return db
          .select(db.treatmentPlans)
          .watch()
          .map(
            (rows) => rows
                .where(
                  (p) =>
                      p.clinicId == clinicId &&
                      p.status == TreatmentPlanStatus.accepted,
                )
                .toList(),
          );
    });

/// Lines of every accepted plan, loaded through the repository so removed
/// lines are excluded.
final StreamProvider<List<TreatmentPlanLine>> acceptedPlanLinesProvider =
    StreamProvider<List<TreatmentPlanLine>>((ref) {
      final plans = ref.watch(acceptedPlansProvider).value;
      if (plans == null || plans.isEmpty) return Stream.value(const []);
      final repo = ref.watch(treatmentPlanRepositoryProvider);
      return Stream.fromFuture(() async {
        final all = <TreatmentPlanLine>[];
        for (final plan in plans) {
          all.addAll(await repo.linesForPlan(plan.id));
        }
        return all;
      }());
    });

/// The five dashboard numbers; null until every input has loaded once.
final Provider<TodayKpis?> todayKpisProvider = Provider<TodayKpis?>((ref) {
  final procedures = ref.watch(clinicProceduresProvider).value;
  final payments = ref.watch(monthPaymentsProvider).value;
  final recalls = ref.watch(dueRecallsProvider).value;
  final plans = ref.watch(acceptedPlansProvider).value;
  final lines = ref.watch(acceptedPlanLinesProvider).value;
  final appointments = ref.watch(horizonAppointmentsProvider).value;
  if (procedures == null ||
      payments == null ||
      recalls == null ||
      plans == null ||
      lines == null ||
      appointments == null) {
    return null;
  }
  return TodayKpis.compute(
    now: ref.watch(clockProvider)(),
    procedures: procedures,
    payments: payments,
    dueRecalls: recalls,
    plans: plans,
    lines: lines,
    appointments: appointments,
  );
});

/// Number of local writes waiting for the (future) sync backend.
final StreamProvider<int> pendingOutboxCountProvider = StreamProvider<int>((
  ref,
) {
  final clinicId = ref.watch(currentClinicIdProvider);
  if (clinicId == null) return Stream.value(0);
  return ref.watch(outboxRepositoryProvider).watchPendingCount(clinicId);
});
