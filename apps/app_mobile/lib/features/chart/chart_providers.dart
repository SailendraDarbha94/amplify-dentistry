import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chart_service.dart';

/// One patient by id for the chart pages (null when not found).
final chartPatientProvider = StreamProvider.family<Patient?, String>(
  (ref, id) => ref.watch(patientRepositoryProvider).watchById(id),
);

/// Current state per tooth, collapsed from the append-only history.
final toothStatesProvider =
    StreamProvider.family<Map<ToothId, ToothState>, String>(
      (ref, patientId) =>
          ref.watch(chartRepositoryProvider).watchCurrentStates(patientId),
    );

/// Full tooth-state history of a patient, oldest first.
final toothHistoryProvider =
    StreamProvider.family<List<ToothStateRecord>, String>(
      (ref, patientId) =>
          ref.watch(chartRepositoryProvider).watchToothStateHistory(patientId),
    );

/// Findings of a patient (deleted excluded), newest first.
final chartFindingsProvider = StreamProvider.family<List<Finding>, String>(
  (ref, patientId) =>
      ref.watch(chartRepositoryProvider).watchFindings(patientId),
);

/// Procedures of a patient (deleted excluded).
final chartProceduresProvider =
    StreamProvider.family<List<ProcedureRecord>, String>(
      (ref, patientId) => ref
          .watch(chartRepositoryProvider)
          .watchProceduresForPatient(patientId),
    );

/// Effective procedure catalogue of the current clinic.
final StreamProvider<List<CatalogItem>> catalogItemsProvider =
    StreamProvider<List<CatalogItem>>((ref) {
      final clinicId = ref.watch(currentClinicIdProvider);
      if (clinicId == null) return Stream.value(const []);
      return ref.watch(catalogRepositoryProvider).watchForClinic(clinicId);
    });

/// Catalogue indexed by item id (empty until loaded).
final Provider<Map<String, CatalogItem>> catalogByIdProvider =
    Provider<Map<String, CatalogItem>>((ref) {
      final items = ref.watch(catalogItemsProvider).value ?? const [];
      return {for (final item in items) item.id: item};
    });

/// Images (photos and radiographs) of a patient, for the pre-op guard.
final patientImagesProvider = FutureProvider.family<List<ImageRecord>, String>(
  (ref, patientId) =>
      ref.watch(clinicalRepositoryProvider).imagesForPatient(patientId),
);

/// Perio exams of a patient, newest first.
final perioExamsProvider = StreamProvider.family<List<PerioExam>, String>(
  (ref, patientId) => ref.watch(perioRepositoryProvider).watchExams(patientId),
);

/// The chart write service bound to the current actor.
final Provider<ChartService> chartServiceProvider = Provider<ChartService>(
  (ref) => ChartService(
    chart: ref.watch(chartRepositoryProvider),
    recalls: ref.watch(recallRepositoryProvider),
    clinics: ref.watch(clinicRepositoryProvider),
    ctx: ref.watch(actorContextProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// Seeds age-default tooth states the first time a patient's chart opens.
/// Resolves to the number of records written (0 when a chart existed).
final chartSeedProvider = FutureProvider.family<int, String>((
  ref,
  patientId,
) async {
  final patient = await ref.watch(patientRepositoryProvider).getById(patientId);
  if (patient == null) return 0;
  return ref.read(chartServiceProvider).seedAgeDefaults(patient);
});
