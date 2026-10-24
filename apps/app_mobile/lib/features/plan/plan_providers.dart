import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'plan_service.dart';

/// Plans of a patient, active first then newest first (live).
final patientPlansProvider = StreamProvider.family<List<TreatmentPlan>, String>(
  (ref, patientId) {
    return ref.watch(treatmentPlanRepositoryProvider).watchPlans(patientId).map(
      (list) {
        final sorted = list.toList()
          ..sort((a, b) {
            final ra = a.status == TreatmentPlanStatus.active ? 0 : 1;
            final rb = b.status == TreatmentPlanStatus.active ? 0 : 1;
            if (ra != rb) return ra.compareTo(rb);
            return b.createdAt.compareTo(a.createdAt);
          });
        return sorted;
      },
    );
  },
);

/// One plan of a patient, live, keyed by `(patientId, planId)`.
final planProvider = StreamProvider.family<TreatmentPlan?, (String, String)>((
  ref,
  key,
) {
  final (patientId, planId) = key;
  return ref.watch(treatmentPlanRepositoryProvider).watchPlans(patientId).map((
    list,
  ) {
    for (final p in list) {
      if (p.id == planId) return p;
    }
    return null;
  });
});

/// Live lines of a plan.
final planLinesProvider =
    StreamProvider.family<List<TreatmentPlanLine>, String>(
      (ref, planId) =>
          ref.watch(treatmentPlanRepositoryProvider).watchLines(planId),
    );

/// Estimates issued for a plan, oldest version first.
final planEstimatesProvider = FutureProvider.family<List<Estimate>, String>(
  (ref, planId) =>
      ref.watch(treatmentPlanRepositoryProvider).estimatesForPlan(planId),
);

/// Procedures of a patient (live), for funnel chips and the add-line sheet.
final planProceduresProvider =
    StreamProvider.family<List<ProcedureRecord>, String>(
      (ref, patientId) => ref
          .watch(chartRepositoryProvider)
          .watchProceduresForPatient(patientId),
    );

/// Appointments of a patient (live), for the `scheduled` funnel chip.
final planAppointmentsProvider =
    StreamProvider.family<List<Appointment>, String>(
      (ref, patientId) =>
          ref.watch(appointmentRepositoryProvider).watchForPatient(patientId),
    );

/// Effective catalogue of the current clinic (live).
final StreamProvider<List<CatalogItem>> catalogItemsProvider =
    StreamProvider<List<CatalogItem>>((ref) {
      final clinicId = ref.watch(currentClinicIdProvider);
      if (clinicId == null) return Stream.value(const []);
      return ref.watch(catalogRepositoryProvider).watchForClinic(clinicId);
    });

/// Catalogue items by id, for fee-range checks and GST labels.
final Provider<Map<String, CatalogItem>> catalogByIdProvider =
    Provider<Map<String, CatalogItem>>((ref) {
      final items = ref.watch(catalogItemsProvider).value ?? const [];
      return {for (final i in items) i.id: i};
    });

/// GST rate table of the current clinic.
final FutureProvider<GstRateTable> gstRateTableProvider =
    FutureProvider<GstRateTable>((ref) {
      final clinicId = ref.watch(currentClinicIdProvider);
      if (clinicId == null) return Future.value(GstRateTable.indiaDefaults());
      return ref.watch(clinicRepositoryProvider).loadGstRateTable(clinicId);
    });

/// The plan service bound to the current actor.
final Provider<PlanService> planServiceProvider = Provider<PlanService>(
  (ref) => PlanService(
    plans: ref.watch(treatmentPlanRepositoryProvider),
    chart: ref.watch(chartRepositoryProvider),
    catalog: ref.watch(catalogRepositoryProvider),
    ctx: ref.watch(actorContextProvider),
  ),
);
