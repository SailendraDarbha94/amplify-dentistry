import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Active drug master, seeded from terminology when empty.
final FutureProvider<List<Drug>> drugsProvider = FutureProvider<List<Drug>>((
  ref,
) async {
  final repo = ref.watch(prescriptionRepositoryProvider);
  await repo.seedDrugMasterIfEmpty();
  return repo.drugs();
});

/// Drug master keyed by id.
final Provider<Map<String, Drug>> drugsByIdProvider =
    Provider<Map<String, Drug>>((ref) {
      final drugs = ref.watch(drugsProvider).value ?? const <Drug>[];
      return {for (final d in drugs) d.id: d};
    });

/// Prescriptions of a patient, newest first.
final patientPrescriptionsProvider =
    StreamProvider.family<List<Prescription>, String>(
      (ref, patientId) => ref
          .watch(prescriptionRepositoryProvider)
          .watchPrescriptions(patientId),
    );

/// One prescription by id.
final prescriptionProvider = FutureProvider.family<Prescription?, String>(
  (ref, id) => ref.watch(prescriptionRepositoryProvider).getPrescription(id),
);

/// Patient of a prescription screen.
final rxPatientProvider = StreamProvider.family<Patient?, String>(
  (ref, patientId) => ref.watch(patientRepositoryProvider).watchById(patientId),
);

/// Latest medical history, for allergy and pregnancy checks.
final rxMedicalHistoryProvider = StreamProvider.family<MedicalHistory?, String>(
  (ref, patientId) => ref
      .watch(clinicalRepositoryProvider)
      .watchLatestMedicalHistory(patientId),
);
