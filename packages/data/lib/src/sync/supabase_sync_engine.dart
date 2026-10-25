/// [SyncEngine] backed by Supabase PostgREST: outbox push, watermark pull.
library;

import 'dart:async';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:supabase/supabase.dart';

import '../db/app_database.dart';
import 'async_mutex.dart';
import 'outbox_repository.dart';
import 'sync_engine.dart';
import 'sync_errors.dart';
import 'sync_puller.dart';
import 'sync_pusher.dart';
import 'sync_state_repository.dart';

/// Returns the current access token, or null when signed out.
typedef AccessTokenProvider = Future<String?> Function();

/// Replicates one clinic's local store with a Supabase project.
///
/// * [pushPending] drains `sync_outbox` in foreign-key order as PostgREST
///   upserts (see `OutboxPusher`).
/// * [pullSince] fetches rows with `updated_at` above each table's watermark
///   and applies them under the per-table conflict policy (`TablePuller`).
/// * Push and pull share one mutex, so concurrent calls serialise.
/// * Nothing runs while [accessTokenProvider] returns null (signed out) or
///   the device is not linked to [clinicId] (`RemoteClinicLinker`).
///
/// The engine does no sign-in: the app owns auth and builds the
/// [SupabaseClient] (with `accessToken:` or Supabase auth); only
/// `client.from(...)` is used here. Logs carry table names, counts and
/// error classes, never row contents.
class SupabaseSyncEngine implements SyncEngine {
  /// Creates the engine. [sleep] and [backoff] are injectable for tests.
  SupabaseSyncEngine({
    required this.client,
    required this.db,
    required this.clinicId,
    required this.accessTokenProvider,
    OutboxRepository? outbox,
    SyncStateRepository? syncState,
    BackoffPolicy backoff = const BackoffPolicy(),
    Future<void> Function(Duration)? sleep,
    int pushBatchSize = 200,
    int pullPageSize = 1000,
    this.requireLink = true,
    DateTime Function()? clock,
  }) : outbox = outbox ?? DriftOutboxRepository(db),
       syncState = syncState ?? DriftSyncStateRepository(db),
       _clock = clock ?? _utcNow {
    _pusher = OutboxPusher(
      db: db,
      outbox: this.outbox,
      client: client,
      clinicId: clinicId,
      backoff: backoff,
      batchSize: pushBatchSize,
      sleep: sleep,
    );
    _puller = TablePuller(
      db: db,
      client: client,
      syncState: this.syncState,
      outbox: this.outbox,
      clinicId: clinicId,
      pageSize: pullPageSize,
    );
    _controller = StreamController<SyncState>.broadcast(
      onListen: () => _controller.add(_current),
    );
    _pendingSub = this.outbox.watchPendingCount(clinicId).listen((n) {
      _emit(_current.copyWith(pendingCount: n));
    });
  }

  static const Logger _log = Logger('SupabaseSyncEngine');

  static DateTime _utcNow() => DateTime.now().toUtc();

  /// Supabase client; only its REST interface is used.
  final SupabaseClient client;

  /// Local database.
  final AppDatabase db;

  /// Clinic replicated by this device.
  final String clinicId;

  /// Supplies the session token; null pauses the engine.
  final AccessTokenProvider accessTokenProvider;

  /// Outbox.
  final OutboxRepository outbox;

  /// Watermarks, device id and clinic link.
  final SyncStateRepository syncState;

  /// Whether a recorded clinic link is required before any network call.
  final bool requireLink;

  final DateTime Function() _clock;
  final AsyncMutex _lock = AsyncMutex();
  late final OutboxPusher _pusher;
  late final TablePuller _puller;
  late final StreamController<SyncState> _controller;
  StreamSubscription<int>? _pendingSub;
  SyncState _current = const SyncState();
  bool _disposed = false;

  @override
  SyncState get current => _current;

  @override
  Stream<SyncState> get state => _controller.stream;

  /// Last push report, for diagnostics screens.
  PushReport? lastPushReport;

  /// Last pull report, for diagnostics screens.
  PullReport? lastPullReport;

  void _emit(SyncState next) {
    _current = next;
    if (!_disposed) _controller.add(next);
  }

  /// Checks token and link; emits the reason and returns false when the
  /// engine must stay idle.
  Future<bool> _ready() async {
    final token = await accessTokenProvider();
    if (token == null || token.isEmpty) {
      _emit(_current.copyWith(status: SyncStatus.offline, error: 'signed out'));
      return false;
    }
    if (requireLink) {
      final linked = await syncState.linkedClinicId();
      if (linked != clinicId) {
        _emit(
          _current.copyWith(
            status: SyncStatus.error,
            error: 'clinic not linked to the server (run RemoteClinicLinker)',
          ),
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _guarded(SyncStatus busy, Future<void> Function() body) async {
    if (!await _ready()) return;
    _emit(_current.copyWith(status: busy, clearError: true));
    try {
      await body();
      _emit(_current.copyWith(status: SyncStatus.idle, clearError: true));
    } on SyncFailure catch (f) {
      _log.warning('${busy.name} stopped: ${f.message}');
      _emit(
        _current.copyWith(
          status: f.isTransient ? SyncStatus.offline : SyncStatus.error,
          error: f.message,
        ),
      );
    } catch (e, st) {
      _log.error('${busy.name} failed: ${e.runtimeType}', stackTrace: st);
      _emit(
        _current.copyWith(status: SyncStatus.error, error: '${e.runtimeType}'),
      );
    }
  }

  Future<void> _push() async {
    lastPushReport = await _pusher.push();
    final at = _clock();
    await syncState.writeInstant(SyncStateKeys.lastPushAt, at);
    _emit(_current.copyWith(lastPushedAt: at));
  }

  Future<void> _pull(DateTime? since) async {
    lastPullReport = await _puller.pullAll(since: since);
    final at = _clock();
    await syncState.writeInstant(SyncStateKeys.lastPullAt, at);
    _emit(_current.copyWith(lastPulledAt: at));
  }

  @override
  Future<void> pushPending() =>
      _lock.synchronized(() => _guarded(SyncStatus.pushing, _push));

  @override
  Future<void> pullSince(DateTime? since) => _lock.synchronized(
    () => _guarded(SyncStatus.pulling, () => _pull(since)),
  );

  /// Push then pull under one lock; what the scheduler runs.
  Future<void> syncNow() => _lock.synchronized(() async {
    await _guarded(SyncStatus.pushing, _push);
    if (_current.status != SyncStatus.idle) return;
    await _guarded(SyncStatus.pulling, () => _pull(null));
  });

  /// Clears every watermark so the next pull is a full one (idempotent
  /// locally: existing rows are kept or overwritten per policy).
  Future<void> resetWatermarks() =>
      _lock.synchronized(syncState.resetWatermarks);

  /// Restores the last stored push/pull times into [current] (call once
  /// after construction so banners show the real last sync).
  Future<void> restoreLastSyncTimes() async {
    final pushed = await syncState.readInstant(SyncStateKeys.lastPushAt);
    final pulled = await syncState.readInstant(SyncStateKeys.lastPullAt);
    _emit(_current.copyWith(lastPushedAt: pushed, lastPulledAt: pulled));
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _pendingSub?.cancel();
    await _controller.close();
  }
}
