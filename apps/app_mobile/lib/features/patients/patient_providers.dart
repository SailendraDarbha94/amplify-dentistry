import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Patients matching a search query (name, phone or patient number); all
/// active patients when the query is blank.
final patientSearchProvider = StreamProvider.family<List<Patient>, String>((
  ref,
  query,
) {
  final clinicId = ref.watch(currentClinicIdProvider);
  if (clinicId == null) return Stream.value(const []);
  final q = query.trim();
  return ref
      .watch(patientRepositoryProvider)
      .watchAll(clinicId, query: q.isEmpty ? null : q);
});

/// Most recently updated patients, newest first.
final StreamProvider<List<Patient>> recentPatientsProvider =
    StreamProvider<List<Patient>>((ref) {
      final clinicId = ref.watch(currentClinicIdProvider);
      if (clinicId == null) return Stream.value(const []);
      return ref
          .watch(patientRepositoryProvider)
          .watchRecent(clinicId, limit: 20);
    });

/// Number of active patients in the clinic.
final StreamProvider<int> patientCountProvider = StreamProvider<int>((ref) {
  final clinicId = ref.watch(currentClinicIdProvider);
  if (clinicId == null) return Stream.value(0);
  return ref.watch(patientRepositoryProvider).watchCount(clinicId);
});

/// One patient by id (null when not found).
final patientProvider = StreamProvider.family<Patient?, String>(
  (ref, id) => ref.watch(patientRepositoryProvider).watchById(id),
);

/// Outstanding balance of a patient.
final patientBalanceProvider = StreamProvider.family<Money, String>(
  (ref, id) => ref.watch(billingRepositoryProvider).watchPatientBalance(id),
);

/// Latest medical history snapshot of a patient, for red flags.
final latestMedicalHistoryProvider =
    StreamProvider.family<MedicalHistory?, String>(
      (ref, id) =>
          ref.watch(clinicalRepositoryProvider).watchLatestMedicalHistory(id),
    );

/// Latest data consent per purpose for a patient.
final latestDataConsentsProvider =
    FutureProvider.family<Map<DataPurpose, DataConsent>, String>(
      (ref, id) => ref.watch(consentRepositoryProvider).latestDataConsents(id),
    );

/// Procedures of a patient (live).
final patientProceduresProvider =
    StreamProvider.family<List<ProcedureRecord>, String>(
      (ref, id) =>
          ref.watch(chartRepositoryProvider).watchProceduresForPatient(id),
    );

/// Invoices of a patient (live).
final patientInvoicesProvider = StreamProvider.family<List<Invoice>, String>(
  (ref, id) => ref.watch(billingRepositoryProvider).watchInvoices(id),
);

/// Clinical notes of a patient (live).
final patientNotesProvider = StreamProvider.family<List<ClinicalNote>, String>(
  (ref, id) => ref.watch(clinicalRepositoryProvider).watchNotesForPatient(id),
);

/// Outbound messages about a patient (live), newest first.
final patientMessagesProvider = StreamProvider.family<List<MessageLog>, String>(
  (ref, id) => ref.watch(messageLogRepositoryProvider).watchForPatient(id),
);
