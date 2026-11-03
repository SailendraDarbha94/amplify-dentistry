import 'package:ampdent_data/ampdent_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sync_helpers.dart';

void main() {
  late SyncTestEnv s;
  late DateTime now;

  setUp(() async {
    s = await SyncTestEnv.open();
    now = DateTime.utc(2026, 11, 3, 9);
  });
  tearDown(() => s.close());

  const info = DeviceInfo(appVersion: '1.2.0+45', platform: DevicePlatform.ios);

  SupabaseSyncEngine engine({DeviceInfo? deviceInfo = info}) =>
      SupabaseSyncEngine(
        client: s.client,
        db: s.db,
        clinicId: clinicId,
        accessTokenProvider: () async => s.token,
        clock: () => now,
        deviceInfo: deviceInfo,
        backoff: const BackoffPolicy(maxAttempts: 3),
        sleep: (d) async => s.sleeps.add(d),
      );

  group('device heartbeat', () {
    test('upserts the devices row once per 15 minutes on push', () async {
      final e = engine();
      await e.pushPending();
      await e.pushPending();
      final reqs = s.fake.requestsFor('devices');
      expect(reqs, hasLength(1));
      expect(reqs.single.method, 'POST');
      expect(reqs.single.query['on_conflict'], 'id');
      final row = reqs.single.rows.single;
      expect(row['id'], await s.state.ensureDeviceId());
      expect(row['clinic_id'], clinicId);
      expect(row['platform'], 'ios');
      expect(row['app_version'], '1.2.0+45');
      expect(row['last_seen_at'], now.toIso8601String());
      expect(row.containsKey('user_id'), isFalse, reason: 'server default');
      expect(e.heartbeats, 1);
      expect(await s.state.readInstant(SyncStateKeys.lastHeartbeatAt), now);

      now = now.add(const Duration(minutes: 14));
      await e.pushPending();
      expect(s.fake.requestsFor('devices'), hasLength(1));
      now = now.add(const Duration(minutes: 2));
      await e.pushPending();
      expect(s.fake.requestsFor('devices'), hasLength(2));
      expect(
        s.fake.requestsFor('devices').last.rows.single['last_seen_at'],
        now.toIso8601String(),
      );
      expect(s.fake.rows('devices'), hasLength(1));
      await e.dispose();
    });

    test('the last heartbeat time survives a restart', () async {
      await engine().pushPending();
      now = now.add(const Duration(minutes: 5));
      await engine().pushPending();
      expect(s.fake.requestsFor('devices'), hasLength(1));
    });

    test('runs after the push, not while signed out or unlinked', () async {
      s.token = null;
      await engine().pushPending();
      expect(s.fake.requestsFor('devices'), isEmpty);
      s.token = 'test-access-token';
      s.fake.failNext.addAll([500, 500, 500]);
      final e = engine();
      await e.pushPending();
      expect(e.current.status, SyncStatus.offline);
      expect(s.fake.requestsFor('devices'), isEmpty);
    });

    test('a failed heartbeat never fails the push', () async {
      s.fake.rejectTables['devices'] = 403;
      final e = engine();
      await e.pushPending();
      expect(e.current.status, SyncStatus.idle);
      expect(e.heartbeats, 0);
      expect(await s.pendingCount(), 0);
      // Retried on the next push (nothing recorded).
      s.fake.rejectTables.clear();
      await s.repos.patients.upsert(ctx, patient(firstName: 'Again'));
      await e.pushPending();
      expect(e.heartbeats, 1);
    });

    test('no device info, no heartbeat', () async {
      await engine(deviceInfo: null).pushPending();
      expect(s.fake.requestsFor('devices'), isEmpty);
    });

    test('DeviceInfo maps to the devices columns and compares by value', () {
      expect(info.toJson(), {'platform': 'ios', 'app_version': '1.2.0+45'});
      expect(
        info,
        const DeviceInfo(appVersion: '1.2.0+45', platform: DevicePlatform.ios),
      );
      const other = DeviceInfo(appVersion: '1', platform: DevicePlatform.other);
      expect(other.toJson()['platform'], 'other');
      expect(info.hashCode, isNot(other.hashCode));
      expect('$info', 'DeviceInfo(ios 1.2.0+45)');
    });
  });
}
