import 'dart:async';

import 'package:ampdent_data/ampdent_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Engine whose status the test sets; counts pushes.
class _StatusEngine implements SyncEngine {
  SyncStatus status = SyncStatus.idle;
  int pushes = 0;

  @override
  SyncState get current => SyncState(status: status);

  @override
  Stream<SyncState> get state => const Stream.empty();

  @override
  Future<void> pushPending() async {
    pushes++;
    status = SyncStatus.idle;
  }

  @override
  Future<void> pullSince(DateTime? since) async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  final url = Uri.parse('https://abc.supabase.co');

  Reachability probe(
    Future<http.Response> Function(http.Request) handler, {
    Duration timeout = const Duration(seconds: 3),
  }) => Reachability(
    supabaseUrl: url,
    client: MockClient(handler),
    timeout: timeout,
  );

  group('Reachability', () {
    test('targets /auth/v1/health', () {
      expect(
        Reachability.healthUrlFor(url).toString(),
        'https://abc.supabase.co/auth/v1/health',
      );
      expect(
        Reachability.healthUrlFor(Uri.parse('http://localhost:54321/'))
            .toString(),
        'http://localhost:54321/auth/v1/health',
      );
    });

    test('HEAD 200 is reachable', () async {
      final methods = <String>[];
      final r = probe((req) async {
        methods.add(req.method);
        expect(req.url.path, '/auth/v1/health');
        return http.Response('', 200);
      });
      expect(await r.probe(), isTrue);
      expect(methods, ['HEAD']);
      expect(r.lastResult, isTrue);
      expect(r.lastProbedAt, isNotNull);
    });

    test('falls back to GET when HEAD is not allowed', () async {
      final methods = <String>[];
      final r = probe((req) async {
        methods.add(req.method);
        return req.method == 'HEAD'
            ? http.Response('', 405)
            : http.Response('{"version":"v2"}', 200);
      });
      expect(await r.probe(), isTrue);
      expect(methods, ['HEAD', 'GET']);
    });

    test('a 5xx, a socket error and a timeout are unreachable', () async {
      expect(await probe((_) async => http.Response('', 503)).probe(), isFalse);
      expect(
        await probe((_) async => throw http.ClientException('down')).probe(),
        isFalse,
      );
      final slow = probe(
        (_) => Future.delayed(
          const Duration(milliseconds: 300),
          () => http.Response('', 200),
        ),
        timeout: const Duration(milliseconds: 50),
      );
      expect(await slow.probe(), isFalse);
      expect(slow.lastResult, isFalse);
    });

    test('a 401 from the gateway still means reachable', () async {
      expect(await probe((_) async => http.Response('', 401)).probe(), isTrue);
    });
  });

  group('SyncScheduler.probeReachability', () {
    test('feeds the probe into onConnectivityChanged', () async {
      var status = 503;
      final engine = NoopSyncEngine();
      final pending = StreamController<int>.broadcast();
      final sch = SyncScheduler(
        engine: engine,
        pendingCount: pending.stream,
        accessTokenProvider: () async => 'token',
        reachability: probe((_) async => http.Response('', status)),
      );
      expect(await sch.probeReachability(), isFalse);
      expect(sch.isOnline, isFalse);
      status = 200;
      expect(await sch.probeReachability(), isTrue);
      expect(sch.isOnline, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(sch.runs, 1, reason: 'coming back online triggers a run');
      expect(await sch.probeReachability(), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(sch.runs, 1, reason: 'still online: no extra run');
      await sch.dispose();
      await pending.close();
      await engine.dispose();
    });

    test(
      'without a probe it reports the flag and retries an offline engine',
      () async {
        final engine = _StatusEngine();
        final sch = SyncScheduler(
          engine: engine,
          pendingCount: const Stream.empty(),
          accessTokenProvider: () async => 'token',
        );
        expect(await sch.probeReachability(), isTrue);
        expect(engine.pushes, 0, reason: 'idle engine is left alone');
        engine.status = SyncStatus.offline;
        expect(await sch.probeReachability(), isTrue);
        expect(engine.pushes, 1, reason: 'the run is the probe');
        sch.onConnectivityChanged(online: false);
        expect(await sch.probeReachability(), isFalse);
        expect(engine.pushes, 1, reason: 'reported offline: no automatic run');
        await sch.dispose();
      },
    );
  });
}
