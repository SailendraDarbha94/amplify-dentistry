/// Lists and resolves outbox rows the server rejected for good.
library;

import 'dart:convert';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:drift/drift.dart';
import 'package:supabase/supabase.dart';

import '../db/app_database.dart';
import '../db/tables_clinic.dart';
import '../repositories/actor_context.dart';
import '../repositories/audit_repository.dart';
import 'outbox_repository.dart';
import 'row_codec.dart';
import 'sync_errors.dart';
import 'sync_state_repository.dart';
import 'sync_tables.dart';

/// One held local change: a row whose outbox entries are quarantined, or
/// blocked behind a quarantined row. [id] is the oldest held outbox entry
/// of the row and the handle for [SyncRepairService.retry] /
/// [SyncRepairService.discardLocalChange].
class SyncProblem {
  /// Creates a problem.
  const SyncProblem({
    required this.id,
    required this.entryIds,
    required this.table,
    required this.rowId,
    required this.entityType,
    required this.entityLabel,
    required this.status,
    required this.changedAt,
    this.error,
    this.statusCode,
    this.blockedBy,
    this.attempts = 0,
  });

  /// Oldest held outbox entry of the row.
  final String id;

  /// Every held outbox entry of the row.
  final List<String> entryIds;

  /// SQL table name.
  final String table;

  /// Row key (`id`, or `clinic_id:setting_key` for settings).
  final String rowId;

  /// Domain entity name (`Patient`, `Invoice`).
  final String entityType;

  /// Short human label of the row (a name, a number, a date), never a
  /// clinical detail.
  final String entityLabel;

  /// `quarantined` or `blockedBy`.
  final OutboxStatus status;

  /// When the local change was made (oldest held entry).
  final DateTime changedAt;

  /// Error class and server message of the rejection; null while blocked.
  final String? error;

  /// HTTP status of the rejection (inferred for Postgres codes).
  final int? statusCode;

  /// Outbox id of the quarantined parent, when blocked.
  final String? blockedBy;

  /// Upload attempts of the oldest entry.
  final int attempts;

  /// Whether the row itself was rejected (as opposed to waiting on one).
  bool get isQuarantined => status == OutboxStatus.quarantined;

  /// One readable line: table, label, error and time. Safe to show.
  String get description {
    final when = changedAt.toIso8601String();
    return isQuarantined
        ? '$entityType "$entityLabel" ($table): rejected by the server'
              '${statusCode == null ? '' : ' ($statusCode)'}'
              '${error == null ? '' : ': $error'}; changed $when'
        : '$entityType "$entityLabel" ($table): waiting on a rejected row; '
              'changed $when';
  }

  @override
  String toString() => 'SyncProblem(${status.name}, $table/$rowId)';
}

/// Resolves quarantined and blocked outbox rows: list them with a readable
/// description, re-queue a chain for another push, or drop the local change
/// and take the server's copy of the row instead.
class SyncRepairService {
  /// Creates the service.
  SyncRepairService({
    required this.db,
    required this.client,
    required this.clinicId,
    required this.outbox,
    required this.syncState,
    required this.audit,
    DateTime Function()? clock,
  }) : _clock = clock ?? _utcNow;

  static const Logger _log = Logger('SyncRepairService');

  static DateTime _utcNow() => DateTime.now().toUtc();

  /// Local database.
  final AppDatabase db;

  /// Supabase client (REST only).
  final SupabaseClient client;

  /// Clinic replicated by this device.
  final String clinicId;

  /// Outbox.
  final OutboxRepository outbox;

  /// Holds the rejected-row notes.
  final SyncStateRepository syncState;

  /// Receives an event for every row marked rejected.
  final AuditRepository audit;

  final DateTime Function() _clock;

