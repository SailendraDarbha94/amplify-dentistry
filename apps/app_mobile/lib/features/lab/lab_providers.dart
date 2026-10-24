import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Open lab cases of the clinic, due soonest first (live).
final StreamProvider<List<LabCase>> openLabCasesProvider =
    StreamProvider<List<LabCase>>((ref) {
      final clinicId = ref.watch(currentClinicIdProvider);
      if (clinicId == null) return Stream.value(const []);
      return ref.watch(labRepositoryProvider).watchOpenCases(clinicId);
    });

/// One lab case by id; invalidate after every write (no watch in the repo).
final labCaseProvider = FutureProvider.family<LabCase?, String>(
  (ref, id) => ref.watch(labRepositoryProvider).getCase(id),
);

/// Lab cases of a patient, newest first.
final patientLabCasesProvider = FutureProvider.family<List<LabCase>, String>(
  (ref, patientId) =>
      ref.watch(labRepositoryProvider).casesForPatient(patientId),
);

/// Active labs of the clinic ordered by name; invalidate after writes.
final FutureProvider<List<Lab>> labDirectoryProvider =
    FutureProvider<List<Lab>>((ref) {
      final clinicId = ref.watch(currentClinicIdProvider);
      if (clinicId == null) return Future.value(const []);
      return ref.watch(labRepositoryProvider).labs(clinicId);
    });

/// One lab by id (inactive labs included so old cases still resolve).
final labProvider = FutureProvider.family<Lab?, String>(
  (ref, id) => ref.watch(labRepositoryProvider).getLab(id),
);

/// Refreshes every lab-feature provider after a write.
void invalidateLabProviders(Ref ref, {String? caseId, String? patientId}) {
  ref.invalidate(labDirectoryProvider);
  if (caseId != null) ref.invalidate(labCaseProvider(caseId));
  if (patientId != null) ref.invalidate(patientLabCasesProvider(patientId));
}
