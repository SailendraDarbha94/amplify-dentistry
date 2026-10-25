import 'package:ampdent_core/ampdent_core.dart';
import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../actor_context.dart';
import '../treatment_plan_repository.dart';
import 'audited_writer.dart';
import 'drift_estimate_methods.dart';
import 'settings_access.dart';

/// Drift implementation of [TreatmentPlanRepository].
class DriftTreatmentPlanRepository extends DatabaseAccessor<AppDatabase>
    with AuditedWriter, SettingsAccess, DriftEstimateMethods
    implements TreatmentPlanRepository {
  /// Creates the repository over [db].
  DriftTreatmentPlanRepository(super.db);

  $TreatmentPlansTable get _plans => attachedDatabase.treatmentPlans;
  $TreatmentPlanLinesTable get _lines => attachedDatabase.treatmentPlanLines;

  /// Hand-written companion: the table carries `removedAt`, which the entity
  /// does not, so drift cannot generate `toInsertable()` for it.
  TreatmentPlanLinesCompanion _lineCompanion(
    TreatmentPlanLine l, {
    DateTime? removedAt,
  }) => TreatmentPlanLinesCompanion.insert(
    id: l.id,
    planId: l.planId,
    clinicId: l.clinicId,
    patientId: l.patientId,
    catalogItemId: l.catalogItemId,
    code: l.code,
    name: l.name,
    laymanName: l.laymanName,
    tooth: Value(l.tooth),
    teeth: l.teeth,
    surfaces: l.surfaces,
    treatmentArea: l.treatmentArea,
    phaseIndex: l.phaseIndex,
    sequence: l.sequence,
    quantity: l.quantity,
    unitFee: l.unitFee,
    discount: l.discount,
    gstClass: l.gstClass,
    isAlternative: l.isAlternative,
    alternativeGroup: Value(l.alternativeGroup),
    procedureId: Value(l.procedureId),
    note: Value(l.note),
    removedAt: Value(removedAt),
  );

  // ---------------------------------------------------------------------------
  // Plans
  // ---------------------------------------------------------------------------

  @override
  Future<TreatmentPlan?> getPlan(String planId) =>
      (select(_plans)..where((t) => t.id.equals(planId))).getSingleOrNull();

  SimpleSelectStatement<$TreatmentPlanLinesTable, TreatmentPlanLine> _liveLines(
    String planId,
  ) => select(_lines)
    ..where((t) => t.planId.equals(planId) & t.removedAt.isNull())
    ..orderBy([
      (t) => OrderingTerm.asc(t.phaseIndex),
      (t) => OrderingTerm.asc(t.sequence),
    ]);

  @override
  Future<List<TreatmentPlanLine>> linesForPlan(String planId) =>
      _liveLines(planId).get();

  @override
  Stream<List<TreatmentPlanLine>> watchLines(String planId) =>
      _liveLines(planId).watch();

  @override
  Stream<List<TreatmentPlan>> watchPlans(String patientId) =>
      (select(_plans)
            ..where((t) => t.patientId.equals(patientId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  @override
  Future<TreatmentPlan?> activePlan(String patientId) =>
      (select(_plans)
            ..where(
              (t) =>
                  t.patientId.equals(patientId) &
                  t.status.equalsValue(TreatmentPlanStatus.active),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(1))
          .getSingleOrNull();

  Future<TreatmentPlan> _writePlan(
    ActorContext ctx,
    TreatmentPlan? before,
    TreatmentPlan after, {
    AuditAction? action,
    String? reason,
  }) {
    checkTenant(ctx, after.clinicId, 'plan.clinicId');
    return audited(
      ctx: ctx,
      table: _plans,
      entityType: 'TreatmentPlan',
      entityId: after.id,
      before: before,
      after: after,
      insertable: after.toInsertable(),
      toJson: (p) => p.toJson(),
      action: action,
      reason: reason,
    );
  }

  Future<void> _writeLine(
    ActorContext ctx,
    TreatmentPlanLine? before,
    TreatmentPlanLine after, {
    DateTime? removedAt,
    AuditAction? action,
  }) async {
    await into(_lines)
        .insertOnConflictUpdate(_lineCompanion(after, removedAt: removedAt));
    final afterJson = after.toJson();
    if (removedAt != null) afterJson['removedAt'] = dateToJson(removedAt);
    await recordWrite(
      ctx: ctx,
      action:
          action ?? (before == null ? AuditAction.create : AuditAction.update),
      entityType: 'TreatmentPlanLine',
      entityId: after.id,
      table: _lines,
      before: before?.toJson(),
      after: afterJson,
    );
  }

  @override
  Future<TreatmentPlan> savePlan(
    ActorContext ctx,
    TreatmentPlan plan,
    List<TreatmentPlanLine> lines,
  ) {
    checkTenant(ctx, plan.clinicId, 'plan.clinicId');
    for (final l in lines) {
      if (l.planId != plan.id || l.patientId != plan.patientId) {
        throw ArgumentError.value(
          l.id,
          'lines',
          'line belongs to another plan',
        );
      }
    }
    return writeTransaction(() async {
      final before = await getPlan(plan.id);
      if (before != null && before.isAccepted) {
        throw StateError('Plan ${plan.id} is accepted; revise it instead');
      }
      final saved = await _writePlan(ctx, before, plan);
      final existing = {for (final l in await linesForPlan(plan.id)) l.id: l};
      final keep = {for (final l in lines) l.id};
      final now = nowUtc();
      for (final old in existing.values) {
        if (!keep.contains(old.id)) {
          await _writeLine(
            ctx,
            old,
            old,
            removedAt: now,
            action: AuditAction.softDelete,
          );
        }
      }
      for (final l in lines) {
        await _writeLine(ctx, existing[l.id], l);
      }
      return saved;
    });
  }

  @override
  Future<TreatmentPlan> activatePlan(ActorContext ctx, String planId) =>
      writeTransaction(() async {
        final plan = await getPlan(planId);
        if (plan == null) throw StateError('Plan $planId not found');
        final now = nowUtc();
        final others =
            await (select(_plans)..where(
                  (t) =>
                      t.patientId.equals(plan.patientId) &
                      t.status.equalsValue(TreatmentPlanStatus.active) &
                      t.id.equals(planId).not(),
                ))
                .get();
        for (final o in others) {
          await _writePlan(
            ctx,
            o,
            o.copyWith(status: TreatmentPlanStatus.inactive, updatedAt: now),
            action: AuditAction.statusChange,
          );
        }
        return _writePlan(
          ctx,
          plan,
          plan.copyWith(status: TreatmentPlanStatus.active, updatedAt: now),
          action: AuditAction.statusChange,
        );
      });

  @override
  Future<TreatmentPlan> setPlanStatus(
    ActorContext ctx,
    String planId,
    TreatmentPlanStatus status,
  ) => writeTransaction(() async {
    final plan = await getPlan(planId);
    if (plan == null) throw StateError('Plan $planId not found');
    return _writePlan(
      ctx,
      plan,
      plan.copyWith(status: status, updatedAt: nowUtc()),
      action: AuditAction.statusChange,
    );
  });

  @override
  Future<TreatmentPlan> acceptPlan(
    ActorContext ctx,
    String planId, {
    required String signerName,
    String? signatureHash,
    String? estimateDeclinedReason,
    DateTime? at,
  }) => writeTransaction(() async {
    final plan = await getPlan(planId);
    if (plan == null) throw StateError('Plan $planId not found');
    if (plan.isAccepted) throw StateError('Plan $planId already accepted');
    final lines = await linesForPlan(planId);
    final now = nowUtc(at);
    final declined = estimateDeclinedReason?.trim();
    final after = plan.copyWith(
      status: TreatmentPlanStatus.accepted,
      acceptedAt: now,
      acceptedBySignerName: signerName,
      acceptedSignatureHash: signatureHash,
      snapshotHash: computePlanSnapshotHash(plan, lines),
      estimateDeclinedReason: declined == null || declined.isEmpty
          ? null
          : declined,
      updatedAt: now,
    );
    return _writePlan(
      ctx,
      plan,
      after,
      action: AuditAction.statusChange,
      reason: declined == null || declined.isEmpty
          ? null
          : 'Patient declined a written estimate: $declined',
    );
  });

  @override
  Future<TreatmentPlan> revisePlan(
    ActorContext ctx,
    String planId, {
    String? title,
  }) => writeTransaction(() async {
    final old = await getPlan(planId);
    if (old == null) throw StateError('Plan $planId not found');
    final now = nowUtc();
    final next = TreatmentPlan(
      id: newId(),
      clinicId: old.clinicId,
      patientId: old.patientId,
      title: title ?? old.title,
      phases: old.phases,
      version: old.version + 1,
      supersedesPlanId: old.id,
      createdBy: ctx.actorId,
      createdAt: now,
      updatedAt: now,
    );
    final lines = [
      for (final l in await linesForPlan(planId))
        TreatmentPlanLine(
          id: newId(),
          planId: next.id,
          clinicId: l.clinicId,
          patientId: l.patientId,
          catalogItemId: l.catalogItemId,
          code: l.code,
          name: l.name,
          laymanName: l.laymanName,
          tooth: l.tooth,
          teeth: l.teeth,
          surfaces: l.surfaces,
          treatmentArea: l.treatmentArea,
          phaseIndex: l.phaseIndex,
          sequence: l.sequence,
          quantity: l.quantity,
          unitFee: l.unitFee,
          discount: l.discount,
          gstClass: l.gstClass,
          isAlternative: l.isAlternative,
          alternativeGroup: l.alternativeGroup,
          procedureId: l.procedureId,
          note: l.note,
        ),
    ];
    await _writePlan(
      ctx,
      old,
      old.copyWith(status: TreatmentPlanStatus.superseded, updatedAt: now),
      action: AuditAction.statusChange,
    );
    return savePlan(ctx, next, lines);
  });
}