  /// Every held row, oldest change first.
  Future<List<SyncProblem>> listProblems() async {
    final held = await outbox.held(clinicId);
    final byRow = <(String, String), List<OutboxEntry>>{};
    for (final e in held) {
      byRow.putIfAbsent((e.targetTable, e.rowId), () => []).add(e);
    }
    final out = <SyncProblem>[];
    for (final MapEntry(key: (table, rowId), value: entries) in byRow.entries) {
      // A row that is both quarantined and blocked reports as quarantined.
      final quarantined = entries
          .where((e) => e.status == OutboxStatus.quarantined)
          .toList();
      final root = (quarantined.isEmpty ? entries : quarantined).first;
      final row = await _loadLocalRow(table, rowId);
      out.add(
        SyncProblem(
          id: root.id,
          entryIds: [for (final e in entries) e.id],
          table: table,
          rowId: rowId,
          entityType: entityTypeForTable(table),
          entityLabel: entityLabelFor(table, row, rowId),
          status: root.status,
          changedAt: root.createdAt,
          error: root.lastError,
          statusCode: root.serverStatusCode,
          blockedBy: root.blockedBy,
          attempts: root.attempts,
        ),
      );
    }
    return out;
  }

  /// Re-queues the row behind outbox entry [id] together with everything
  /// held with it (other entries of the same row and, transitively, the
  /// rows blocked by it). The next push sends the rows' current local state.
  Future<int> retry(String id) async {
    final chain = await _chain(id);
    await outbox.requeue(chain.map((e) => e.id));
    _log.info('re-queued ${chain.length} entries');
    return chain.length;
  }

  /// Drops the local change behind outbox entry [id] (and the chain held
  /// with it) so it is never sent, then makes each affected local row match
  /// the server: a last-writer-wins row the server holds is overwritten
  /// with the server copy; a row the server does not hold, or an
  /// append-only row, cannot be replaced and is instead noted as rejected
  /// in `sync_state` (`rejected.<table>.<id>`) and in the audit log, so the
  /// record stays visible and auditable without ever replicating.
  Future<SyncRepairOutcome> discardLocalChange(
    String id,
    ActorContext ctx,
  ) async {
    final chain = await _chain(id);
    if (chain.isEmpty) return const SyncRepairOutcome();
    final now = _clock();
    await outbox.discard(chain.map((e) => e.id), at: now);
    final rows = <(String, String), OutboxEntry>{};
    for (final e in chain) {
      rows.putIfAbsent((e.targetTable, e.rowId), () => e);
    }
    var restored = 0;
    var rejected = 0;
    for (final MapEntry(key: (table, rowId), value: entry) in rows.entries) {
      final sync = syncTablesByName[table];
      if (sync == null) continue;
      final server = await _fetchServerRow(sync, rowId);
      if (server != null && sync.policy == SyncConflictPolicy.lastWriterWins) {
        await _overwriteLocal(sync, server);
        restored++;
        continue;
      }
      await _markRejected(sync, rowId, entry, ctx, now);
      rejected++;
    }
    _log.info(
      'discarded ${chain.length} entries: $restored rows restored from the '
      'server, $rejected rows noted as rejected',
    );
    return SyncRepairOutcome(
      entriesDiscarded: chain.length,
      rowsRestored: restored,
      rowsRejected: rejected,
    );
  }

  /// Rows noted as rejected by [discardLocalChange], keyed by
  /// `rejected.<table>.<row id>`.
  Future<Map<String, Map<String, Object?>>> rejectedRows() =>
      syncState.rejectedNotes();

  /// Removes the rejected note of [table] / [rowId] (the row was fixed and
  /// pushed, or the user acknowledged it).
  Future<void> clearRejected(String table, String rowId) =>
      syncState.write(SyncStateKeys.rejected(table, rowId), null);

