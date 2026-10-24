import 'package:ampdent_core/ampdent_core.dart';
import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../actor_context.dart';
import '../lab_repository.dart';
import 'audited_writer.dart';

/// Drift implementation of [LabRepository].
class DriftLabRepository extends DatabaseAccessor<AppDatabase>
    with AuditedWriter
    implements LabRepository {
  /// Creates the repository over [db].
  DriftLabRepository(super.db);

  $LabsTable get _labs => attachedDatabase.labs;
  $LabCasesTable get _cases => attachedDatabase.labCases;

  /// Default turnaround when neither the call nor the lab specifies one.
  static const int defaultTurnaroundWorkingDays = 7;

  // ---------------------------------------------------------------------------
  // Labs
  // ---------------------------------------------------------------------------

  @override
  Future<Lab> upsertLab(ActorContext ctx, Lab lab) {
    checkTenant(ctx, lab.clinicId, 'lab.clinicId');
    return writeTransaction(
      () async => audited(
        ctx: ctx,
        table: _labs,
        entityType: 'Lab',
        entityId: lab.id,
        before: await getLab(lab.id),
        after: lab,
        insertable: lab.toInsertable(),
        toJson: (l) => l.toJson(),
      ),
    );
  }

  @override
  Future<Lab?> getLab(String id) =>
      (select(_labs)..where((t) => t.id.equals(id))).getSingleOrNull();

  @override
  Future<List<Lab>> labs(String clinicId, {bool includeInactive = false}) =>
      (select(_labs)
            ..where(
              (t) =>
                  t.clinicId.equals(clinicId) &
                  (includeInactive
                      ? const Constant(true)
                      : t.isActive.equals(true)),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();

  @override
  Future<Lab> deactivateLab(ActorContext ctx, String id) =>
      writeTransaction(() async {
        final before = await getLab(id);
        if (before == null) throw StateError('Lab $id not found');
        checkTenant(ctx, before.clinicId, 'lab.clinicId');
        final after = before.copyWith(isActive: false);
        return audited(
          ctx: ctx,
          table: _labs,
          entityType: 'Lab',
          entityId: id,
          before: before,
          after: after,
          insertable: after.toInsertable(),
          toJson: (l) => l.toJson(),
          action: AuditAction.softDelete,
        );
      });

  // ---------------------------------------------------------------------------
  // Cases
  // ---------------------------------------------------------------------------

  Future<LabCase> _write(
    ActorContext ctx,
    LabCase? before,
    LabCase after, {
    AuditAction? action,
    String? reason,
  }) {
    checkTenant(ctx, after.clinicId, 'labCase.clinicId');
    return audited(
      ctx: ctx,
      table: _cases,
      entityType: 'LabCase',
      entityId: after.id,
      before: before,
      after: after,
      insertable: after.toInsertable(),
      toJson: (c) => c.toJson(),
      action: action,
      reason: reason,
    );
  }

  Future<LabCase> _transition(
    ActorContext ctx,
    String id,
    LabCase Function(LabCase before, DateTime now) change, {
    DateTime? at,
    String? reason,
  }) => writeTransaction(() async {
    final before = await getCase(id);
    if (before == null) throw StateError('Lab case $id not found');
    return _write(
      ctx,
      before,
      change(before, nowUtc(at)),
      action: AuditAction.statusChange,
      reason: reason,
    );
  });

  @override
  Future<LabCase> createCase(ActorContext ctx, LabCase labCase) =>
      writeTransaction(() async {
        if (await getCase(labCase.id) != null) {
          throw StateError('Lab case ${labCase.id} already exists');
        }
        return _write(ctx, null, labCase);
      });

  @override
  Future<LabCase> updateCase(ActorContext ctx, LabCase labCase) =>
      writeTransaction(() async {
        final before = await getCase(labCase.id);
        if (before == null) {
          throw StateError('Lab case ${labCase.id} not found');
        }
        return _write(ctx, before, labCase);
      });

  @override
  Future<LabCase?> getCase(String id) =>
      (select(_cases)..where((t) => t.id.equals(id))).getSingleOrNull();

  @override
  Future<List<LabCase>> casesForPatient(String patientId) =>
      (select(_cases)
            ..where((t) => t.patientId.equals(patientId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  SimpleSelectStatement<$LabCasesTable, LabCase> _openQuery(String clinicId) =>
      select(_cases)
        ..where(
          (t) =>
              t.clinicId.equals(clinicId) &
              t.status.isInValues(
                LabCaseStatus.values.where((s) => s.isOpen).toList(),
              ),
        )
        ..orderBy([
          (t) => OrderingTerm.asc(t.dueAt),
          (t) => OrderingTerm.asc(t.createdAt),
        ]);

  @override
  Future<List<LabCase>> openCases(String clinicId) =>
      _openQuery(clinicId).get();

  @override
  Stream<List<LabCase>> watchOpenCases(String clinicId) =>
      _openQuery(clinicId).watch();

  @override
  Future<List<LabCase>> overdueCases(String clinicId, {DateTime? asOf}) async {
    final now = nowUtc(asOf);
    return (await openCases(clinicId)).where((c) => c.isOverdue(now)).toList();
  }

  @override
  Future<LabCase> markSent(
    ActorContext ctx,
    String id, {
    DateTime? at,
    int? turnaroundWorkingDays,
    Set<DateTime> holidays = const {},
  }) => writeTransaction(() async {
    final before = await getCase(id);
    if (before == null) throw StateError('Lab case $id not found');
    final lab = await getLab(before.labId);
    final turnaround =
        turnaroundWorkingDays ??
        lab?.turnaroundFor(before.caseType) ??
        defaultTurnaroundWorkingDays;
    final now = nowUtc(at);
    return _write(
      ctx,
      before,
      before.copyWith(
        status: LabCaseStatus.sent,
        sentAt: now,
        dueAt: computeDueDate(now, turnaround, holidays: holidays),
        updatedAt: now,
      ),
      action: AuditAction.statusChange,
    );
  });

  @override
  Future<LabCase> markReceived(ActorContext ctx, String id, {DateTime? at}) =>
      _transition(
        ctx,
        id,
        (c, now) => c.copyWith(
          status: LabCaseStatus.received,
          receivedAt: now,
          updatedAt: now,
        ),
        at: at,
      );

  @override
  Future<LabCase> markQualityChecked(
    ActorContext ctx,
    String id, {
    DateTime? at,
  }) => _transition(
    ctx,
    id,
    (c, now) => c.copyWith(
      status: LabCaseStatus.qualityChecked,
      qualityCheckedAt: now,
      updatedAt: now,
    ),
    at: at,
  );

  @override
  Future<LabCase> markFitted(ActorContext ctx, String id, {DateTime? at}) =>
      _transition(
        ctx,
        id,
        (c, now) => c.copyWith(
          status: LabCaseStatus.fitted,
          fittedAt: now,
          updatedAt: now,
        ),
        at: at,
      );

  @override
  Future<LabCase> requestRemake(
    ActorContext ctx,
    String id, {
    required String reason,
    DateTime? at,
  }) {
    if (reason.trim().isEmpty) {
      throw ArgumentError.value(reason, 'reason', 'required for a remake');
    }
    return writeTransaction(() async {
      final before = await getCase(id);
      if (before == null) throw StateError('Lab case $id not found');
      final now = nowUtc(at);
      await _write(
        ctx,
        before,
        before.copyWith(
          status: LabCaseStatus.remakeRequested,
          remakeReason: reason,
          updatedAt: now,
        ),
        action: AuditAction.statusChange,
        reason: reason,
      );
      final remake = LabCase(
        id: newId(),
        clinicId: before.clinicId,
        patientId: before.patientId,
        procedureId: before.procedureId,
        labId: before.labId,
        caseType: before.caseType,
        teeth: before.teeth,
        material: before.material,
        shade: before.shade,
        impressionType: before.impressionType,
        instructions: before.instructions,
        labFee: before.labFee,
        createdAt: now,
        remakeReason: reason,
        remakeOfCaseId: before.id,
        updatedAt: now,
      );
      return _write(ctx, null, remake);
    });
  }

  @override
  Future<LabCase> cancelCase(ActorContext ctx, String id, String reason) =>
      _transition(
        ctx,
        id,
        (c, now) => c.copyWith(status: LabCaseStatus.cancelled, updatedAt: now),
        reason: reason,
      );
}
