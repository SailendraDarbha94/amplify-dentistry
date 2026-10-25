import 'package:ampdent_core/ampdent_core.dart';
import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../actor_context.dart';
import '../chart_repository.dart';
import 'audited_writer.dart';

/// Drift implementation of [ChartRepository].
class DriftChartRepository extends DatabaseAccessor<AppDatabase>
    with AuditedWriter
    implements ChartRepository {
  /// Creates the repository over [db].
  DriftChartRepository(super.db);

  $ToothStateRecordsTable get _states => attachedDatabase.toothStateRecords;
  $FindingsTable get _findings => attachedDatabase.findings;
  $ProceduresTable get _procedures => attachedDatabase.procedures;
  $ImplantRecordsTable get _implants => attachedDatabase.implantRecords;

  // ---------------------------------------------------------------------------
  // Tooth states
  // ---------------------------------------------------------------------------

  SimpleSelectStatement<$ToothStateRecordsTable, ToothStateRecord>
  _historyQuery(String patientId, {ToothId? tooth}) => select(_states)
    ..where(
      (t) =>
          t.patientId.equals(patientId) &
          (tooth == null ? const Constant(true) : t.tooth.equalsValue(tooth)),
    )
    ..orderBy([
      (t) => OrderingTerm.asc(t.effectiveFrom),
      (t) => OrderingTerm.asc(t.createdAt),
    ]);

  @override
  Future<List<ToothStateRecord>> toothStateHistory(
    String patientId, {
    ToothId? tooth,
  }) => _historyQuery(patientId, tooth: tooth).get();

  @override
  Stream<List<ToothStateRecord>> watchToothStateHistory(String patientId) =>
      _historyQuery(patientId).watch();

  @override
  Future<Map<ToothId, ToothState>> currentStates(String patientId) async =>
      currentToothStates(await toothStateHistory(patientId));

  @override
  Stream<Map<ToothId, ToothState>> watchCurrentStates(String patientId) =>
      watchToothStateHistory(patientId).map(currentToothStates);

  @override
  Future<ToothStateRecord> recordToothState(
    ActorContext ctx,
    ToothStateRecord record,
  ) {
    checkTenant(ctx, record.clinicId, 'record.clinicId');
    return writeTransaction(
      () async => audited<ToothStateRecord>(
        ctx: ctx,
        table: _states,
        entityType: 'ToothStateRecord',
        entityId: record.id,
        before: null,
        after: record,
        insertable: record.toInsertable(),
        toJson: (r) => r.toJson(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Findings
  // ---------------------------------------------------------------------------

  SimpleSelectStatement<$FindingsTable, Finding> _findingQuery(
    String patientId,
    bool includeDeleted,
  ) => select(_findings)
    ..where(
      (t) =>
          t.patientId.equals(patientId) &
          (includeDeleted
              ? const Constant(true)
              : t.status.equalsValue(FindingStatus.deleted).not()),
    )
    ..orderBy([(t) => OrderingTerm.desc(t.recordedAt)]);

  @override
  Future<List<Finding>> findings(
    String patientId, {
    bool includeDeleted = false,
  }) => _findingQuery(patientId, includeDeleted).get();

  @override
  Stream<List<Finding>> watchFindings(
    String patientId, {
    bool includeDeleted = false,
  }) => _findingQuery(patientId, includeDeleted).watch();

  @override
  Future<Finding?> getFinding(String id) =>
      (select(_findings)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Finding> _writeFinding(
    ActorContext ctx,
    Finding? before,
    Finding after, {
    AuditAction? action,
    String? reason,
  }) {
    checkTenant(ctx, after.clinicId, 'finding.clinicId');
    return audited(
      ctx: ctx,
      table: _findings,
      entityType: 'Finding',
      entityId: after.id,
      before: before,
      after: after,
      insertable: after.toInsertable(),
      toJson: (f) => f.toJson(),
      action: action,
      reason: reason,
    );
  }

  @override
  Future<Finding> addFinding(ActorContext ctx, Finding finding) =>
      writeTransaction(() => _writeFinding(ctx, null, finding));

  @override
  Future<Finding> updateFinding(ActorContext ctx, Finding finding) =>
      writeTransaction(() async {
        final before = await getFinding(finding.id);
        if (before == null) throw StateError('Finding ${finding.id} not found');
        return _writeFinding(ctx, before, finding);
      });

  @override
  Future<Finding> resolveFinding(
    ActorContext ctx,
    String id, {
    String? procedureId,
    DateTime? at,
  }) => writeTransaction(() async {
    final before = await getFinding(id);
    if (before == null) throw StateError('Finding $id not found');
    final now = nowUtc(at);
    final after = before.copyWith(
      status: FindingStatus.resolved,
      resolvedAt: now,
      resolvedByProcedureId: procedureId,
      updatedAt: now,
    );
    return _writeFinding(ctx, before, after, action: AuditAction.statusChange);
  });

  @override
  Future<Finding> deleteFinding(ActorContext ctx, String id, String reason) =>
      writeTransaction(() async {
        final before = await getFinding(id);
        if (before == null) throw StateError('Finding $id not found');
        final after = before.copyWith(
          status: FindingStatus.deleted,
          updatedAt: nowUtc(),
        );
        return _writeFinding(
          ctx,
          before,
          after,
          action: AuditAction.softDelete,
          reason: reason,
        );
      });

  // ---------------------------------------------------------------------------
  // Procedures
  // ---------------------------------------------------------------------------

  @override
  Future<ProcedureRecord?> getProcedure(String id) =>
      (select(_procedures)..where((t) => t.id.equals(id))).getSingleOrNull();

  SimpleSelectStatement<$ProceduresTable, ProcedureRecord> _procedureQuery(
    String patientId, {
    Iterable<ProcedureStatus>? statuses,
    bool includeDeleted = false,
  }) => select(_procedures)
    ..where((t) {
      var where = t.patientId.equals(patientId);
      if (statuses != null) {
        where = where & t.status.isInValues(statuses.toList());
      } else if (!includeDeleted) {
        where = where & t.status.equalsValue(ProcedureStatus.deleted).not();
      }
      return where;
    })
    ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

  @override
  Future<List<ProcedureRecord>> proceduresForPatient(
    String patientId, {
    Iterable<ProcedureStatus>? statuses,
    bool includeDeleted = false,
  }) => _procedureQuery(
    patientId,
    statuses: statuses,
    includeDeleted: includeDeleted,
  ).get();

  @override
  Stream<List<ProcedureRecord>> watchProceduresForPatient(
    String patientId, {
    bool includeDeleted = false,
  }) => _procedureQuery(patientId, includeDeleted: includeDeleted).watch();

  Future<ProcedureRecord> _writeProcedure(
    ActorContext ctx,
    ProcedureRecord? before,
    ProcedureRecord after, {
    AuditAction? action,
    String? reason,
  }) {
    checkTenant(ctx, after.clinicId, 'procedure.clinicId');
    return audited(
      ctx: ctx,
      table: _procedures,
      entityType: 'ProcedureRecord',
      entityId: after.id,
      before: before,
      after: after,
      insertable: after.toInsertable(),
      toJson: (p) => p.toJson(),
      action: action,
      reason: reason,
    );
  }

  @override
  Future<ProcedureRecord> createProcedure(
    ActorContext ctx,
    ProcedureRecord procedure,
  ) => writeTransaction(() async {
    final existing = await getProcedure(procedure.id);
    if (existing != null) {
      throw StateError('Procedure ${procedure.id} already exists');
    }
    return _writeProcedure(ctx, null, procedure);
  });

  @override
  Future<ProcedureRecord> updateProcedure(
    ActorContext ctx,
    ProcedureRecord procedure,
  ) => writeTransaction(() async {
    final before = await getProcedure(procedure.id);
    if (before == null) {
      throw StateError('Procedure ${procedure.id} not found');
    }
    return _writeProcedure(ctx, before, procedure);
  });

  @override
  Future<ProcedureRecord> setProcedureStatus(
    ActorContext ctx,
    String id,
    ProcedureStatus status, {
    String? reason,
    DateTime? at,
  }) => writeTransaction(() async {
    final before = await getProcedure(id);
    if (before == null) throw StateError('Procedure $id not found');
    if (before.status == status) {
      throw StateError('Procedure $id is already ${status.name}');
    }
    if (status == ProcedureStatus.deleted && (reason ?? '').isEmpty) {
      throw ArgumentError.value(reason, 'reason', 'required to delete');
    }
    final now = nowUtc(at);
    final after = before.copyWith(
      status: status,
      acceptedAt: status == ProcedureStatus.accepted ? now : null,
      startedAt: status == ProcedureStatus.inProgress ? now : null,
      completedAt: status == ProcedureStatus.completed ? now : null,
      updatedAt: now,
    );
    return _writeProcedure(
      ctx,
      before,
      after,
      action: status == ProcedureStatus.deleted
          ? AuditAction.softDelete
          : AuditAction.statusChange,
      reason: reason,
    );
  });

  @override
  Future<ProcedureRecord> advanceStage(
    ActorContext ctx,
    String id, {
    DateTime? at,
  }) => writeTransaction(() async {
    final before = await getProcedure(id);
    if (before == null) throw StateError('Procedure $id not found');
    if (before.status == ProcedureStatus.completed ||
        before.status == ProcedureStatus.deleted) {
      throw StateError('Procedure $id is ${before.status.name}');
    }
    final now = nowUtc(at);
    final isFirst = before.status != ProcedureStatus.inProgress;
    final nextIndex = isFirst ? before.stageIndex : before.stageIndex + 1;
    final isLast = nextIndex >= before.totalStages - 1;
    final after = before.copyWith(
      stageIndex: nextIndex.clamp(0, before.totalStages - 1),
      status: isLast ? ProcedureStatus.completed : ProcedureStatus.inProgress,
      startedAt: before.startedAt ?? now,
      completedAt: isLast ? now : null,
      updatedAt: now,
    );
    return _writeProcedure(
      ctx,
      before,
      after,
      action: AuditAction.statusChange,
    );
  });

  @override
  Future<ProcedureRecord> deleteProcedure(
    ActorContext ctx,
    String id,
    String reason,
  ) => setProcedureStatus(ctx, id, ProcedureStatus.deleted, reason: reason);

  // ---------------------------------------------------------------------------
  // Implants
  // ---------------------------------------------------------------------------

  @override
  Future<List<ImplantRecord>> implantsForPatient(String patientId) =>
      (select(_implants)
            ..where((t) => t.patientId.equals(patientId))
            ..orderBy([(t) => OrderingTerm.desc(t.placedAt)]))
          .get();

  @override
  Future<ImplantRecord> upsertImplant(ActorContext ctx, ImplantRecord implant) {
    checkTenant(ctx, implant.clinicId, 'implant.clinicId');
    return writeTransaction(
      () async => audited(
        ctx: ctx,
        table: _implants,
        entityType: 'ImplantRecord',
        entityId: implant.id,
        before: await (select(
          _implants,
        )..where((t) => t.id.equals(implant.id))).getSingleOrNull(),
        after: implant,
        insertable: implant.toInsertable(),
        toJson: (i) => i.toJson(),
      ),
    );
  }
}
