/// Decides when the sync engine runs: on demand, after local writes
/// (debounced), on an interval, and when the app reports connectivity or
/// resume. No connectivity plugin here; the app calls the hooks.
library;

import 'dart:async';

import 'package:ampdent_core/ampdent_core.dart';

import 'reachability.dart';
import 'supabase_sync_engine.dart';
import 'sync_engine.dart';

/// Drives a [SyncEngine].
class SyncScheduler {
  /// Creates the scheduler. [pendingCount] is usually
  /// `OutboxRepository.watchPendingCount(clinicId)`; [accessTokenProvider]
  /// returning null pauses every automatic run.
  SyncScheduler({
    required this.engine,
    required this.pendingCount,
    required this.accessTokenProvider,
    this.debounce = const Duration(seconds: 5),
    this.interval = const Duration(minutes: 5),
    this.reachability,
  });

  static const Logger _log = Logger('SyncScheduler');

  /// Engine to run.
  final SyncEngine engine;

  /// Pauses automatic runs while it returns null.
  final AccessTokenProvider accessTokenProvider;

  /// Quiet period after the last local write before a run.
  final Duration debounce;

  /// Period of the background run.
  final Duration interval;

  /// Server probe behind [probeReachability]; null leaves connectivity to
  /// the app's own [onConnectivityChanged] calls.
  final Reachability? reachability;

  /// Pending outbox count; a growth restarts the debounce timer.
  final Stream<int> pendingCount;
  StreamSubscription<int>? _pendingSub;
  Timer? _debounceTimer;
  Timer? _intervalTimer;
  int _lastPending = 0;
  bool _started = false;
  bool _online = true;
  bool _paused = false;
  Future<void>? _running;
  bool _rerun = false;

  /// Runs so far (for tests and diagnostics).
  int runs = 0;

  /// Whether a run is in flight.
  bool get isRunning => _running != null;

  /// Whether the app reported the device offline.
  bool get isOnline => _online;

  /// Starts listening to the outbox and the interval timer.
  void start() {
    if (_started) return;
    _started = true;
    _pendingSub = pendingCount.listen(_onPendingCount);
    _intervalTimer = Timer.periodic(interval, (_) => _trigger('interval'));
  }

  void _onPendingCount(int n) {
    final grew = n > _lastPending;
    _lastPending = n;
    if (!grew) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () => _trigger('outbox'));
  }

  /// App hook: connectivity changed. Going online triggers a run; offline
  /// stops automatic runs until online again.
  void onConnectivityChanged({required bool online}) {
    final wasOnline = _online;
    _online = online;
    if (online && !wasOnline) _trigger('connectivity');
  }

  /// App hook: the app came to the foreground.
  void onAppResumed() => _trigger('resume');

  /// Probes the server with [reachability] and feeds the answer to
  /// [onConnectivityChanged] (so a device that just came back online runs
  /// once, and an unreachable one stops its automatic runs). The app calls
  /// this on resume and on a timer. Returns the probe result.
  ///
  /// Without a configured probe the run itself is the probe: an engine
  /// that last reported `offline` is given one run (a success flips the
  /// state back and drains the outbox), and the current flag is returned.
  Future<bool> probeReachability() async {
    final probe = reachability;
    if (probe == null) {
      if (engine.current.status == SyncStatus.offline) {
        await _trigger('probe');
      }
      return _online;
    }
    final online = await probe.probe();
    _log.debug('reachability: ${online ? 'online' : 'offline'}');
    onConnectivityChanged(online: online);
    return online;
  }

  /// Stops automatic runs (sign-out, settings toggle).
  void pause() => _paused = true;

  /// Resumes automatic runs and triggers one.
  void resume() {
    _paused = false;
    _trigger('resume');
  }

  /// Runs push and pull now, regardless of pause or connectivity flags
  /// (the engine still checks the token). Awaits completion.
  Future<void> syncNow() => _run('manual');

  Future<void> _trigger(String reason) async {
    if (_paused || !_online) return;
    if (await accessTokenProvider() == null) {
      _log.debug('skip $reason: signed out');
      return;
    }
    await _run(reason);
  }

  Future<void> _run(String reason) {
    final inFlight = _running;
    if (inFlight != null) {
      _rerun = true;
      return inFlight;
    }
    final completer = Completer<void>();
    _running = completer.future;
    unawaited(
      _loop(reason).whenComplete(() {
        _running = null;
        completer.complete();
      }),
    );
    return completer.future;
  }

  Future<void> _loop(String reason) async {
    do {
      _rerun = false;
      runs++;
      _log.debug('run ($reason)');
      try {
        final e = engine;
        if (e is SupabaseSyncEngine) {
          await e.syncNow();
        } else {
          await e.pushPending();
          await e.pullSince(null);
        }
      } catch (e) {
        _log.warning('run failed: ${e.runtimeType}');
      }
    } while (_rerun);
  }

  /// Cancels timers and subscriptions.
  Future<void> dispose() async {
    _debounceTimer?.cancel();
    _intervalTimer?.cancel();
    await _pendingSub?.cancel();
  }
}
