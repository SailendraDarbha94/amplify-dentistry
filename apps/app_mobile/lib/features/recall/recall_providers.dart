import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'incomplete_treatment.dart';
import 'recall_model.dart';

/// Open recalls (`due` / `notified`) due up to [recallUpcomingWindowDays]
/// ahead, overdue first.
final StreamProvider<List<Recall>> recallWindowProvider =
    StreamProvider<List<Recall>>((ref) {
      final clinicId = ref.watch(currentClinicIdProvider);
      if (clinicId == null) return Stream.value(const []);
      final now = ref.watch(clockProvider)();
      return ref
          .watch(recallRepositoryProvider)
          .watchDue(
            clinicId,
            until: now
                .add(const Duration(days: recallUpcomingWindowDays))
                .toUtc(),
          );
    });

/// Selected recall types on the list; empty means every type.
class RecallTypeFilter extends Notifier<Set<RecallType>> {
  @override
  Set<RecallType> build() => const {};

  /// Replaces the selection.
  void set(Set<RecallType> types) => state = Set.unmodifiable(types);
}

/// Type filter state of the recall list.
final NotifierProvider<RecallTypeFilter, Set<RecallType>>
recallTypeFilterProvider = NotifierProvider<RecallTypeFilter, Set<RecallType>>(
  RecallTypeFilter.new,
);

/// Grouped, filtered recalls for the list.
final Provider<AsyncValue<Map<RecallGroup, List<Recall>>>>
groupedRecallsProvider = Provider<AsyncValue<Map<RecallGroup, List<Recall>>>>((
  ref,
) {
  final filter = ref.watch(recallTypeFilterProvider);
  final now = ref.watch(clockProvider)();
  return ref
      .watch(recallWindowProvider)
      .whenData((list) => groupRecalls(filterRecallsByType(list, filter), now));
});

/// Every live procedure of the clinic, across patients. `ChartRepository`
/// only queries per patient, so this is a read-only Drift select on the
/// procedures table; no write ever goes this way.
final StreamProvider<List<ProcedureRecord>> clinicProceduresProvider =
    StreamProvider<List<ProcedureRecord>>((ref) {
      final clinicId = ref.watch(currentClinicIdProvider);
      if (clinicId == null) return Stream.value(const []);
      final db = ref.watch(databaseProvider);
      return (db.select(
        db.procedures,
      )..where((t) => t.clinicId.equals(clinicId))).watch().map(
        (rows) =>
            rows.where((p) => p.status != ProcedureStatus.deleted).toList(),
      );
    });

/// Incomplete-treatment findings for the clinic as of now.
final Provider<AsyncValue<List<IncompleteTreatment>>>
incompleteTreatmentsProvider = Provider<AsyncValue<List<IncompleteTreatment>>>((
  ref,
) {
  final now = ref.watch(clockProvider)();
  return ref
      .watch(clinicProceduresProvider)
      .whenData((list) => detectIncompleteTreatments(list, now: now));
});

/// Most recent visit of a patient, or null when never seen.
final lastVisitProvider = StreamProvider.family<Visit?, String>(
  (ref, patientId) => ref
      .watch(appointmentRepositoryProvider)
      .watchVisits(patientId)
      .map((visits) => visits.isEmpty ? null : visits.first),
);
