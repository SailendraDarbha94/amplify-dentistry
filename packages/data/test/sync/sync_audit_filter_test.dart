import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
// ignore: implementation_imports
import 'package:ampdent_data/src/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sync_helpers.dart';

void main() {
  late SyncTestEnv s;

  setUp(() async => s = await SyncTestEnv.open(withPatient: false));
  tearDown(() => s.close());

  AuditEvent event(String id, {required String deviceId, String? actorId}) =>
      AuditEvent(
        id: id,
        clinicId: clinicId,
        actorId: actorId ?? '00000000-0000-0000-0000-000000000000',
        action: AuditAction.update,
        entityType: 'Patient',
        entityId: 'p-1',
        deviceId: deviceId,
        occurredAt: t1,
      );

  group('audit pull', () {
    test('skips server-authored events by default', () async {
      s.fake.seed(
        'audit_events',
        s.serverRow(
          'audit_events',
          event(
            'a-phone',
            deviceId: 'device-2',
            actorId: 'member-2',
          ).toInsertable(),
        ),
      );
      s.fake.seed(
        'audit_events',
        s.serverRow(
          'audit_events',
          event('a-server', deviceId: 'server').toInsertable(),
        ),
      );
      // The server's own trigger rows carry the nil actor; PostgREST would
      // send `actor_id: null` for a nullable actor, which is skipped too.
      s.fake.seed('audit_events', {
        ...s.serverRow(
          'audit_events',
          event('a-null-actor', deviceId: 'device-3').toInsertable(),
        ),
        'actor_id': null,
      });
      expect(syncTablesByName['audit_events']!.skipServerAuthored, isTrue);

      final engine = s.engine();
      await engine.pullSince(null);
      final get = s.fake.requestsFor('audit_events', method: 'GET').single;
      expect(get.query['device_id'], 'neq.server');
      expect(get.query['actor_id'], 'not.is.null');
      final ids = (await s.db.select(s.db.auditEvents).get())
          .map((e) => e.id)
          .toSet();
      expect(ids, contains('a-phone'));
      expect(ids, isNot(contains('a-server')));
      expect(ids, isNot(contains('a-null-actor')));
    });

    test('includeServerAudit pulls everything', () async {
      s.fake.seed(
        'audit_events',
        s.serverRow(
          'audit_events',
          event(
            'a-phone',
            deviceId: 'device-2',
            actorId: 'member-2',
          ).toInsertable(),
        ),
      );
      s.fake.seed(
        'audit_events',
        s.serverRow(
          'audit_events',
          event('a-server', deviceId: 'server').toInsertable(),
        ),
      );
      final engine = SupabaseSyncEngine(
        client: s.client,
        db: s.db,
        clinicId: clinicId,
        accessTokenProvider: () async => s.token,
        includeServerAudit: true,
      );
      await engine.pullSince(null);
      final get = s.fake.requestsFor('audit_events', method: 'GET').single;
      expect(get.query.containsKey('device_id'), isFalse);
      final ids = (await s.db.select(s.db.auditEvents).get())
          .map((e) => e.id)
          .toSet();
      expect(ids, containsAll(['a-phone', 'a-server']));
      await engine.dispose();
    });
  });

  group('AuditRepository.watchRecent', () {
    test('hides server events unless includeServer', () async {
      await s.db
          .into(s.db.auditEvents)
          .insert(event('local-server', deviceId: 'server').toInsertable());
      final own = await s.repos.audit.watchRecent(clinicId).first;
      expect(own.map((e) => e.id), isNot(contains('local-server')));
      expect(own.map((e) => e.deviceId).toSet(), {deviceId});
      final all = await s.repos.audit
          .watchRecent(clinicId, includeServer: true)
          .first;
      expect(all.map((e) => e.id), contains('local-server'));
      expect(all.length, own.length + 1);
    });
  });

  group('AuditRepository.inRange', () {
    test('hides server events unless includeServer', () async {
      await s.db
          .into(s.db.auditEvents)
          .insert(event('local-server', deviceId: 'server').toInsertable());
      await s.db
          .into(s.db.auditEvents)
          .insert(event('local-phone', deviceId: deviceId).toInsertable());
      final from = t1.subtract(const Duration(days: 1));
      final to = t1.add(const Duration(days: 1));
      final own = await s.repos.audit.inRange(clinicId, from, to);
      expect(own.map((e) => e.id), contains('local-phone'));
      expect(own.map((e) => e.id), isNot(contains('local-server')));
      expect(own.map((e) => e.deviceId).toSet(), {deviceId});
      final all = await s.repos.audit.inRange(
        clinicId,
        from,
        to,
        includeServer: true,
      );
      expect(all.map((e) => e.id), contains('local-server'));
      expect(all.length, own.length + 1);
      // The window still applies with the flag on.
      final none = await s.repos.audit.inRange(
        clinicId,
        to,
        to.add(const Duration(days: 1)),
        includeServer: true,
      );
      expect(none, isEmpty);
    });
  });
}
