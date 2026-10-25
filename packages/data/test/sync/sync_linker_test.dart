import 'package:ampdent_data/ampdent_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sync_helpers.dart';

void main() {
  group('linker', () {
    test('lists the memberships of the signed-in user', () async {
      final s = await SyncTestEnv.open(link: false, withPatient: false);
      addTearDown(s.close);
      s.fake.seed('clinic_members', {
        'id': 'm-1',
        'clinic_id': 'c-1',
        'user_id': 'user-1',
        'role': 'ownerDentist',
        'display_name': 'Dr. A',
        'is_active': true,
      });
      s.fake.seed('clinic_members', {
        'id': 'm-2',
        'clinic_id': 'c-2',
        'user_id': 'user-1',
        'role': 'associateDentist',
        'display_name': 'Dr. A',
        'is_active': false,
      });
      s.fake.seed('clinic_members', {
        'id': 'm-3',
        'clinic_id': 'c-3',
        'user_id': 'user-2',
        'role': 'ownerDentist',
        'display_name': 'Dr. B',
        'is_active': true,
      });
      final linker = RemoteClinicLinker(client: s.client, db: s.db);
      final list = await linker.listMemberships('user-1');
      expect(list, hasLength(1));
      expect(list.single.clinicId, 'c-1');
      expect(list.single.memberId, 'm-1');
      expect(list.single.role, 'ownerDentist');
      final req = s.fake.requestsFor('clinic_members', method: 'GET').single;
      expect(req.query['user_id'], 'eq.user-1');
      expect(req.query['is_active'], 'eq.true');
      expect(await linker.currentLink(), isNull);
    });

    test('first device pushes the local clinic and owner member', () async {
      final s = await SyncTestEnv.open(link: false, withPatient: false);
      addTearDown(s.close);
      final linker = RemoteClinicLinker(client: s.client, db: s.db);
      final link = await linker.pushLocalClinic(
        localClinicId: clinicId,
        ownerMemberId: dentistId,
        userId: 'user-1',
      );
      expect(link.clinicId, clinicId);
      expect(link.memberId, dentistId);
      expect(link.mode, ClinicLinkMode.pushedLocal);
      final posts = s.fake.requests.where((r) => r.method == 'POST').toList();
      expect(posts.map((r) => r.table), ['clinics', 'clinic_members']);
      final clinicRow = posts.first.rows.single;
      expect(clinicRow['name'], 'Smile Dental');
      expect(clinicRow.containsKey('created_by'), isFalse);
      expect(clinicRow.containsKey('updated_at'), isFalse);
      final member = posts.last.rows.single;
      expect(member['user_id'], 'user-1');
      expect(member['role'], 'ownerDentist');
      expect(member['registration_number'], 'A-12345');
      expect(await s.state.linkedClinicId(), clinicId);
      final stored = (await linker.currentLink())!;
      expect(stored.memberId, dentistId);
      // The engine now runs; the outbox replay of the same rows is harmless.
      final engine = s.engine();
      await engine.pushPending();
      expect(engine.current.status, SyncStatus.idle);
      expect(s.fake.row('clinic_members', dentistId)!['user_id'], 'user-1');
    });

    test('re-linking an existing membership only records the link', () async {
      final s = await SyncTestEnv.open(link: false, withPatient: false);
      addTearDown(s.close);
      s.fake.seed('clinic_members', {
        'id': dentistId,
        'clinic_id': clinicId,
        'user_id': 'user-1',
        'role': 'ownerDentist',
        'display_name': 'Dr. A. Rao',
        'is_active': true,
      });
      final linker = RemoteClinicLinker(client: s.client, db: s.db);
      await linker.pushLocalClinic(
        localClinicId: clinicId,
        ownerMemberId: dentistId,
        userId: 'user-1',
      );
      expect(s.fake.requests.where((r) => r.method == 'POST'), isEmpty);
      expect(await s.state.linkedClinicId(), clinicId);
    });

    test('refuses to push when the user belongs to another clinic', () async {
      final s = await SyncTestEnv.open(link: false, withPatient: false);
      addTearDown(s.close);
      s.fake.seed('clinic_members', {
        'id': 'm-9',
        'clinic_id': 'other',
        'user_id': 'user-1',
        'role': 'ownerDentist',
        'display_name': 'Dr. A',
        'is_active': true,
      });
      final linker = RemoteClinicLinker(client: s.client, db: s.db);
      await expectLater(
        linker.pushLocalClinic(
          localClinicId: clinicId,
          ownerMemberId: dentistId,
          userId: 'user-1',
        ),
        throwsStateError,
      );
      expect(await s.state.linkedClinicId(), isNull);
    });

    test('second device adopts a remote clinic only when empty', () async {
      final withData = await SyncTestEnv.open(link: false, withPatient: false);
      addTearDown(withData.close);
      const membership = RemoteMembership(
        clinicId: 'remote-clinic',
        memberId: 'remote-member',
        role: 'associateDentist',
        displayName: 'Dr. C',
      );
      final linker = RemoteClinicLinker(
        client: withData.client,
        db: withData.db,
      );
      await expectLater(linker.adoptRemoteClinic(membership), throwsStateError);
      expect(await withData.state.linkedClinicId(), isNull);

      final empty = AppDatabase.inMemory();
      addTearDown(empty.close);
      final emptyLinker = RemoteClinicLinker(
        client: withData.client,
        db: empty,
      );
      final link = await emptyLinker.adoptRemoteClinic(membership);
      expect(link.mode, ClinicLinkMode.adoptedRemote);
      expect(link.clinicId, 'remote-clinic');
      final stored = await DriftSyncStateRepository(empty).linkedClinicId();
      expect(stored, 'remote-clinic');
      expect((await emptyLinker.currentLink())!.memberId, 'remote-member');
    });
  });
}
