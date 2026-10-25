import 'dart:async';

/// Coarse sync status.
enum SyncStatus {
  /// Nothing in flight.
  idle,

  /// Uploading outbox rows.
  pushing,

  /// Downloading server changes.
  pulling,

  /// Last operation failed; see [SyncState.error].
  error,

  /// No sync backend configured (local-only install).
  disabled,

  /// A backend is configured but unreachable or the user is signed out; the
  /// outbox keeps growing and is drained when connectivity returns.
  offline,
}

/// Snapshot of the sync engine for the UI.
class SyncState {
  /// Creates a state.
  const SyncState({
    this.status = SyncStatus.idle,
    this.pendingCount = 0,
    this.lastPushedAt,
    this.lastPulledAt,
    this.error,
  });

  /// Current status.
  final SyncStatus status;

  /// Outbox rows awaiting upload.
  final int pendingCount;

  /// Last successful push.
  final DateTime? lastPushedAt;

  /// Last successful pull.
  final DateTime? lastPulledAt;

  /// Last error message (error class and table, never row contents).
  final String? error;

  /// Most recent successful push or pull, whichever is later.
  DateTime? get lastSyncedAt {
    final a = lastPushedAt;
    final b = lastPulledAt;
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  /// Whether a push or pull is in flight.
  bool get isBusy =>
      status == SyncStatus.pushing || status == SyncStatus.pulling;

  /// Returns a copy with the given fields replaced; [clearError] drops the
  /// error message.
  SyncState copyWith({
    SyncStatus? status,
    int? pendingCount,
    DateTime? lastPushedAt,
    DateTime? lastPulledAt,
    String? error,
    bool clearError = false,
  }) => SyncState(
    status: status ?? this.status,
    pendingCount: pendingCount ?? this.pendingCount,
    lastPushedAt: lastPushedAt ?? this.lastPushedAt,
    lastPulledAt: lastPulledAt ?? this.lastPulledAt,
    error: clearError ? null : (error ?? this.error),
  );

  @override
  String toString() => 'SyncState($status, pending: $pendingCount)';
}

/// Replicates the local store with a server. `SupabaseSyncEngine` is the
/// real implementation (outbox push, watermark pull); [NoopSyncEngine] serves
/// tests and local-only installs.
abstract class SyncEngine {
  /// Current state.
  SyncState get current;

  /// State changes (emits [current] first).
  Stream<SyncState> get state;

  /// Uploads pending outbox rows.
  Future<void> pushPending();

  /// Downloads changes. With [since] null the engine continues from its
  /// stored per-table watermarks (a full pull when a table has none); a
  /// non-null [since] lowers every watermark to that instant first.
  Future<void> pullSince(DateTime? since);

  /// Releases resources.
  Future<void> dispose();
}

/// Sync engine for local-only installs: does nothing, reports `disabled`
/// and mirrors the pending outbox count when given a [pendingCount] stream.
class NoopSyncEngine implements SyncEngine {
  /// Creates the engine; [pendingCount] usually comes from
  /// `OutboxRepository.watchPendingCount`.
  NoopSyncEngine({Stream<int>? pendingCount})
    : _current = const SyncState(status: SyncStatus.disabled) {
    _controller = StreamController<SyncState>.broadcast(
      onListen: () => _controller.add(_current),
    );
    if (pendingCount != null) {
      _subscription = pendingCount.listen((n) {
        _current = _current.copyWith(pendingCount: n);
        _controller.add(_current);
      });
    }
  }

  late final StreamController<SyncState> _controller;
  StreamSubscription<int>? _subscription;
  SyncState _current;

  @override
  SyncState get current => _current;

  @override
  Stream<SyncState> get state => _controller.stream;

  @override
  Future<void> pushPending() async {}

  @override
  Future<void> pullSince(DateTime? since) async {}

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
  }
}
