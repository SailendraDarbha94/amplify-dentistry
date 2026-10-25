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

  @override
  Future<Recall?> forProcedure(String procedureId) =>
      (select(_t)
            ..where((t) => t.triggeredByProcedureId.equals(procedureId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
            ..limit(1))
          .getSingleOrNull();

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
  }) {
    final seed = procedureSeedByCode(procedure.code);
    if (seed == null) return Future.value();
    final rule = recallRuleFor(seed);
    if (rule == null) return Future.value();
    checkTenant(ctx, procedure.clinicId, 'procedure.clinicId');
    return writeTransaction(() async {
      // Idempotent per triggering procedure (which fixes patient and type):
      // the lookup and the insert share one transaction.
      final existing = await forProcedure(procedure.id);
      if (existing != null) return existing;
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
      final written = await _write(ctx, null, recall);
      await _supersedeOlderOpen(ctx, written);
      return written;
    });
  }

  /// Closes every other open recall of the same type for the patient: a
  /// later completion of the same kind of procedure replaces the earlier
  /// recall instead of leaving two due rows that double the overdue KPI and
  /// the reminders. The audit reason names the superseding recall.
  Future<void> _supersedeOlderOpen(ActorContext ctx, Recall newer) async {
    final older =
        await (select(_t)..where(
              (t) =>
                  t.clinicId.equals(newer.clinicId) &
                  t.patientId.equals(newer.patientId) &
                  t.type.equalsValue(newer.type) &
                  t.status.isInValues(_open) &
                  t.id.equals(newer.id).not(),
            ))
            .get();
    for (final r in older) {
      await _write(
        ctx,
        r,
        r.copyWith(status: RecallStatus.dismissed, updatedAt: nowUtc()),
        action: AuditAction.statusChange,
        reason: 'superseded by recall ${newer.id}',
      );
    }
  }
}
