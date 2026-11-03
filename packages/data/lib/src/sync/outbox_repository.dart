import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../db/tables_clinic.dart';

/// Reads, holds and acknowledges `sync_outbox` rows. Rows are never deleted
/// here; `ack` stamps `ackedAt` and pending queries exclude acknowledged
/// rows. Besides `pending`, an unacknowledged row can be `quarantined`
/// (rejected by the server for good), `blockedBy` (waiting on a quarantined
/// parent) or `discarded` (dropped by the repair service); only `pending`
/// rows are pushed.
abstract class OutboxRepository {
  /// Pending (unacknowledged, status `pending`) rows, oldest first.
  Future<List<OutboxEntry>> pending(String clinicId, {int limit = 200});

  /// Number of pending rows.
  Future<int> pendingCount(String clinicId);

  /// Stream of the number of pending rows.
  Stream<int> watchPendingCount(String clinicId);

  /// Unacknowledged rows held back (`quarantined` or `blockedBy`), oldest
  /// first.
  Future<List<OutboxEntry>> held(String clinicId);

  /// Number of held rows.
  Future<int> heldCount(String clinicId);

  /// Stream of the number of held rows.
  Stream<int> watchHeldCount(String clinicId);

  /// One entry by id, or null.
  Future<OutboxEntry?> byId(String id);

  /// Every unacknowledged entry (any status) of one row.
  Future<List<OutboxEntry>> unackedForRow(String targetTable, String rowId);

  /// Unacknowledged `pending` entries of [targetTable] for the clinic.
  Future<List<OutboxEntry>> pendingForTable(
    String clinicId,
    String targetTable,
  );

  /// Unacknowledged entries whose `blockedBy` is one of [parentIds].
  Future<List<OutboxEntry>> blockedBy(Iterable<String> parentIds);

  /// Marks rows as acknowledged by the server.
  Future<void> ack(Iterable<String> ids, {DateTime? at});

  /// Acknowledges the held (`quarantined` / `blockedBy`) entries of the
  /// given rows of [targetTable]: a later write of the same row reached the
  /// server, so the older rejected state is obsolete.
  Future<int> ackHeldRows(
    String targetTable,
    Iterable<String> rowIds, {
    DateTime? at,
  });

  /// Records a failed upload attempt (increments `attempts`, stores the
  /// error).
  Future<void> recordFailure(String id, String error);

  /// Records one failed attempt on every row in [ids] (same bookkeeping as
  /// [recordFailure], one statement). [error] is an error class, never a
  /// payload.
  Future<void> recordFailures(Iterable<String> ids, String error);

  /// Holds [ids] as `quarantined` with the error class and the server's
  /// status code; also counts one attempt.
  Future<void> quarantine(
    Iterable<String> ids, {
    required String error,
    int? statusCode,
  });

  /// Holds [ids] as `blockedBy` the quarantined entry [parentId].
  Future<void> block(Iterable<String> ids, {required String parentId});

  /// Returns [ids] to `pending` (clears `blockedBy`).
  Future<void> requeue(Iterable<String> ids);

  /// Marks [ids] `discarded` and acknowledged: they will never be sent.
  Future<void> discard(Iterable<String> ids, {DateTime? at});

  /// Releases `blockedBy` entries whose parent entry has since been
  /// acknowledged (a later write of the parent row was accepted); returns
  /// how many went back to `pending`.
  Future<int> releaseBlocked(String clinicId);

  /// Whether [rowId] of [targetTable] still has an unacknowledged entry (of
  /// any status: a held local change still protects the local row).
  Future<bool> hasPending(String targetTable, String rowId);
}

