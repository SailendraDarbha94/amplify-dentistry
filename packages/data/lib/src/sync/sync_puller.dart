/// Pulls server changes table by table with keyset paging and applies them
/// under the per-table conflict policy.
library;

import 'package:ampdent_core/ampdent_core.dart';
import 'package:drift/drift.dart';
import 'package:supabase/supabase.dart';

import '../db/app_database.dart';
import '../db/converters.dart';
import '../repositories/drift/drift_perio_repository.dart';
import 'outbox_repository.dart';
import 'row_codec.dart';
import 'sync_errors.dart';
import 'sync_state_repository.dart';
import 'sync_tables.dart';

/// Per-table outcome of a pull.
class TablePullReport {
  /// Creates a report.
  TablePullReport(this.table);

  /// Table name.
  final String table;

  /// Rows inserted locally.
  int inserted = 0;

  /// Rows overwritten locally (last-writer-wins).
  int updated = 0;

  /// Rows kept because a local write is still pending.
  int keptPending = 0;

  /// Rows kept because the local copy is at least as new.
  int keptNewer = 0;

  /// Rows kept because the table is append-only.
  int keptAppendOnly = 0;

  /// Rows fetched from the server.
  int fetched = 0;

  @override
  String toString() =>
      '$table: fetched $fetched, inserted $inserted, updated $updated, '
      'kept pending $keptPending, newer $keptNewer, append-only '
      '$keptAppendOnly';
}

/// Outcome of a pull across all tables.
class PullReport {
  /// Creates a report.
  const PullReport(this.tables, {required this.wasFull});

  /// Per-table reports in sync order.
  final List<TablePullReport> tables;

  /// Whether the pull started with no watermarks (first full pull).
  final bool wasFull;

  /// Rows fetched across tables.
  int get fetched => tables.fold(0, (n, t) => n + t.fetched);

  /// Rows written locally across tables.
  int get applied => tables.fold(0, (n, t) => n + t.inserted + t.updated);
}

/// Pulls one clinic's rows for every synced table.
class TablePuller {
  /// Creates the puller.
  TablePuller({
    required this.db,
    required this.client,
    required this.syncState,
    required this.outbox,
    required this.clinicId,
    this.pageSize = 1000,
  });

  static const Logger _log = Logger('TablePuller');

  /// Local database.
  final AppDatabase db;

  /// Supabase client (REST only).
  final SupabaseClient client;

  /// Watermark store.
  final SyncStateRepository syncState;

  /// Outbox, consulted so pending local rows are not overwritten.
  final OutboxRepository outbox;

  /// Clinic to pull.
  final String clinicId;

  /// Rows per page.
  final int pageSize;

  /// Pulls every table. With [since] non-null every watermark is lowered to
  /// that instant first.
  Future<PullReport> pullAll({DateTime? since}) async {
    final wasFull = await syncState.hasNoWatermarks;
    final reports = <TablePullReport>[];
    for (final table in syncTables) {
      reports.add(await pullTable(table, since: since));
    }
    if (wasFull) {
      await syncState.writeInstant(
        SyncStateKeys.lastFullSyncAt,
        DateTime.now().toUtc(),
      );
    }
    return PullReport(reports, wasFull: wasFull);
  }

  /// Pulls one table page by page, advancing its watermark after each page.
  Future<TablePullReport> pullTable(SyncTable table, {DateTime? since}) async {
    final report = TablePullReport(table.name);
    final codec = SyncRowCodec(
      _tableInfo(table.name),
      jsonTextColumns: table.jsonTextColumns,
    );
    var wm = await syncState.watermark(table.name);
    if (since != null) {
      final floor = SyncWatermark(encodeIsoUtc(since));
      if (wm == null || parseInstant(wm.updatedAt).isAfter(since)) wm = floor;
    }
    while (true) {
      final List<Map<String, dynamic>> rows;
      try {
        rows = await _page(table, wm);
      } catch (e) {
        throw classifySyncError(e, table: table.name);
      }
      report.fetched += rows.length;
      if (rows.isEmpty) break;
      await db.transaction(() async {
        for (final row in rows) {
          await _apply(table, codec, row.cast<String, Object?>(), report);
        }
      });
      final last = rows.last;
      wm = SyncWatermark(
        '${last['updated_at']}',
        lastKey: '${last[table.orderKey]}',
      );
      await syncState.setWatermark(table.name, wm);
      if (rows.length < pageSize) break;
    }
    if (report.fetched > 0) _log.info('$report');
    return report;
  }

  Future<List<Map<String, dynamic>>> _page(SyncTable table, SyncWatermark? wm) {
    var q = client.from(table.name).select().eq(table.scopeColumn, clinicId);
    if (wm != null) {
      q = wm.lastKey == null
          ? q.gt('updated_at', wm.updatedAt)
          : q.or(
              'updated_at.gt."${wm.updatedAt}",'
              'and(updated_at.eq."${wm.updatedAt}",'
              '${table.orderKey}.gt."${wm.lastKey}")',
            );
    }
    return q
        .order('updated_at', ascending: true)
        .order(table.orderKey, ascending: true)
        .limit(pageSize);
  }

  Future<void> _apply(
    SyncTable table,
    SyncRowCodec codec,
    Map<String, Object?> server,
    TablePullReport report,
  ) async {
    final values = codec.fromServer(server);
    final keyValues = [for (final c in table.keyColumns) '${values[c]}'];
    final where = table.keyColumns.map((c) => '"$c" = ?').join(' AND ');
    final selectCols = codec.hasUpdatedAt ? '"updated_at"' : '1 AS one';
    final local = await db
        .customSelect(
          'SELECT $selectCols FROM "${table.name}" WHERE $where',
          variables: [for (final v in keyValues) Variable.withString(v)],
        )
        .getSingleOrNull();
    final info = codec.table;
    if (local == null) {
      final (sql, vars) = codec.insertSql(values);
      await db.customInsert(sql, variables: vars, updates: {info});
      await _afterInsert(table, keyValues);
      report.inserted++;
      return;
    }
    if (table.policy == SyncConflictPolicy.appendOnly) {
      report.keptAppendOnly++;
      return;
    }
    if (await outbox.hasPending(table.name, keyValues.join(':'))) {
      report.keptPending++;
      return;
    }
    if (codec.hasUpdatedAt) {
      final serverAt = parseInstant('${server['updated_at']}');
      final localAt = parseInstant(local.read<String>('updated_at'));
      if (!serverAt.isAfter(localAt)) {
        report.keptNewer++;
        return;
      }
    }
    final (sql, vars) = codec.updateSql(values, table.keyColumns);
    await db.customUpdate(sql, variables: vars, updates: {info});
    report.updated++;
  }

  /// Local-only derived data that a pulled row must bring with it. The
  /// repositories build these on local writes; pulled rows bypass them.
  Future<void> _afterInsert(SyncTable table, List<String> keyValues) async {
    if (table.name != 'perio_exams') return;
    final exam = await (db.select(
      db.perioExams,
    )..where((t) => t.id.equals(keyValues.single))).getSingleOrNull();
    if (exam != null) await DriftPerioRepository.indexPerioSites(db, exam);
  }

  TableInfo<Table, Object?> _tableInfo(String name) =>
      db.allTables.firstWhere((t) => t.actualTableName == name);
}
