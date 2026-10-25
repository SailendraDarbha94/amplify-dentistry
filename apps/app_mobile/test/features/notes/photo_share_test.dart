import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/features/notes/photos/photo_share.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_env.dart';

/// Sharing a photo needs an active photo-use *data* consent (DPDP purpose
/// `photoUse`); its id is what `ImageRecord.sharingConsentId` references. A
/// signed procedure consent never qualifies.
void main() {
  late AppTestEnv env;
  final now = DateTime.utc(2026, 10, 25, 10);

  setUp(() async => env = await AppTestEnv.open(withPatient: true));
  tearDown(() => env.close());

  DataConsent consent({
    String id = 'dc-photo',
    DataPurpose purpose = DataPurpose.photoUse,
    bool granted = true,
    String patientId = testPatientId,
    DateTime? at,
  }) => DataConsent(
    id: id,
    clinicId: testClinicId,
    patientId: patientId,
    purpose: purpose,
    granted: granted,
    noticeVersion: '1',
    languageCode: 'en',
    channel: 'inClinic',
    grantedAt: at ?? now,
    createdAt: at ?? now,
  );

  ImageRecord image() => ImageRecord(
    id: 'img-1',
    clinicId: testClinicId,
    patientId: testPatientId,
    kind: ImageKind.photoIntraoral,
    filePath: 'img-1.jpg',
    capturedAt: now,
    createdAt: now,
  );

  test('no data consent: nothing to share under', () async {
    expect(await photoShareConsent(env.repos.consents, testPatientId), isNull);
    // A signed PHOTO-USE procedure consent is not a data consent.
    expect(activePhotoUseConsent(const []), isNull);
  });

  test('another purpose or a declined toggle does not count', () async {
    await env.repos.consents.recordDataConsent(
      testCtx,
      consent(id: 'dc-appt', purpose: DataPurpose.appointmentReminders),
    );
    await env.repos.consents.recordDataConsent(
      testCtx,
      consent(id: 'dc-declined', granted: false),
    );
    expect(await photoShareConsent(env.repos.consents, testPatientId), isNull);
  });

  test('a granted photo-use consent is used and stored on the image', () async {
    final granted = await env.repos.consents.recordDataConsent(
      testCtx,
      consent(),
    );
    final found = await photoShareConsent(env.repos.consents, testPatientId);
    expect(found?.id, granted.id);

    await env.repos.clinical.addImage(testCtx, image());
    final shared = await markPhotoShared(
      env.repos.clinical,
      testCtx,
      image(),
      found!,
    );
    expect(shared.sharingConsentId, 'dc-photo');
    expect(
      (await env.repos.clinical.getImage('img-1'))!.sharingConsentId,
      'dc-photo',
    );
  });

  test('a withdrawn consent blocks sharing again', () async {
    final granted = await env.repos.consents.recordDataConsent(
      testCtx,
      consent(),
    );
    await env.repos.consents.withdrawDataConsent(testCtx, granted.id, at: now);
    expect(await photoShareConsent(env.repos.consents, testPatientId), isNull);
    await env.repos.clinical.addImage(testCtx, image());
    final withdrawn = (await env.repos.consents.dataConsentsForPatient(
      testPatientId,
    )).single;
    expect(
      () => markPhotoShared(env.repos.clinical, testCtx, image(), withdrawn),
      throwsArgumentError,
    );
  });

  test('the newest active consent wins', () {
    final older = consent(id: 'old', at: now.subtract(const Duration(days: 9)));
    final newer = consent(id: 'new');
    expect(activePhotoUseConsent([older, newer])?.id, 'new');
    expect(activePhotoUseConsent([newer, older])?.id, 'new');
  });

  test('the fallback route is the patient profile with the toggles', () {
    expect(dataConsentLocation('p1'), '/patients/p1/edit');
  });
}
