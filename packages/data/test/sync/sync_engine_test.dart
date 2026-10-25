import 'package:ampdent_data/ampdent_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sync_helpers.dart';

void main() {
  late SyncTestEnv s;

  setUp(() async => s = await SyncTestEnv.open());
  tearDown(() => s.close());

  group('engine', () {
    test('does nothing while signed out', () async {
      s.token = null;
      final engine = s.engine();
      await engine.pushPending();
      await engine.pullSince(null);
      expect(engine.current.status, SyncStatus.offline);
      expect(engine.current.error, 'signed out');
      expect(s.fake.requests, isEmpty);
      expect(await s.pendingCount(), greaterThan(0));
    });

    test('refuses to sync before the device is linked', () async {
      await s.state.write(SyncStateKeys.linkedClinicId, null);
      final engine = s.engine();
      await engine.syncNow();
      expect(engine.current.status, SyncStatus.error);
      expect(engine.current.error, contains('not linked'));
      expect(s.fake.requests, isEmpty);
    });

    test('a link to another clinic also blocks', () async {
      await s.state.write(SyncStateKeys.linkedClinicId, 'other-clinic');
      final engine = s.engine();
      await engine.pushPending();
      expect(engine.current.status, SyncStatus.error);
      expect(s.fake.requests, isEmpty);
    });

    test('state stream emits current first, then transitions', () async {
      final engine = s.engine();
      final seen = <SyncStatus>[];
      final sub = engine.state.listen((st) => seen.add(st.status));
      await Future<void>.delayed(Duration.zero);
      await engine.pushPending();
      await engine.pullSince(null);
      // Broadcast delivery is asynchronous; let the last event arrive.
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(seen.first, SyncStatus.idle);
      expect(
        seen,
        containsAllInOrder([
          SyncStatus.pushing,
          SyncStatus.idle,
          SyncStatus.pulling,
          SyncStatus.idle,
        ]),
      );
      expect(engine.current.lastPushedAt, isNotNull);
      expect(engine.current.lastPulledAt, isNotNull);
      expect(engine.current.lastSyncedAt, engine.current.lastPulledAt);
      expect(engine.current.isBusy, isFalse);
      await engine.dispose();
    });

    test('mirrors the pending outbox count', () async {
      final engine = s.engine();
      final before = await s.pendingCount();
      await engine.state.firstWhere((st) => st.pendingCount == before);
      await engine.pushPending();
      await engine.state.firstWhere((st) => st.pendingCount == 0);
      expect(engine.current.pendingCount, 0);
      await engine.dispose();
    });

    test('concurrent push and pull never interleave', () async {
      s.fake.latency = const Duration(milliseconds: 5);
      final engine = s.engine();
      await Future.wait([
        engine.pullSince(null),
        engine.pushPending(),
        engine.pullSince(null),
        engine.pushPending(),
      ]);
      expect(s.fake.maxInFlight, 1);
      // Each call ran to completion before the next started: the request
      // log is a sequence of whole GET-only and POST-only blocks.
      final methods = s.fake.requests.map((r) => r.method).toList();
      var blocks = 1;
      for (var i = 1; i < methods.length; i++) {
        if (methods[i] != methods[i - 1]) blocks++;
      }
      expect(blocks, 3, reason: 'GET block, POST block, GET block');
      expect(engine.current.status, SyncStatus.idle);
      expect(await s.pendingCount(), 0);
    });

    test('syncNow pushes then pulls and persists sync times', () async {
      final engine = s.engine();
      await engine.syncNow();
      final methods = s.fake.requests.map((r) => r.method).toList();
      expect(methods.first, 'POST');
      expect(methods.last, 'GET');
      expect(await s.state.readInstant(SyncStateKeys.lastPushAt), isNotNull);
      expect(await s.state.readInstant(SyncStateKeys.lastPullAt), isNotNull);
      final fresh = s.engine();
      expect(fresh.current.lastPushedAt, isNull);
      await fresh.restoreLastSyncTimes();
      expect(fresh.current.lastPushedAt, engine.current.lastPushedAt);
      await fresh.dispose();
      await engine.dispose();
    });

    test('syncNow skips the pull when the push failed', () async {
      s.fake.failNext.addAll([500, 500, 500]);
      final engine = s.engine();
      await engine.syncNow();
      expect(engine.current.status, SyncStatus.offline);
      expect(s.fake.requests.every((r) => r.method == 'POST'), isTrue);
    });

    test('a device id is minted once', () async {
      final a = await s.state.ensureDeviceId();
      final b = await s.state.ensureDeviceId();
      expect(a, b);
      expect(a, hasLength(36));
    });
  });
}
