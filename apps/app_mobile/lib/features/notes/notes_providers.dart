import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'photos/photo_share.dart';
import 'photos/photo_source.dart';
import 'photos/photo_store.dart';
import 'red_flags.dart';

/// Template code of the clinical photography consent.
const String photoUseTemplateCode = 'PHOTO-USE';

/// Latest version of every clinical note of a patient, newest first.
final notesForPatientProvider =
    StreamProvider.family<List<ClinicalNote>, String>(
      (ref, patientId) =>
          ref.watch(clinicalRepositoryProvider).watchNotesForPatient(patientId),
    );

/// One clinical note by id.
final noteProvider = FutureProvider.family<ClinicalNote?, String>(
  (ref, noteId) => ref.watch(clinicalRepositoryProvider).getNote(noteId),
);

/// Every version in the chain that contains [noteId], oldest first.
final noteVersionsProvider = FutureProvider.family<List<ClinicalNote>, String>(
  (ref, noteId) => ref.watch(clinicalRepositoryProvider).noteVersions(noteId),
);

/// Latest medical history snapshot of a patient.
final medicalHistoryProvider = StreamProvider.family<MedicalHistory?, String>(
  (ref, patientId) => ref
      .watch(clinicalRepositoryProvider)
      .watchLatestMedicalHistory(patientId),
);

/// Red flags of a patient derived from the latest medical history, with the
/// detail text shown on banners. Empty until the history has loaded.
final patientRedFlagsProvider = Provider.family<List<RedFlagInfo>, String>((
  ref,
  patientId,
) {
  final history = ref.watch(medicalHistoryProvider(patientId)).value;
  return history == null ? const [] : redFlagInfos(history);
});

/// Images of a patient, newest first.
final patientImagesProvider = StreamProvider.family<List<ImageRecord>, String>(
  (ref, patientId) =>
      ref.watch(clinicalRepositoryProvider).watchImages(patientId),
);

/// The patient's clinical photography consent, or null when none is signed.
final photoUseConsentProvider = StreamProvider.family<ConsentRecord?, String>(
  (ref, patientId) =>
      ref.watch(consentRepositoryProvider).watchConsents(patientId).map((list) {
        final matches = list
            .where((c) => c.templateCode == photoUseTemplateCode)
            .toList();
        if (matches.isEmpty) return null;
        matches.sort((a, b) => b.signedAt.compareTo(a.signedAt));
        return matches.first;
      }),
);

/// The patient's active photo-use data consent (DPDP purpose `photoUse`), or
/// null when none is granted or it was withdrawn. Sharing a photo requires it.
final photoUseDataConsentProvider = StreamProvider.family<DataConsent?, String>(
  (ref, patientId) => ref
      .watch(consentRepositoryProvider)
      .watchDataConsents(patientId)
      .map(activePhotoUseConsent),
);

/// The patient a notes screen belongs to.
final notesPatientProvider = StreamProvider.family<Patient?, String>(
  (ref, patientId) => ref.watch(patientRepositoryProvider).watchById(patientId),
);

/// Procedures a photo can be linked to (planned, in progress or completed).
final linkableProceduresProvider =
    StreamProvider.family<List<ProcedureRecord>, String>(
      (ref, patientId) => ref
          .watch(chartRepositoryProvider)
          .watchProceduresForPatient(patientId),
    );

/// Where photo files live; overridden in tests with a temp directory.
final Provider<PhotoStore> photoStoreProvider = Provider<PhotoStore>(
  (ref) => LocalPhotoStore(root: applicationDocumentsRoot),
);

/// Camera / gallery picker; overridden in tests with a fake.
final Provider<PhotoSource> photoSourceProvider = Provider<PhotoSource>(
  (ref) => const ImagePickerPhotoSource(),
);

/// Resolved file path of an image record (store-relative paths become
/// absolute).
final imageFilePathProvider = FutureProvider.family<String, String>(
  (ref, filePath) async =>
      (await ref.watch(photoStoreProvider).resolve(filePath)).path,
);
