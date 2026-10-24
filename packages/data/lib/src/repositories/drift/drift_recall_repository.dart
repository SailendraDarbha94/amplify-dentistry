import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_terminology/ampdent_terminology.dart';
import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../../db/converters.dart';
import '../actor_context.dart';
import '../recall_repository.dart';
import 'audited_writer.dart';

/// Drift implementation of [RecallRepository].
class DriftRecallRepository extends DatabaseAccessor<AppDatabase>
    with AuditedWriter
    implements RecallRepository {
  /// Creates the repository over [db].
  DriftRecallRepository(super.db);

  $RecallsTable get _t => attachedDatabase.recalls;

  static const List<RecallStatus> _open = [
    RecallStatus.due,
    RecallStatus.notified,
  ];

  Future<Recall> _write(
    ActorContext ctx,
    Recall? before,
    Recall after, {
    AuditAction? action,
    String? reason,
  }) {
    checkTenant(ctx, after.clinicId, 'recall.clinicId');
    return audited(
      ctx: ctx,
      table: _t,
      entityType: 'Recall',
      entityId: after.id,
      before: before,
      after: after,
      insertable: after.toInsertable(),
      toJson: (r) => r.toJson(),
      action: action,
      reason: reason,
    );
  }

  Future<Recall> _transition(
    ActorContext ctx,
    String id,
    Recall Function(Recall before, DateTime now) change, {
    String? reason,
  }) => writeTransaction(() async {
    final before = await getById(id);
    if (before == null) throw StateError('Recall $id not found');
    return _write(
      ctx,
      before,
      change(before, nowUtc()),
      action: AuditAction.statusChange,
      reason: reason,
    );
  });

  @override
  Future<Recall> upsert(ActorContext ctx, Recall recall) => writeTransaction(
    () async => _write(ctx, await getById(recall.id), recall),
  );

  @override
  Future<Recall?> getById(String id) =>
      (select(_t)..where((t) => t.id.equals(id))).getSingleOrNull();

  @override
  Future<List<Recall>> forPatient(String patientId) =>
      (select(_t)
            ..where((t) => t.patientId.equals(patientId))
            ..orderBy([(t) => OrderingTerm.asc(t.dueAt)]))
          .get();

  SimpleSelectStatement<$RecallsTable, Recall> _dueQuery(
    String clinicId,
    DateTime? until,
    int? limit,
  ) {
    final q = select(_t)
      ..where(
        (t) =>
            t.clinicId.equals(clinicId) &
            t.status.isInValues(_open) &
            t.dueAt.isSmallerOrEqualValue(encodeIsoUtc(nowUtc(until))),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.dueAt)]);
    if (limit != null) q.limit(limit);
    return q;
  }

  @override
  Future<List<Recall>> due(String clinicId, {DateTime? until, int? limit}) =>
      _dueQuery(clinicId, until, limit).get();

  @override
  Stream<List<Recall>> watchDue(String clinicId, {DateTime? until}) =>
      _dueQuery(clinicId, until, null).watch();

  @override
  Future<Money> dueValue(String clinicId, {DateTime? until}) async =>
      (await due(clinicId, until: until)).map((r) => r.estimatedValue).total;

  @override
  Future<Recall> markNotified(ActorContext ctx, String id, {DateTime? at}) =>
      _transition(
        ctx,
        id,
        (r, now) => r.copyWith(
          status: RecallStatus.notified,
          lastNotifiedAt: nowUtc(at),
          notifyCount: r.notifyCount + 1,
          updatedAt: now,
        ),
      );

  @override
  Future<Recall> markScheduled(
    ActorContext ctx,
    String id,
    String appointmentId,
  ) => _transition(
    ctx,
    id,
    (r, now) => r.copyWith(
      status: RecallStatus.scheduled,
      appointmentId: appointmentId,
      updatedAt: now,
    ),
  );

  @override
  Future<Recall> markCompleted(ActorContext ctx, String id) => _transition(
    ctx,
    id,
    (r, now) => r.copyWith(status: RecallStatus.completed, updatedAt: now),
  );

  @override
  Future<Recall> dismiss(ActorContext ctx, String id, String reason) =>
      _transition(
        ctx,
        id,
        (r, now) => r.copyWith(status: RecallStatus.dismissed, updatedAt: now),
        reason: reason,
      );

  @override
  Future<Recall?> createFromProcedure(
    ActorContext ctx,
    ProcedureRecord procedure, {
    DateTime? completedOn,
  }) async {
    final seed = procedureSeedByCode(procedure.code);
    if (seed == null) return null;
    final rule = recallRuleFor(seed);
    if (rule == null) return null;
    final from = nowUtc(completedOn ?? procedure.completedAt);
    final now = nowUtc();
    final recall = Recall(
      id: newId(),
      clinicId: procedure.clinicId,
      patientId: procedure.patientId,
      type: RecallType.values.byName(rule.type),
      triggeredByProcedureId: procedure.id,
      dueAt: from.add(Duration(days: rule.dueAfterDays)),
      interval: seed.recallInterval,
      estimatedValue: Money.paise(rule.estimatedValuePaise),
      note: '${seed.name} (${rule.intervalLabel})',
      createdAt: now,
      updatedAt: now,
    );
    return upsert(ctx, recall);
  }
}
