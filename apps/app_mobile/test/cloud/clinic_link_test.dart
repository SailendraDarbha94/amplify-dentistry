import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_mobile/core/clinic_link.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/core/remote_devices.dart';
import 'package:ampdent_mobile/core/session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'cloud_test_support.dart';

/// The linker rules as the app applies them after sign-in.
void main() {
  late FakeSupabase fake;

  setUp(() => fake = FakeSupabase());

  test(
    'local clinic, no remote membership: pushes the clinic and links',
    () async {
      final env = await openCloudEnv(fake);
      addTearDown(env.close);
      await signIn(env.container, fake);
      final state = await runLink(env.container);

      expect(state.phase, LinkPhase.linked, reason: state.error);
      expect(state.link!.mode, ClinicLinkMode.pushedLocal);
      expect(state.link!.clinicId, testClinicId);
      expect(fake.row('clinics', testClinicId), isNotNull);
      final member = fake.row('clinic_members', testDentistId)!;
      expect(member['user_id'], fake.userId);
      expect(member['clinic_id'], testClinicId);
      // The device that created the clinic is its primary device.
      final device = fake.row('devices', testDeviceId)!;
      expect(device['clinic_id'], testClinicId);
      expect(device['is_primary'], isTrue);
      expect(device['platform'], devicePlatformName());
      // The link is recorded for the engine and the device id for sync.
      final syncState = DriftSyncStateRepository(env.db);
      expect(await syncState.linkedClinicId(), testClinicId);
      expect(await syncState.read(SyncStateKeys.deviceId), testDeviceId);
      // The engine now runs for real.
      expect(env.container.read(syncEngineProvider), isA<SupabaseSyncEngine>());
    },
  );

  test(
    'remote membership, empty device: adopts, pulls, skips onboarding',
    () async {
      await seedRemoteClinic(
        fake,
        clinic: remoteClinic(testClinicId, name: 'Smile Dental'),
        owner: remoteOwner(testDentistId, testClinicId),
      );
      final env = await openCloudEnv(fake, withClinic: false);
      addTearDown(env.close);
      expect(env.container.read(appSessionProvider).hasClinic, isFalse);

      await signIn(env.container, fake);
      final state = await runLink(env.container);

      expect(state.phase, LinkPhase.linked, reason: state.error);
      expect(state.link!.mode, ClinicLinkMode.adoptedRemote);
      final session = env.container.read(appSessionProvider);
      expect(session.clinicId, testClinicId);
      expect(session.memberId, testDentistId);
      final clinic = await env.repos.clinics.getClinic(testClinicId);
      expect(clinic?.name, 'Smile Dental');
      expect(await env.repos.clinics.members(testClinicId), hasLength(1));
      // Another device created the clinic, so this one is not primary.
      expect(fake.row('devices', testDeviceId)!['is_primary'], isFalse);
      expect(state.pulledRows, greaterThan(0));
    },
  );

  test('membership in another clinic than the local one: asks', () async {
    await seedRemoteClinic(
      fake,
      clinic: remoteClinic('clinic-remote'),
      owner: remoteOwner('member-remote', 'clinic-remote'),
    );
    final env = await openCloudEnv(fake, withPatient: true);
    addTearDown(env.close);
    await signIn(env.container, fake);
    final asked = await runLink(env.container);

    expect(asked.phase, LinkPhase.choosing);
    expect(asked.hasLocalClinic, isTrue);
    expect(asked.memberships.single.clinicId, 'clinic-remote');
    expect(fake.rows('clinics'), hasLength(1), reason: 'nothing pushed');
    expect(env.container.read(syncEngineProvider), isA<NoopSyncEngine>());

    // Replace: the local store is discarded and the remote clinic adopted.
    await env.container
        .read(clinicLinkProvider.notifier)
        .replaceLocalWith(asked.memberships.single);
    final state = await waitForLink(env.container);
    expect(state.phase, LinkPhase.linked, reason: state.error);
    final session = env.container.read(appSessionProvider);
    expect(session.clinicId, 'clinic-remote');
    expect(session.memberId, 'member-remote');
    expect(await listLocalClinics(env.db), hasLength(1));
    expect(await env.repos.clinics.getClinic(testClinicId), isNull);
    expect(await env.repos.patients.getById(testPatientId), isNull);
    // The global catalogue is re-seeded after the wipe.
    expect(
      await env.repos.catalog.byCode('clinic-remote', 'SCALING-ADULT'),
      isNotNull,
    );
  });

  test('conflict: keep the local clinic signs out and links nothing', () async {
    await seedRemoteClinic(
      fake,
      clinic: remoteClinic('clinic-remote'),
      owner: remoteOwner('member-remote', 'clinic-remote'),
    );
    final env = await openCloudEnv(fake);
    addTearDown(env.close);
    await signIn(env.container, fake);
    expect((await runLink(env.container)).phase, LinkPhase.choosing);

    await env.container.read(clinicLinkProvider.notifier).keepLocalAndSignOut();
    expect(env.container.read(cloudAuthProvider).isSignedIn, isFalse);
    expect(env.container.read(clinicLinkProvider).phase, LinkPhase.idle);
    expect(await DriftSyncStateRepository(env.db).linkedClinicId(), isNull);
    expect(await env.repos.clinics.getClinic(testClinicId), isNotNull);
  });

  test(
    'membership in the same clinic as the local one: links without pushing',
    () async {
      fake.seed('clinic_members', {
        'id': testDentistId,
        'clinic_id': testClinicId,
        'user_id': fake.userId,
        'role': 'ownerDentist',
        'display_name': 'Dr. A. Rao',
        'is_active': true,
      });
      final env = await openCloudEnv(fake);
      addTearDown(env.close);
      await signIn(env.container, fake);
      final state = await runLink(env.container);

      expect(state.phase, LinkPhase.linked, reason: state.error);
      expect(fake.callsTo('clinics', method: 'POST'), isEmpty);
      expect(fake.row('devices', testDeviceId), isNotNull);
    },
  );

  test(
    'signed in with nothing anywhere: unlinked, onboarding then pushes',
    () async {
      final env = await openCloudEnv(fake, withClinic: false);
      addTearDown(env.close);
      await signIn(env.container, fake);
      expect((await runLink(env.container)).phase, LinkPhase.unlinked);
      expect(env.container.read(signInGateProvider), isFalse);

      // Onboarding creates the clinic; the controller then pushes it.
      await env.repos.clinics.createClinic(testCtx, testClinic());
      await env.repos.clinics.upsertMember(testCtx, testDentist());
      await env.container
          .read(appSessionProvider.notifier)
          .activate(
            clinics: env.repos.clinics,
            clinicId: testClinicId,
            memberId: testDentistId,
          );
      await env.container.read(clinicLinkProvider.notifier).afterOnboarding();
      final state = await waitForLink(env.container);
      expect(state.phase, LinkPhase.linked, reason: state.error);
      expect(fake.row('clinics', testClinicId), isNotNull);
    },
  );

  test(
    'a server failure is reported, never thrown, and can be retried',
    () async {
      final env = await openCloudEnv(fake);
      addTearDown(env.close);
      await signIn(env.container, fake);
      // 403, not 5xx: the PostgREST client retries 5xx with real delays.
      fake.failAllWith = 403;
      final failed = await runLink(env.container);
      expect(failed.phase, LinkPhase.failed);
      expect(failed.error, isNotNull);
      expect(failed.error, isNot(contains('Smile')), reason: 'no row contents');

      fake.failAllWith = null;
      final state = await runLink(env.container);
      expect(state.phase, LinkPhase.linked, reason: state.error);
    },
  );
}