  /// The held entry [id], every unacknowledged entry of its row, and the
  /// entries blocked by any of those (transitively).
  Future<List<OutboxEntry>> _chain(String id) async {
    final root = await outbox.byId(id);
    if (root == null || root.ackedAt != null) return const [];
    final seen = <String, OutboxEntry>{};
    final queue = [root];
    while (queue.isNotEmpty) {
      final e = queue.removeLast();
      if (seen.containsKey(e.id)) continue;
      final sameRow = await outbox.unackedForRow(e.targetTable, e.rowId);
      for (final s in [e, ...sameRow]) {
        if (seen.containsKey(s.id)) continue;
        seen[s.id] = s;
        queue.addAll(await outbox.blockedBy([s.id]));
      }
    }
    return seen.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<Map<String, Object?>?> _fetchServerRow(
    SyncTable table,
    String rowId,
  ) async {
    final parts = table.splitRowId(rowId);
    try {
      var q = client.from(table.name).select();
      for (var i = 0; i < table.keyColumns.length; i++) {
        q = q.eq(table.keyColumns[i], parts[i]);
      }
      final rows = await q.limit(1);
      return rows.isEmpty ? null : rows.first.cast<String, Object?>();
    } catch (e) {
      final failure = classifySyncError(e, table: table.name);
      if (failure.isTransient || failure.kind == SyncFailureKind.notReady) {
        throw failure;
      }
      _log.warning('${table.name}: server row lookup rejected');
      return null;
    }
  }

  Future<void> _overwriteLocal(
    SyncTable table,
    Map<String, Object?> server,
  ) async {
    final info = _tableInfo(table.name);
    final codec = SyncRowCodec(info, jsonTextColumns: table.jsonTextColumns);
    final values = codec.fromServer(server);
    final keyValues = [for (final c in table.keyColumns) '${values[c]}'];
    final where = table.keyColumns.map((c) => '"$c" = ?').join(' AND ');
    final local = await db
        .customSelect(
          'SELECT 1 FROM "${table.name}" WHERE $where',
          variables: [for (final v in keyValues) Variable.withString(v)],
        )
        .getSingleOrNull();
    final (sql, vars) = local == null
        ? codec.insertSql(values)
        : codec.updateSql(values, table.keyColumns);
    if (local == null) {
      await db.customInsert(sql, variables: vars, updates: {info});
    } else {
      await db.customUpdate(sql, variables: vars, updates: {info});
    }
  }

  Future<void> _markRejected(
    SyncTable table,
    String rowId,
    OutboxEntry entry,
    ActorContext ctx,
    DateTime now,
  ) async {
    final note = {
      'error': entry.lastError,
      'statusCode': entry.serverStatusCode,
      'outboxId': entry.id,
      'at': now.toIso8601String(),
    };
    await syncState.write(
      SyncStateKeys.rejected(table.name, rowId),
      jsonEncode(note),
    );
    await audit.append(
      ctx,
      action: AuditAction.statusChange,
      entityType: entityTypeForTable(table.name),
      entityId: rowId,
      after: {'syncRejected': note},
      reason:
          'sync: local change rejected by the server'
          '${entry.serverStatusCode == null ? '' : ' (${entry.serverStatusCode})'}'
          ' and kept on this device only'
          '${entry.lastError == null ? '' : ': ${entry.lastError}'}',
      at: now,
    );
  }

  Future<Map<String, Object?>?> _loadLocalRow(
    String table,
    String rowId,
  ) async {
    final sync = syncTablesByName[table];
    if (sync == null) return null;
    final parts = sync.splitRowId(rowId);
    final where = sync.keyColumns.map((c) => '"$c" = ?').join(' AND ');
    final row = await db
        .customSelect(
          'SELECT * FROM "$table" WHERE $where',
          variables: [for (final p in parts) Variable.withString(p)],
        )
        .getSingleOrNull();
    return row?.data;
  }

  TableInfo<Table, Object?> _tableInfo(String name) =>
      db.allTables.firstWhere((t) => t.actualTableName == name);
}

/// What [SyncRepairService.discardLocalChange] did.
class SyncRepairOutcome {
  /// Creates the outcome.
  const SyncRepairOutcome({
    this.entriesDiscarded = 0,
    this.rowsRestored = 0,
    this.rowsRejected = 0,
  });

