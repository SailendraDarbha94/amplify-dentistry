/// Shared helpers for the cloud tests: an [AppTestEnv] bound to a
/// [FakeSupabase], sign-in and link helpers, remote fixtures and a scan of
/// the local store for a secret.
library;

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_mobile/core/clinic_link.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/features/recall/patient_messenger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_env.dart';
import 'fake_supabase.dart';

export '../helpers/test_env.dart';
export 'fake_supabase.dart';

/// Opens an [AppTestEnv] whose cloud is [fake]; the deep-link launcher is
/// replaced by one that records URIs in [launched].
Future<AppTestEnv> openCloudEnv(
  FakeSupabase fake, {
  bool withClinic = true,
  bool withPatient = false,
  List<Uri>? launched,
}) => AppTestEnv.open(
  withClinic: withClinic,
  withPatient: withPatient,
  cloudClient: fake.client(),
  overrides: [
    if (launched != null)
      linkLauncherProvider.overrideWithValue((uri) async {
        launched.add(uri);
        return true;
      }),
  ],
);

/// Signs in with the fake's email and password.
Future<void> signIn(ProviderContainer container, FakeSupabase fake) => container
    .read(cloudAuthProvider.notifier)
    .signInWithPassword(email: fake.email, password: fake.password);

/// Runs the link flow once (it completes, adopt pull included, before the
/// future resolves) and returns the resulting state. No timers: this also
/// runs inside `testWidgets`' fake async zone.
Future<ClinicLinkState> runLink(ProviderContainer container) async {
  await container.read(clinicLinkProvider.notifier).run();
  return waitForLink(container);
}

/// The link state after an awaited controller call.
Future<ClinicLinkState> waitForLink(ProviderContainer container) async {
  final state = container.read(clinicLinkProvider);
  if (state.isBusy) fail('link flow still busy: ${state.phase}');
  return state;
}

/// A clinic with [id] (fixtures for the server side).
Clinic remoteClinic(String id, {String name = 'Remote Dental'}) {
  final t = DateTime.utc(2026, 9, 1);
  return Clinic(
    id: id,
    name: name,
    city: 'Vijayawada',
    stateCode: '37',
    pincode: '520001',
    phone: '+919000000009',
    createdAt: t,
    updatedAt: t,
  );
}

/// An owner member of [clinicId].
ClinicMember remoteOwner(String id, String clinicId) {
  final t = DateTime.utc(2026, 9, 1);
  return ClinicMember(
    id: id,
    clinicId: clinicId,
    displayName: 'Dr. R. Remote',
    role: ClinicRole.ownerDentist,
    registrationNumber: 'B-99999',
    registrationCouncil: 'Andhra Pradesh State Dental Council',
    phone: '+919000000002',
    createdAt: t,
    updatedAt: t,
  );
}

/// Builds a scratch database holding [clinic] and [owner] (written by the
/// device [deviceId]) and copies it to [fake] with [owner] bound to
/// [fake.userId].
Future<void> seedRemoteClinic(
  FakeSupabase fake, {
  required Clinic clinic,
  required ClinicMember owner,
  String deviceId = 'device-other',
}) async {
  final scratch = AppDatabase.inMemory(seedOnOpen: false);
  try {
    final repos = DriftRepositories(scratch);
    final ctx = ActorContext(
      clinicId: clinic.id,
      actorId: owner.id,
      deviceId: deviceId,
    );
    await repos.clinics.createClinic(ctx, clinic);
    await repos.clinics.upsertMember(ctx, owner);
    await fake.seedFromDatabase(
      scratch,
      memberUserIds: {owner.id: fake.userId},
    );
  } finally {
    await scratch.close();
  }
}

/// Every table and column of [db] that contains [secret].
Future<List<String>> findSecretInStore(AppDatabase db, String secret) async {
  final hits = <String>[];
  for (final table in db.allTables) {
    final name = table.actualTableName;
    final rows = await db.customSelect('SELECT * FROM "$name"').get();
    for (final row in rows) {
      for (final e in row.data.entries) {
        if ('${e.value}'.contains(secret)) hits.add('$name.${e.key}');
      }
    }
  }
  return hits;
}