/// Drift implementation of [OutboxRepository].
class DriftOutboxRepository extends DatabaseAccessor<AppDatabase>
    implements OutboxRepository {
  /// Creates the repository over [db].
  DriftOutboxRepository(super.db);

  $SyncOutboxTable get _t => attachedDatabase.syncOutbox;

  static const List<OutboxStatus> _heldStatuses = [
    OutboxStatus.quarantined,
    OutboxStatus.blockedBy,
  ];

  Expression<bool> _unacked($SyncOutboxTable t, String clinicId) =>
      t.clinicId.equals(clinicId) & t.ackedAt.isNull();

  Expression<bool> _isPending($SyncOutboxTable t, String clinicId) =>
      _unacked(t, clinicId) & t.status.equalsValue(OutboxStatus.pending);

  Expression<bool> _isHeld($SyncOutboxTable t, String clinicId) =>
      _unacked(t, clinicId) & t.status.isInValues(_heldStatuses);

  List<OrderingTerm Function($SyncOutboxTable)> get _oldestFirst => [
    (t) => OrderingTerm.asc(t.createdAt),
    (t) => OrderingTerm.asc(t.rowId),
  ];

  @override
  Future<List<OutboxEntry>> pending(String clinicId, {int limit = 200}) =>
      (select(_t)
            ..where((t) => _isPending(t, clinicId))
            ..orderBy(_oldestFirst)
            ..limit(limit))
          .get();

  Selectable<int> _count(Expression<bool> where) {
    final c = countAll();
    return (selectOnly(_t)
          ..addColumns([c])
          ..where(where))
        .map((row) => row.read(c) ?? 0);
  }

  @override
  Future<int> pendingCount(String clinicId) =>
      _count(_isPending(_t, clinicId)).getSingle();

  @override
  Stream<int> watchPendingCount(String clinicId) =>
      _count(_isPending(_t, clinicId)).watchSingle();

  @override
  Future<List<OutboxEntry>> held(String clinicId) =>
      (select(_t)
            ..where((t) => _isHeld(t, clinicId))
            ..orderBy(_oldestFirst))
          .get();

  @override
  Future<int> heldCount(String clinicId) =>
      _count(_isHeld(_t, clinicId)).getSingle();

  @override
  Stream<int> watchHeldCount(String clinicId) =>
      _count(_isHeld(_t, clinicId)).watchSingle();

  @override
  Future<OutboxEntry?> byId(String id) =>
      (select(_t)..where((t) => t.id.equals(id))).getSingleOrNull();

  @override
  Future<List<OutboxEntry>> unackedForRow(String targetTable, String rowId) =>
      (select(_t)
            ..where(
              (t) =>
                  t.targetTable.equals(targetTable) &
                  t.rowId.equals(rowId) &
                  t.ackedAt.isNull(),
            )
            ..orderBy(_oldestFirst))
          .get();

  @override
  Future<List<OutboxEntry>> pendingForTable(
    String clinicId,
    String targetTable,
  ) =>
      (select(_t)
            ..where(
              (t) =>
                  _isPending(t, clinicId) & t.targetTable.equals(targetTable),
            )
            ..orderBy(_oldestFirst))
          .get();

  @override
  Future<List<OutboxEntry>> blockedBy(Iterable<String> parentIds) {
    final list = parentIds.toList();
    if (list.isEmpty) return Future.value(const []);
    return (select(_t)
          ..where((t) => t.ackedAt.isNull() & t.blockedBy.isIn(list))
          ..orderBy(_oldestFirst))
        .get();
  }

  @override
  Future<void> ack(Iterable<String> ids, {DateTime? at}) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    await (update(_t)..where((t) => t.id.isIn(list))).write(
      SyncOutboxCompanion(ackedAt: Value((at ?? DateTime.now()).toUtc())),
    );
  }

  @override
  Future<int> ackHeldRows(
    String targetTable,
    Iterable<String> rowIds, {
    DateTime? at,
  }) async {
    final list = rowIds.toList();
    if (list.isEmpty) return 0;
    return (update(_t)..where(
          (t) =>
              t.targetTable.equals(targetTable) &
              t.rowId.isIn(list) &
              t.ackedAt.isNull() &
              t.status.isInValues(_heldStatuses),
        ))
        .write(
          SyncOutboxCompanion(ackedAt: Value((at ?? DateTime.now()).toUtc())),
        );
  }

  @override
  Future<void> recordFailure(String id, String error) =>
      recordFailures([id], error);

  @override
  Future<void> recordFailures(Iterable<String> ids, String error) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    final marks = List.filled(list.length, '?').join(', ');
    await customUpdate(
      'UPDATE sync_outbox SET attempts = attempts + 1, last_error = ? '
      'WHERE id IN ($marks)',
      variables: [
        Variable.withString(error),
        for (final id in list) Variable.withString(id),
      ],
      updates: {_t},
    );
  }

  @override
  Future<void> quarantine(
    Iterable<String> ids, {
    required String error,
    int? statusCode,
  }) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    final marks = List.filled(list.length, '?').join(', ');
    await customUpdate(
      'UPDATE sync_outbox SET attempts = attempts + 1, last_error = ?, '
      "status = 'quarantined', server_status_code = ?, blocked_by = NULL "
      'WHERE id IN ($marks)',
      variables: [
        Variable.withString(error),
        Variable<int>(statusCode),
        for (final id in list) Variable.withString(id),
      ],
      updates: {_t},
    );
  }

  @override
  Future<void> block(Iterable<String> ids, {required String parentId}) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    await (update(_t)..where((t) => t.id.isIn(list))).write(
      SyncOutboxCompanion(
        status: const Value(OutboxStatus.blockedBy),
        blockedBy: Value(parentId),
      ),
    );
  }

  @override
  Future<void> requeue(Iterable<String> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    await (update(_t)..where((t) => t.id.isIn(list))).write(
      const SyncOutboxCompanion(
        status: Value(OutboxStatus.pending),
        blockedBy: Value(null),
      ),
    );
  }

  @override
  Future<void> discard(Iterable<String> ids, {DateTime? at}) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    await (update(_t)..where((t) => t.id.isIn(list))).write(
      SyncOutboxCompanion(
        status: const Value(OutboxStatus.discarded),
        ackedAt: Value((at ?? DateTime.now()).toUtc()),
      ),
    );
  }

  @override
  Future<int> releaseBlocked(String clinicId) => customUpdate(
    "UPDATE sync_outbox SET status = 'pending', blocked_by = NULL "
    "WHERE clinic_id = ? AND acked_at IS NULL AND status = 'blockedBy' "
    'AND blocked_by IN (SELECT id FROM sync_outbox '
    "WHERE acked_at IS NOT NULL AND status <> 'discarded')",
    variables: [Variable.withString(clinicId)],
    updates: {_t},
  );

  @override
  Future<bool> hasPending(String targetTable, String rowId) async {
    final rows = await customSelect(
      'SELECT 1 FROM sync_outbox WHERE target_table = ? AND row_id = ? '
      'AND acked_at IS NULL LIMIT 1',
      variables: [Variable.withString(targetTable), Variable.withString(rowId)],
      readsFrom: {_t},
    ).get();
    return rows.isNotEmpty;
  }
}