  /// Outbox entries marked discarded.
  final int entriesDiscarded;

  /// Local rows overwritten with the server's copy.
  final int rowsRestored;

  /// Local rows that could not be replaced and were noted as rejected.
  final int rowsRejected;

  @override
  String toString() =>
      'SyncRepairOutcome(discarded: $entriesDiscarded, restored: '
      '$rowsRestored, rejected: $rowsRejected)';
}

/// Domain entity name for a synced SQL table (`patients` -> `Patient`), as
/// used in `audit_events.entity_type`.
String entityTypeForTable(String table) =>
    _entityTypes[table] ??
    table
        .split('_')
        .map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}')
        .join();

const Map<String, String> _entityTypes = {
  'clinics': 'Clinic',
  'clinic_members': 'ClinicMember',
  'chairs': 'Chair',
  'settings': 'Setting',
  'catalog_items': 'CatalogItem',
  'drugs': 'Drug',
  'labs': 'Lab',
  'patients': 'Patient',
  'appointments': 'Appointment',
  'visits': 'Visit',
  'medical_histories': 'MedicalHistory',
  'clinical_notes': 'ClinicalNote',
  'treatment_plans': 'TreatmentPlan',
  'treatment_plan_lines': 'TreatmentPlanLine',
  'procedures': 'Procedure',
  'lab_cases': 'LabCase',
  'tooth_state_records': 'ToothStateRecord',
  'findings': 'Finding',
  'perio_exams': 'PerioExam',
  'estimates': 'Estimate',
  'consent_records': 'ConsentRecord',
  'data_consents': 'DataConsent',
  'image_records': 'ImageRecord',
  'implant_records': 'ImplantRecord',
  'invoices': 'Invoice',
  'payments': 'Payment',
  'adjustments': 'Adjustment',
  'ledger_entries': 'LedgerEntry',
  'prescriptions': 'Prescription',
  'recalls': 'Recall',
  'message_logs': 'MessageLog',
  'sterilisation_cycles': 'SterilisationCycle',
  'licences': 'Licence',
  'audit_events': 'AuditEvent',
};

/// A short label for a local [row] of [table]: a person's name, a document
/// number, a date, the setting key; never free text or a clinical value.
/// Falls back to the row id.
String entityLabelFor(String table, Map<String, Object?>? row, String rowId) {
  if (row == null) return rowId;
  String? s(String column) {
    final v = row[column];
    return v == null || '$v'.isEmpty ? null : '$v';
  }

  final label = switch (table) {
    'patients' =>
      [
            s('first_name'),
            s('last_name'),
          ].whereType<String>().join(' ').trim().ifEmpty(null) ??
          s('patient_number'),
    'clinics' => s('name'),
    'clinic_members' => s('display_name'),
    'chairs' => s('name'),
    'labs' => s('name'),
    'settings' => s('setting_key'),
    'catalog_items' => s('name') ?? s('code'),
    'drugs' => s('generic_name'),
    'appointments' => s('starts_at'),
    'visits' => s('started_at') ?? s('visit_date'),
    'invoices' => s('number'),
    'estimates' => s('number') ?? s('version'),
    'payments' => s('receipt_number') ?? s('paid_at'),
    'prescriptions' => s('issued_at'),
    'procedures' => s('catalog_code') ?? s('name'),
    'treatment_plans' => s('title') ?? s('version'),
    'recalls' => s('due_at') ?? s('recall_type'),
    'lab_cases' => s('case_number') ?? s('sent_at'),
    'sterilisation_cycles' => s('cycle_number'),
    'licences' => s('identifier'),
    'message_logs' => s('template_code'),
    'audit_events' => s('entity_type'),
    _ => null,
  };
  return label ?? rowId;
}

extension on String {
  String? ifEmpty(String? fallback) => isEmpty ? fallback : this;
}
