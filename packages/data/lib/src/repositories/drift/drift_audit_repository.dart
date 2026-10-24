import 'package:ampdent_core/ampdent_core.dart';
import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../../db/converters.dart';
import '../actor_context.dart';
import '../audit_repository.dart';
import 'audited_writer.dart';

/// Drift implementation of [AuditRepository].
class DriftAuditRepository extends DatabaseAccessor<AppDatabase>
    with AuditedWriter
    implements AuditRepository {
  /// Creates the repository over [db].
  DriftAuditRepository(super.db);

  $AuditEventsTable get _t => attachedDatabase.auditEvents;

  @override
  Future<AuditEvent> append(
    ActorContext ctx, {
    required AuditAction action,
    required String entityType,
    required String entityId,
    Map<String, Object?>? before,
    Map<String, Object?>? after,
    String? reason,
    DateTime? at,
  }) async {
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
      occurredAt: nowUtc(at),
    );
    await into(_t).insert(event.toInsertable());
    return event;
  }

  @override
  Future<List<AuditEvent>> forEntity(
    String clinicId,
    String entityType,
    String entityId,
  ) =>
      (select(_t)
            ..where(
              (t) =>
                  t.clinicId.equals(clinicId) &
                  t.entityType.equals(entityType) &
                  t.entityId.equals(entityId),
            )
            ..orderBy([
              (t) => OrderingTerm.asc(t.occurredAt),
              (t) => OrderingTerm.asc(t.rowId),
            ]))
          .get();

  @override
  Future<List<AuditEvent>> forActor(
    String clinicId,
    String actorId, {
    DateTime? from,
    DateTime? to,
    int? limit,
  }) {
    final q = select(_t)
      ..where((t) {
        var where = t.clinicId.equals(clinicId) & t.actorId.equals(actorId);
        if (from != null) {
          where = where & t.occurredAt.isBiggerOrEqualValue(encodeIsoUtc(from));
        }
        if (to != null) {
          where = where & t.occurredAt.isSmallerThanValue(encodeIsoUtc(to));
        }
        return where;
      })
      ..orderBy([
        (t) => OrderingTerm.desc(t.occurredAt),
        (t) => OrderingTerm.desc(t.rowId),
      ]);
    if (limit != null) q.limit(limit);
    return q.get();
  }

  @override
  Future<List<AuditEvent>> inRange(
    String clinicId,
    DateTime from,
    DateTime to, {
    int? limit,
  }) {
    final q = select(_t)
      ..where(
        (t) =>
            t.clinicId.equals(clinicId) &
            t.occurredAt.isBiggerOrEqualValue(encodeIsoUtc(from)) &
            t.occurredAt.isSmallerThanValue(encodeIsoUtc(to)),
      )
      ..orderBy([
        (t) => OrderingTerm.desc(t.occurredAt),
        (t) => OrderingTerm.desc(t.rowId),
      ]);
    if (limit != null) q.limit(limit);
    return q.get();
  }

  @override
  Stream<List<AuditEvent>> watchRecent(String clinicId, {int limit = 100}) =>
      (select(_t)
            ..where((t) => t.clinicId.equals(clinicId))
            ..orderBy([
              (t) => OrderingTerm.desc(t.occurredAt),
              (t) => OrderingTerm.desc(t.rowId),
            ])
            ..limit(limit))
          .watch();

  @override
  Future<int> count(String clinicId) async {
    final c = countAll();
    final row =
        await (selectOnly(_t)
              ..addColumns([c])
              ..where(_t.clinicId.equals(clinicId)))
            .getSingle();
    return row.read(c) ?? 0;
  }
}
