import 'dart:async';

import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_mobile/core/app_shell.dart';
import 'package:ampdent_mobile/core/formatting.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/core/sync_banner.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/test_env.dart';

/// A scripted engine: tests push states and watch what the shell shows.
class FakeSyncEngine implements SyncEngine {
  FakeSyncEngine() {
    _controller = StreamController<SyncState>.broadcast(
      onListen: () => _controller.add(_current),
    );
  }

  late final StreamController<SyncState> _controller;
  SyncState _current = const SyncState();
  int pushes = 0;
  int pulls = 0;

  void emit(SyncState state) {
    _current = state;
    _controller.add(state);
  }

  @override
  SyncState get current => _current;

  @override
  Stream<SyncState> get state => _controller.stream;

  @override
  Future<void> pushPending() async => pushes++;

  @override
  Future<void> pullSince(DateTime? since) async => pulls++;

  @override
  Future<void> dispose() => _controller.close();
}

void main() {
  final now = DateTime(2026, 10, 25, 9, 30);
  final strings = AppStrings.en;
  setUpAll(() => initializeDateFormatting('en_IN'));

  group('syncBannerSpec', () {
    SyncBannerSpec? spec(SyncState s) =>
        syncBannerSpec(s, strings: strings, now: now);

    test('disabled engine leaves the banner to the offline-only widget', () {
      expect(
        spec(const SyncState(status: SyncStatus.disabled, pendingCount: 3)),
        isNull,
      );
    });

    test('offline shows the count when there is one', () {
      expect(
        spec(const SyncState(status: SyncStatus.offline, pendingCount: 2))!
            .text,
        'Offline - 2 changes waiting',
      );
      final bare = spec(const SyncState(status: SyncStatus.offline))!;
      expect(bare.text, 'Offline');
      expect(bare.kind, SyncBannerKind.offline);
      expect(bare.canRetry, isFalse);
    });

    test('syncing, waiting, error', () {
      expect(
        spec(const SyncState(status: SyncStatus.pushing, pendingCount: 1))!
            .kind,
        SyncBannerKind.syncing,
      );
      expect(
        spec(const SyncState(status: SyncStatus.pulling))!.text,
        'Syncing...',
      );
      final waiting = spec(const SyncState(pendingCount: 4))!;
      expect(waiting.kind, SyncBannerKind.waiting);
      expect(waiting.text, '4 changes waiting');
      final error = spec(
        const SyncState(
          status: SyncStatus.error,
          error: 'PostgrestException 403 on patients',
        ),
      )!;
      expect(error.kind, SyncBannerKind.error);
      expect(error.canRetry, isTrue);
      expect(error.text, contains('PostgrestException 403 on patients'));
      expect(error.text, contains('Tap to retry'));
    });

    test('synced at hh:mm only right after a run, else nothing', () {
      final recent = SyncState(
        lastPulledAt: now.subtract(const Duration(seconds: 10)),
      );
      final banner = spec(recent)!;
      expect(banner.kind, SyncBannerKind.synced);
      expect(banner.text, 'Synced at ${AppFormat.time(recent.lastSyncedAt!)}');
      expect(
        syncedBannerRemaining(recent, now),
        syncedBannerWindow - const Duration(seconds: 10),
      );
      final old = SyncState(
        lastPushedAt: now.subtract(const Duration(hours: 1)),
      );
      expect(spec(old), isNull);
      expect(syncedBannerRemaining(old, now), isNull);
      expect(spec(const SyncState()), isNull);
    });
  });

  group('shell banner with a real engine', () {
    late AppTestEnv env;
    late FakeSyncEngine engine;

    var clockNow = now;

    setUp(() async {
      engine = FakeSyncEngine();
      clockNow = now;
      env = await AppTestEnv.open(
        overrides: [
          syncEngineProvider.overrideWithValue(engine),
          clockProvider.overrideWithValue(() => clockNow),
        ],
      );
    });
    // The container goes first: it holds the subscription on the engine's
    // broadcast stream, and closing that stream waits for its listeners.
    tearDown(() async {
      await env.close();
      await engine.dispose();
    });

    Finder banner() => find.byKey(shellSyncBannerKey);

    testWidgets('shows each state, hides the synced one, retries on tap', (
      tester,
    ) async {
      await env.pumpApp(tester);
      expect(banner(), findsNothing, reason: 'idle and empty: nothing to say');

      engine.emit(const SyncState(status: SyncStatus.offline, pendingCount: 3));
      await settle(tester);
      expect(find.text('Offline - 3 changes waiting'), findsOneWidget);
      expect(find.byType(OfflineBanner), findsNothing);

      engine.emit(const SyncState(pendingCount: 3));
      await settle(tester);
      expect(find.text('3 changes waiting'), findsOneWidget);

      engine.emit(const SyncState(status: SyncStatus.pushing, pendingCount: 3));
      await settle(tester);
      expect(find.textContaining('Syncing...'), findsOneWidget);

      engine.emit(
        SyncState(lastPushedAt: now, lastPulledAt: now, pendingCount: 0),
      );
      await settle(tester);
      expect(find.text('Synced at ${AppFormat.time(now)}'), findsOneWidget);
      // Time passes: the shell's hide timer fires and the clock has moved on.
      clockNow = now.add(syncedBannerWindow + const Duration(seconds: 1));
      await tester.pump(syncedBannerWindow + const Duration(seconds: 1));
      await tester.pump();
      expect(banner(), findsNothing, reason: 'the synced banner hides itself');

      engine.emit(
        const SyncState(
          status: SyncStatus.error,
          error: 'PostgrestException 500 on patients',
          pendingCount: 1,
        ),
      );
      await settle(tester);
      expect(find.textContaining('Tap to retry'), findsOneWidget);
      await tester.tap(banner());
      await settle(tester);
      expect(engine.pushes, 1, reason: 'tap retried through the engine');
      expect(engine.pulls, 1);
    });
  });
}
