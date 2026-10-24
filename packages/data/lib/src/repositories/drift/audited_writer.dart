/// Append-only write discipline shared by every Drift repository.
library;

import 'package:ampdent_core/ampdent_core.dart';
import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../../db/tables_clinic.dart';
import '../actor_context.dart';

/// Mixin for Drift repositories: every write goes through [audited] or
/// [recordWrite], which, inside the same transaction, appends an
/// [AuditEvent] (actor, action, entity, before/after JSON) and a
/// `sync_outbox` row carrying the row's JSON after the write.
///
/// No method here deletes anything; soft deletes are status changes recorded
/// with [AuditAction.softDelete].
mixin AuditedWriter on DatabaseAccessor<AppDatabase> {
  /// Current UTC time, or [at] normalised to UTC.
  DateTime nowUtc([DateTime? at]) => (at ?? DateTime.now()).toUtc();

  /// Runs [body] in one transaction (nested calls join the outer one).
  Future<T> writeTransaction<T>(Future<T> Function() body) => transaction(body);

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
  /// to create/update by presence of [before].
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
