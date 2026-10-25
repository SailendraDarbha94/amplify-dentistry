import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// Reads and acknowledges `sync_outbox` rows. Rows are never deleted here;
/// `ack` stamps `ackedAt` and pending queries exclude acknowledged rows.
abstract class OutboxRepository {
  /// Pending (unacknowledged) rows, oldest first.
  Future<List<OutboxEntry>> pending(String clinicId, {int limit = 200});

  /// Number of pending rows.
  Future<int> pendingCount(String clinicId);

  /// Stream of the number of pending rows.
  Stream<int> watchPendingCount(String clinicId);

  /// Marks rows as acknowledged by the server.
  Future<void> ack(Iterable<String> ids, {DateTime? at});

  /// Records a failed upload attempt (increments `attempts`, stores the
  /// error).
  Future<void> recordFailure(String id, String error);

  /// Records one failed attempt on every row in [ids] (same bookkeeping as
  /// [recordFailure], one statement). [error] is an error class, never a
  /// payload.
  Future<void> recordFailures(Iterable<String> ids, String error);

  /// Whether [rowId] of [targetTable] still has an unacknowledged entry.
  Future<bool> hasPending(String targetTable, String rowId);
}

/// Drift implementation of [OutboxRepository].
class DriftOutboxRepository extends DatabaseAccessor<AppDatabase>
    implements OutboxRepository {
  /// Creates the repository over [db].
  DriftOutboxRepository(super.db);

  $SyncOutboxTable get _t => attachedDatabase.syncOutbox;

  @override
  Future<List<OutboxEntry>> pending(String clinicId, {int limit = 200}) =>
      (select(_t)
            ..where((t) => t.clinicId.equals(clinicId) & t.ackedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm.asc(t.createdAt),
              (t) => OrderingTerm.asc(t.rowId),
            ])
            ..limit(limit))
          .get();

  Selectable<int> _countQuery(String clinicId) {
    final c = countAll();
    return (selectOnly(_t)
          ..addColumns([c])
          ..where(_t.clinicId.equals(clinicId) & _t.ackedAt.isNull()))
        .map((row) => row.read(c) ?? 0);
  }

  @override
  Future<int> pendingCount(String clinicId) =>
      _countQuery(clinicId).getSingle();

  @override
  Stream<int> watchPendingCount(String clinicId) =>
      _countQuery(clinicId).watchSingle();

  @override
  Future<void> ack(Iterable<String> ids, {DateTime? at}) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    await (update(_t)..where((t) => t.id.isIn(list))).write(
      SyncOutboxCompanion(ackedAt: Value((at ?? DateTime.now()).toUtc())),
    );
  }

  @override
  Future<void> recordFailure(String id, String error) async {
    final row = await (select(
      _t,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await (update(_t)..where((t) => t.id.equals(id))).write(
      SyncOutboxCompanion(
        attempts: Value(row.attempts + 1),
        lastError: Value(error),
      ),
    );
  }

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
