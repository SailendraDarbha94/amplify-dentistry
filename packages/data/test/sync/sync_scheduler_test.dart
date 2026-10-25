import 'dart:async';

import 'package:ampdent_data/ampdent_data.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records push/pull calls; optionally slow.
class RecordingEngine implements SyncEngine {
  final List<String> calls = [];
  Duration latency = Duration.zero;
  SyncState _current = const SyncState();
  final StreamController<SyncState> _controller =
      StreamController<SyncState>.broadcast();

  @override
  SyncState get current => _current;

  @override
  Stream<SyncState> get state => _controller.stream;

  @override
  Future<void> pushPending() async {
    calls.add('push');
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    _current = _current.copyWith(status: SyncStatus.idle);
  }

  @override
  Future<void> pullSince(DateTime? since) async {
    calls.add('pull');
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  @override
  Future<void> dispose() => _controller.close();
}

void main() {
  late RecordingEngine engine;
  late StreamController<int> pending;
  String? token = 'token';

  SyncScheduler scheduler({Duration? debounce, Duration? interval}) =>
      SyncScheduler(
        engine: engine,
        pendingCount: pending.stream,
        accessTokenProvider: () async => token,
        debounce: debounce ?? const Duration(seconds: 5),
        interval: interval ?? const Duration(minutes: 5),
      );

  setUp(() {
    engine = RecordingEngine();
    pending = StreamController<int>.broadcast();
    token = 'token';
  });

  group('scheduler', () {
    test('debounces outbox growth into one run after 5 s', () {
      fakeAsync((async) {
        final sch = scheduler()..start();
        pending.add(1);
        async.elapse(const Duration(seconds: 2));
        pending.add(2);
        async.elapse(const Duration(seconds: 2));
        pending.add(3);
        async.elapse(const Duration(seconds: 4));
        expect(sch.runs, 0, reason: 'timer restarted by each write');
        async.elapse(const Duration(seconds: 2));
        expect(sch.runs, 1);
        expect(engine.calls, ['push', 'pull']);
        // A shrinking count (acks) does not schedule a run.
        pending.add(0);
        async.elapse(const Duration(seconds: 10));
        expect(sch.runs, 1);
        sch.dispose();
      });
    });

    test('runs on the interval', () {
      fakeAsync((async) {
        final sch = scheduler(interval: const Duration(minutes: 5))..start();
        async.elapse(const Duration(minutes: 4, seconds: 59));
        expect(sch.runs, 0);
        async.elapse(const Duration(seconds: 1));
        expect(sch.runs, 1);
        async.elapse(const Duration(minutes: 10));
        expect(sch.runs, 3);
        sch.dispose();
      });
    });

    test('pauses while there is no access token', () {
      fakeAsync((async) {
        token = null;
        final sch = scheduler()..start();
        pending.add(1);
        async.elapse(const Duration(minutes: 6));
        expect(sch.runs, 0);
        expect(engine.calls, isEmpty);
        token = 'token';
        sch.onAppResumed();
        async.flushMicrotasks();
        expect(sch.runs, 1);
        sch.dispose();
      });
    });

    test('syncNow runs immediately and awaits completion', () {
      fakeAsync((async) {
        engine.latency = const Duration(seconds: 3);
        final sch = scheduler()..start();
        var done = false;
        sch.syncNow().then((_) => done = true);
        async.elapse(const Duration(seconds: 1));
        expect(sch.isRunning, isTrue);
        expect(done, isFalse);
        async.elapse(const Duration(seconds: 6));
        expect(done, isTrue);
        expect(engine.calls, ['push', 'pull']);
        sch.dispose();
      });
    });

    test('connectivity: offline suppresses, online triggers once', () {
      fakeAsync((async) {
        final sch = scheduler()..start();
        sch.onConnectivityChanged(online: false);
        pending.add(1);
        async.elapse(const Duration(minutes: 6));
        expect(sch.runs, 0);
        sch.onConnectivityChanged(online: true);
        async.flushMicrotasks();
        expect(sch.runs, 1);
        sch.onConnectivityChanged(online: true);
        async.flushMicrotasks();
        expect(sch.runs, 1, reason: 'already online: no extra run');
        sch.dispose();
      });
    });

    test('triggers during a run coalesce into one follow-up run', () {
      fakeAsync((async) {
        engine.latency = const Duration(seconds: 2);
        final sch = scheduler()..start();
        sch.onAppResumed();
        async.flushMicrotasks();
        expect(sch.isRunning, isTrue);
        sch.onAppResumed();
        sch.onAppResumed();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 10));
        expect(sch.runs, 2);
        expect(engine.calls, ['push', 'pull', 'push', 'pull']);
        sch.dispose();
      });
    });

    test('pause and resume', () {
      fakeAsync((async) {
        final sch = scheduler()..start();
        sch.pause();
        pending.add(1);
        async.elapse(const Duration(minutes: 6));
        expect(sch.runs, 0);
        sch.resume();
        async.flushMicrotasks();
        expect(sch.runs, 1);
        sch.dispose();
      });
    });
  });
}
