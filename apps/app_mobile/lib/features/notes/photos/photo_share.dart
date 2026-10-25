import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';

/// Where the patient's DPDP data-consent toggles live (the patient form).
String dataConsentLocation(String patientId) => '/patients/$patientId/edit';

/// The active (granted, not withdrawn) photo-use data consent among
/// [consents], newest first; null when the patient has not consented or has
/// withdrawn it.
DataConsent? activePhotoUseConsent(Iterable<DataConsent> consents) {
  final matches =
      consents
          .where((c) => c.purpose == DataPurpose.photoUse && c.isActive)
          .toList()
        ..sort((a, b) => b.grantedAt.compareTo(a.grantedAt));
  return matches.firstOrNull;
}

/// Resolves the photo-use [DataConsent] a share must be covered by: a
/// `ConsentRecord` (procedure consent) never qualifies, since
/// `ImageRecord.sharingConsentId` references `data_consents`.
Future<DataConsent?> photoShareConsent(
  ConsentRepository consents,
  String patientId,
) async =>
    activePhotoUseConsent(await consents.dataConsentsForPatient(patientId));

/// Records that [image] was shared under [consent] (its id goes into
/// `sharingConsentId`) and returns the updated row. Throws [ArgumentError]
/// when [consent] is not an active photo-use consent of the image's patient.
Future<ImageRecord> markPhotoShared(
  ClinicalRepository clinical,
  ActorContext ctx,
  ImageRecord image,
  DataConsent consent,
) {
  if (consent.purpose != DataPurpose.photoUse ||
      !consent.isActive ||
      consent.patientId != image.patientId) {
    throw ArgumentError.value(
      consent.id,
      'consent',
      'must be an active photo-use data consent of the same patient',
    );
  }
  return clinical.updateImage(
    ctx,
    image.copyWith(sharingConsentId: consent.id),
  );
}
