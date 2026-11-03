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
  const PushReport({
    required this.rowsSent,
    required this.entriesAcked,
    this.rowsQuarantined = 0,
    this.entriesBlocked = 0,
  });

  /// Rows upserted (after de-duplicating repeated writes of one row).
  final int rowsSent;

  /// Outbox entries acknowledged.
  final int entriesAcked;

  /// Rows the server rejected for good during this push (now quarantined).
  final int rowsQuarantined;

  /// Outbox entries held back behind a quarantined row during this push.
  final int entriesBlocked;

  @override
  String toString() =>
      'PushReport(rows: $rowsSent, acked: $entriesAcked, '
      'quarantined: $rowsQuarantined, blocked: $entriesBlocked)';
}

/// Reads pending outbox entries, loads the current local row for each,
/// upserts them table by table in [buildPushPlan] order, and acknowledges
/// the entries only after the server answered 2xx for every step that
/// touches their table.
///
/// A permanent rejection (4xx other than 401/408/429, a constraint or
/// policy error) quarantines the offending row instead of stopping the
/// push: the failed batch is re-sent row by row to find the poison rows,
/// each of those has its outbox entries marked `quarantined` (with the error
/// class and status code), every pending entry whose local row references
/// it through a foreign key is marked `blockedBy` that entry (transitively),
/// and the remaining rows and tables continue. Transient failures still
/// retry with backoff and then stop the push, and a 401 stops it at once.
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
    this.maxPasses = 50,
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

  /// Upper bound on passes per push (a pass acknowledges or releases rows,
  /// so this only guards against a pathological loop).
  final int maxPasses;

  final Future<void> Function(Duration) _sleep;
  final List<PushStep> _plan = buildPushPlan();
  Map<String, List<(String, String)>>? _fkChildren;

  /// Pushes everything pending. Throws [SyncFailure] when a step fails after
  /// its retries; entries already acknowledged stay acknowledged.
  Future<PushReport> push() async {
    var rows = 0;
    var acked = 0;
    var quarantined = 0;
    var blocked = 0;
    for (var pass = 0; pass < maxPasses; pass++) {
      final pending = await outbox.pending(clinicId, limit: pendingLimit);
      if (pending.isEmpty) break;
      final result = await _pass(pending);
      rows += result.rowsSent;
      acked += result.entriesAcked;
      quarantined += result.rowsQuarantined;
      blocked += result.entriesBlocked;
      // A parent row that was accepted on this pass releases the entries
      // that were waiting behind its earlier, rejected state.
      final released = await outbox.releaseBlocked(clinicId);
      if (released > 0) {
        _log.info('$released blocked entries released');
        continue;
      }
      if (result.entriesAcked == 0 || pending.length < pendingLimit) break;
    }
    return PushReport(
      rowsSent: rows,
      entriesAcked: acked,
      rowsQuarantined: quarantined,
      entriesBlocked: blocked,
    );
  }

  Future<PushReport> _pass(List<OutboxEntry> pending) async {
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
    final counters = _PassCounters();
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
      rows += await _runStep(step, entries, byTable, counters);
      if (step.isFinal && entries.isNotEmpty) {
        final ids = entries.values.expand((l) => l).map((e) => e.id).toList();
        await outbox.ack(ids);
        // Older rejected states of the same rows are obsolete now.
        await outbox.ackHeldRows(step.table.name, entries.keys);
        acked += ids.length;
        _log.info('${step.table.name}: ${entries.length} rows pushed');
      }
    }
    return PushReport(
      rowsSent: rows,
      entriesAcked: acked,
      rowsQuarantined: counters.quarantined,
      entriesBlocked: counters.blocked,
    );
  }

  Future<int> _runStep(
    PushStep step,
    Map<String, List<OutboxEntry>> entries,
    Map<String, Map<String, List<OutboxEntry>>> byTable,
    _PassCounters counters,
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
      final payload = <String, Map<String, Object?>>{};
      for (final row in local) {
        if (table.scopeNullable && row[table.scopeColumn] == null) continue;
        if (step.isFixup && step.onlyColumns!.every((c) => row[c] == null)) {
          continue;
        }
        final encoded = codec.toServer(
          row,
          exclude: {...step.excludeColumns, ...table.localOnlyColumns},
          only: step.onlyColumns == null
              ? null
              : {...table.keyColumns, ...step.onlyColumns!},
        );
        for (final c in table.serverDefaultColumns) {
          if (encoded[c] == null) encoded.remove(c);
        }
        payload[table.rowIdOf(row)] = encoded;
      }
      if (payload.isEmpty) continue;
      // Rows that were held while an earlier step ran (a parent of theirs
      // was quarantined) are not sent.
      payload.removeWhere((id, _) => !entries.containsKey(id));
      if (payload.isEmpty) continue;
      sent += await _sendChunk(
        step,
        codec,
        payload,
        entries,
        byTable,
        counters,
      );
    }
    return sent;
  }

  /// Sends one chunk; on a permanent rejection isolates the poison rows and
  /// quarantines them. Returns the number of rows the server accepted.
  Future<int> _sendChunk(
    PushStep step,
    SyncRowCodec codec,
    Map<String, Map<String, Object?>> payload,
    Map<String, List<OutboxEntry>> entries,
    Map<String, Map<String, List<OutboxEntry>>> byTable,
    _PassCounters counters,
  ) async {
    final table = step.table;
    List<String> entryIdsOf(Iterable<String> rowIds) => [
      for (final id in rowIds)
        for (final e in entries[id] ?? const <OutboxEntry>[]) e.id,
    ];
    try {
      await _upsertWithBackoff(
        table,
        payload.values.toList(),
        entryIdsOf(payload.keys),
      );
      return payload.length;
    } on SyncFailure catch (f) {
      if (!f.isPermanent) rethrow;
      if (payload.length == 1) {
        await _quarantine(table, payload.keys.single, f, byTable, counters);
        return 0;
      }
    }
    // The batch holds at least one poison row: find it row by row.
    var accepted = 0;
    for (final MapEntry(key: rowId, value: row) in payload.entries) {
      // Blocked meanwhile by a poison row earlier in this same chunk.
      if (!entries.containsKey(rowId)) continue;
      try {
        await _upsertWithBackoff(table, [row], entryIdsOf([rowId]));
        accepted++;
      } on SyncFailure catch (f) {
        if (!f.isPermanent) rethrow;
        await _quarantine(table, rowId, f, byTable, counters);
      }
    }
    return accepted;
  }

  /// Holds every outbox entry of ([table], [rowId]) as quarantined, then
  /// blocks the pending entries of rows that reference it.
  Future<void> _quarantine(
    SyncTable table,
    String rowId,
    SyncFailure failure,
    Map<String, Map<String, List<OutboxEntry>>> byTable,
    _PassCounters counters,
  ) async {
    final inPass = byTable[table.name]?.remove(rowId) ?? const [];
    final all = {
      for (final e in inPass) e.id: e,
      for (final e in await outbox.unackedForRow(table.name, rowId)) e.id: e,
    };
    final sorted = all.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final rootId = sorted.first.id;
    final server = failure.serverMessage;
    await outbox.quarantine(
      all.keys,
      error: server == null ? failure.message : '${failure.message}: $server',
      statusCode: failure.statusCode,
    );
    counters.quarantined++;
    _log.warning(
      '${table.name}: row quarantined (${failure.message}, '
      'status ${failure.statusCode})',
    );
    await _blockDependants(table.name, rowId, rootId, byTable, counters);
  }

  /// Marks the pending entries of rows that reference ([parentTable],
  /// [parentRowId]) through a foreign key as blocked by [rootId], then
  /// recurses into those rows.
  Future<void> _blockDependants(
    String parentTable,
    String parentRowId,
    String rootId,
    Map<String, Map<String, List<OutboxEntry>>> byTable,
    _PassCounters counters,
  ) async {
    final children = (await _foreignKeyChildren())[parentTable];
    if (children == null) return;
    for (final (childTable, column) in children) {
      final table = syncTablesByName[childTable];
      if (table == null) continue;
      final pending = await outbox.pendingForTable(clinicId, childTable);
      if (pending.isEmpty) continue;
      final byRow = <String, List<OutboxEntry>>{};
      for (final e in pending) {
        byRow.putIfAbsent(e.rowId, () => []).add(e);
      }
      final codec = SyncRowCodec(_tableInfo(childTable));
      final rows = await _loadRows(table, codec, byRow.keys.toList());
      for (final row in rows) {
        if ('${row[column]}' != parentRowId) continue;
        final childRowId = table.rowIdOf(row);
        final ids = [for (final e in byRow[childRowId]!) e.id];
        await outbox.block(ids, parentId: rootId);
        counters.blocked += ids.length;
        byTable[childTable]?.remove(childRowId);
        await _blockDependants(
          childTable,
          childRowId,
          rootId,
          byTable,
          counters,
        );
      }
    }
  }

  /// `parent table -> [(child table, referencing column)]` for every synced
  /// table, from SQLite's own foreign-key metadata. Only references to a
  /// parent's `id` are followed (every synced FK is one).
  Future<Map<String, List<(String, String)>>> _foreignKeyChildren() async {
    final cached = _fkChildren;
    if (cached != null) return cached;
    final out = <String, List<(String, String)>>{};
    for (final table in syncTables) {
      final rows = await db
          .customSelect('PRAGMA foreign_key_list("${table.name}")')
          .get();
      for (final r in rows) {
        final parent = r.read<String>('table');
        final to = r.readNullable<String>('to');
        if (to != null && to != 'id') continue;
        out.putIfAbsent(parent, () => []).add((
          table.name,
          r.read<String>('from'),
        ));
      }
    }
    return _fkChildren = out;
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
        if (!failure.isPermanent) {
          await outbox.recordFailures(entryIds, failure.message);
        }
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

class _PassCounters {
  int quarantined = 0;
  int blocked = 0;
}
