/// Drains the sync outbox to PostgREST in foreign-key order.
library;

import 'package:ampdent_core/ampdent_core.dart';
import 'package:drift/drift.dart';
import 'package:supabase/supabase.dart';

import '../db/app_database.dart';
import 'outbox_repository.dart';
import 'row_codec.dart';
import 'sync_errors.dart';
import 'sync_tables.dart';

/// Outcome of one push.
class PushReport {
  /// Creates a report.
  const PushReport({required this.rowsSent, required this.entriesAcked});

  /// Rows upserted (after de-duplicating repeated writes of one row).
  final int rowsSent;

  /// Outbox entries acknowledged.
  final int entriesAcked;

  @override
  String toString() => 'PushReport(rows: $rowsSent, acked: $entriesAcked)';
}

/// Reads pending outbox entries, loads the current local row for each,
/// upserts them table by table in [buildPushPlan] order, and acknowledges
/// the entries only after the server answered 2xx for every step that
/// touches their table.
class OutboxPusher {
  /// Creates the pusher.
  OutboxPusher({
    required this.db,
    required this.outbox,
    required this.client,
    required this.clinicId,
    this.backoff = const BackoffPolicy(),
    this.batchSize = 200,
    this.pendingLimit = 5000,
    Future<void> Function(Duration)? sleep,
  }) : _sleep = sleep ?? _defaultSleep;

  static const Logger _log = Logger('OutboxPusher');

  static Future<void> _defaultSleep(Duration d) => Future<void>.delayed(d);

  /// Local database.
  final AppDatabase db;

  /// Outbox.
  final OutboxRepository outbox;

  /// Supabase client (REST only).
  final SupabaseClient client;

  /// Clinic whose outbox is drained.
  final String clinicId;

  /// Retry schedule for transient failures.
  final BackoffPolicy backoff;

  /// Rows per upsert request.
  final int batchSize;

  /// Outbox entries read per pass.
  final int pendingLimit;

  final Future<void> Function(Duration) _sleep;
  final List<PushStep> _plan = buildPushPlan();

  /// Pushes everything pending. Throws [SyncFailure] when a step fails after
  /// its retries; entries already acknowledged stay acknowledged.
  Future<PushReport> push() async {
    var rows = 0;
    var acked = 0;
    while (true) {
      final pending = await outbox.pending(clinicId, limit: pendingLimit);
      if (pending.isEmpty) break;
      final (r, a) = await _pass(pending);
      rows += r;
      acked += a;
      if (a == 0 || pending.length < pendingLimit) break;
    }
    return PushReport(rowsSent: rows, entriesAcked: acked);
  }

  Future<(int, int)> _pass(List<OutboxEntry> pending) async {
    // Entries per table, keeping first-write order; one upsert per row id.
    final byTable = <String, Map<String, List<OutboxEntry>>>{};
    for (final e in pending) {
      byTable
          .putIfAbsent(e.targetTable, () => {})
          .putIfAbsent(e.rowId, () => [])
          .add(e);
    }
    var rows = 0;
    var acked = 0;
    for (final name in byTable.keys) {
      if (!syncTablesByName.containsKey(name)) {
        final ids = byTable[name]!.values.expand((l) => l).map((e) => e.id);
        _log.warning('$name has no server table; acknowledging without send');
        await outbox.ack(ids);
        acked += ids.length;
      }
    }
    for (final step in _plan) {
      final entries = byTable[step.table.name];
      if (entries == null || entries.isEmpty) continue;
      rows += await _runStep(step, entries);
      if (step.isFinal) {
        final ids = entries.values.expand((l) => l).map((e) => e.id).toList();
        await outbox.ack(ids);
        acked += ids.length;
        _log.info('${step.table.name}: ${entries.length} rows pushed');
      }
    }
    return (rows, acked);
  }

  Future<int> _runStep(
    PushStep step,
    Map<String, List<OutboxEntry>> entries,
  ) async {
    final table = step.table;
    final codec = SyncRowCodec(
      _tableInfo(table.name),
      jsonTextColumns: table.jsonTextColumns,
    );
    final rowIds = entries.keys.toList();
    var sent = 0;
    for (var i = 0; i < rowIds.length; i += batchSize) {
      final chunk = rowIds.sublist(
        i,
        i + batchSize > rowIds.length ? rowIds.length : i + batchSize,
      );
      final local = await _loadRows(table, codec, chunk);
      final payload = <Map<String, Object?>>[];
      for (final row in local) {
        if (table.scopeNullable && row[table.scopeColumn] == null) continue;
        if (step.isFixup && step.onlyColumns!.every((c) => row[c] == null)) {
          continue;
        }
        payload.add(
          codec.toServer(
            row,
            exclude: step.excludeColumns,
            only: step.onlyColumns == null
                ? null
                : {...table.keyColumns, ...step.onlyColumns!},
          ),
        );
      }
      if (payload.isEmpty) continue;
      final entryIds = chunk.expand((id) => entries[id]!).map((e) => e.id);
      await _upsertWithBackoff(table, payload, entryIds.toList());
      sent += payload.length;
    }
    return sent;
  }

  Future<void> _upsertWithBackoff(
    SyncTable table,
    List<Map<String, Object?>> payload,
    List<String> entryIds,
  ) async {
    for (var attempt = 1; ; attempt++) {
      try {
        await client
            .from(table.name)
            .upsert(
              payload,
              onConflict: table.keyColumns.join(','),
              ignoreDuplicates: table.ignoreDuplicatesOnPush,
              defaultToNull: false,
            );
        return;
      } catch (e) {
        final failure = classifySyncError(e, table: table.name);
        await outbox.recordFailures(entryIds, failure.message);
        _log.warning(
          '${table.name}: ${payload.length} rows failed (attempt $attempt): '
          '${failure.message}',
        );
        if (!failure.isTransient || attempt >= backoff.maxAttempts) {
          throw failure;
        }
        await _sleep(backoff.delayFor(attempt));
      }
    }
  }

  TableInfo<Table, Object?> _tableInfo(String name) =>
      db.allTables.firstWhere((t) => t.actualTableName == name);

  /// Current local rows for [rowIds], in the given order; rows that no
  /// longer exist are skipped.
  Future<List<Map<String, Object?>>> _loadRows(
    SyncTable table,
    SyncRowCodec codec,
    List<String> rowIds,
  ) async {
    final byId = <String, Map<String, Object?>>{};
    if (table.hasIdKey) {
      final marks = List.filled(rowIds.length, '?').join(', ');
      final rows = await db
          .customSelect(
            'SELECT * FROM "${table.name}" WHERE "id" IN ($marks)',
            variables: [for (final id in rowIds) Variable.withString(id)],
          )
          .get();
      for (final r in rows) {
        byId['${r.data['id']}'] = r.data;
      }
    } else {
      final where = table.keyColumns.map((c) => '"$c" = ?').join(' AND ');
      for (final rowId in rowIds) {
        final parts = table.splitRowId(rowId);
        final row = await db
            .customSelect(
              'SELECT * FROM "${table.name}" WHERE $where',
              variables: [for (final p in parts) Variable.withString(p)],
            )
            .getSingleOrNull();
        if (row != null) byId[rowId] = row.data;
      }
    }
    return [
      for (final id in rowIds)
        if (byId[id] != null) byId[id]!,
    ];
  }
}
