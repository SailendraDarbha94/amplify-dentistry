/// Append-only write discipline shared by every Drift repository.
library;

import 'package:ampdent_core/ampdent_core.dart';
import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../../db/tables_clinic.dart';
import '../actor_context.dart';
import 'repository_exception.dart';

/// SQL names of the tables whose rows are never rewritten: an id that already
/// exists is rejected by [AuditedWriter.ensureAbsent] instead of being
/// overwritten through `insertOnConflictUpdate`.
const Set<String> appendOnlyTables = {
  'consent_records',
  'data_consents',
  'payments',
  'ledger_entries',
  'prescriptions',
  'tooth_state_records',
  'audit_events',
  'medical_histories',
  'perio_exams',
  'sterilisation_cycles',
};

/// Mixin for Drift repositories: every write goes through [audited] or
/// [recordWrite], which, inside the same transaction, appends an
/// [AuditEvent] (actor, action, entity, before/after JSON) and a
/// `sync_outbox` row carrying the row's JSON after the write.
///
/// No method here deletes anything; soft deletes are status changes recorded
/// with [AuditAction.softDelete].
mixin AuditedWriter on DatabaseAccessor<AppDatabase> {
  static const Logger _log = Logger('AuditedWriter');

  /// Current UTC time, or [at] normalised to UTC.
  DateTime nowUtc([DateTime? at]) => (at ?? DateTime.now()).toUtc();

  /// Runs [body] in one transaction (nested calls join the outer one).
  ///
  /// A SQLite failure is rethrown as a [RepositoryException], which carries
  /// the result code, table and constraint identifiers but not the bound
  /// values, so nothing downstream can log patient data by printing the
  /// error. Application errors ([StateError], [ArgumentError]) pass through.
  Future<T> writeTransaction<T>(Future<T> Function() body) async {
    try {
      return await transaction(body);
    } catch (e, st) {
      final safe = RepositoryException.sanitise(e);
      if (safe == null) rethrow;
      _log.warning('write failed: $safe');
      Error.throwWithStackTrace(safe, st);
    }
  }

  /// Throws [StateError] when [table] already holds a row with [id]. Call
  /// before inserting into an append-only table (see [appendOnlyTables]);
  /// [audited] does so itself for a create on one of those tables.
  Future<void> ensureAbsent(TableInfo<Table, Object?> table, String id) async {
    final name = table.actualTableName;
    final rows = await customSelect(
      'SELECT 1 FROM "$name" WHERE id = ? LIMIT 1',
      variables: [Variable.withString(id)],
      readsFrom: {table},
    ).get();
    if (rows.isNotEmpty) {
      throw StateError('$name is append-only: row $id already exists');
    }
  }

  /// Throws [ArgumentError] when a row's clinic differs from the actor's.
  void checkTenant(ActorContext ctx, String? clinicId, String what) {
    if (clinicId != null && clinicId != ctx.clinicId) {
      throw ArgumentError.value(
        clinicId,
        what,
        'belongs to another clinic than the actor (${ctx.clinicId})',
      );
    }
  }

  /// Appends the audit event and outbox row for a write that has already
  /// been applied to [table]. Call inside the transaction that did the write.
  /// `occurredAt` is always the device clock at write time, never the
  /// business time of the entity, so the log orders by write order.
  Future<AuditEvent> recordWrite({
    required ActorContext ctx,
    required AuditAction action,
    required String entityType,
    required String entityId,
    required TableInfo<Table, Object?> table,
    Map<String, Object?>? before,
    Map<String, Object?>? after,
    String? reason,
  }) async {
    final occurredAt = nowUtc();
    final event = AuditEvent(
      id: newId(),
      clinicId: ctx.clinicId,
      actorId: ctx.actorId,
      action: action,
      entityType: entityType,
      entityId: entityId,
      before: before,
      after: after,
      reason: reason,
      deviceId: ctx.deviceId,
      occurredAt: occurredAt,
    );
    await into(attachedDatabase.auditEvents).insert(event.toInsertable());
    if (after != null) {
      await into(attachedDatabase.syncOutbox).insert(
        SyncOutboxCompanion.insert(
          id: newId(),
          clinicId: ctx.clinicId,
          targetTable: table.actualTableName,
          rowId: entityId,
          operation: before == null
              ? OutboxOperation.insert
              : OutboxOperation.update,
          payload: after,
          createdAt: occurredAt,
        ),
      );
    }
    return event;
  }

  /// Upserts [after] into [table] and records the write. [before] is the
  /// stored row prior to the write (null for a create). The action defaults
  /// to create/update by presence of [before]. On an [appendOnlyTables]
  /// table a create whose id already exists throws [StateError] instead of
  /// silently overwriting the row.
  Future<T> audited<T>({
    required ActorContext ctx,
    required TableInfo<Table, T> table,
    required String entityType,
    required String entityId,
    required T? before,
    required T after,
    required Insertable<T> insertable,
    required Map<String, Object?> Function(T) toJson,
    AuditAction? action,
    String? reason,
  }) async {
    if (before == null && appendOnlyTables.contains(table.actualTableName)) {
      await ensureAbsent(table, entityId);
    }
    await into(table).insertOnConflictUpdate(insertable);
    await recordWrite(
      ctx: ctx,
      action:
          action ?? (before == null ? AuditAction.create : AuditAction.update),
      entityType: entityType,
      entityId: entityId,
      table: table,
      before: before == null ? null : toJson(before),
      after: toJson(after),
      reason: reason,
    );
    return after;
  }

  /// Records a read-type action (view, export, print, share) that touches no
  /// row and therefore adds no outbox entry.
  Future<AuditEvent> recordAccess({
    required ActorContext ctx,
    required AuditAction action,
    required String entityType,
    required String entityId,
    String? reason,
  }) async {
    final event = AuditEvent(
      id: newId(),
      clinicId: ctx.clinicId,
      actorId: ctx.actorId,
      action: action,
      entityType: entityType,
      entityId: entityId,
      reason: reason,
      deviceId: ctx.deviceId,
      occurredAt: nowUtc(),
    );
    await into(attachedDatabase.auditEvents).insert(event.toInsertable());
    return event;
  }
}
