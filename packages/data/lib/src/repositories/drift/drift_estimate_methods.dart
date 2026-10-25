import 'package:ampdent_core/ampdent_core.dart';
import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../actor_context.dart';
import '../treatment_plan_repository.dart';
import 'audited_writer.dart';
import 'settings_access.dart';

/// Estimate half of [TreatmentPlanRepository], mixed into
/// `DriftTreatmentPlanRepository`. Needs the plan reads it declares abstract.
mixin DriftEstimateMethods
    on DatabaseAccessor<AppDatabase>, AuditedWriter, SettingsAccess
    implements TreatmentPlanRepository {
  $EstimatesTable get _estimates => attachedDatabase.estimates;

  // ---------------------------------------------------------------------------
  // Estimates
  // ---------------------------------------------------------------------------

  @override
  Future<List<Estimate>> estimatesForPlan(String planId) =>
      (select(_estimates)
            ..where((t) => t.planId.equals(planId))
            ..orderBy([(t) => OrderingTerm.asc(t.version)]))
          .get();

  @override
  Future<List<Estimate>> estimatesForPatient(String patientId) =>
      (select(_estimates)
            ..where((t) => t.patientId.equals(patientId))
            ..orderBy([(t) => OrderingTerm.desc(t.issuedAt)]))
          .get();

  @override
  Future<Estimate?> getEstimate(String id) =>
      (select(_estimates)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Estimate> _writeEstimate(
    ActorContext ctx,
    Estimate? before,
    Estimate after, {
    AuditAction? action,
  }) => audited(
    ctx: ctx,
    table: _estimates,
    entityType: 'Estimate',
    entityId: after.id,
    before: before,
    after: after,
    insertable: after.toInsertable(),
    toJson: (e) => e.toJson(),
    action: action,
  );

  @override
  Future<Estimate> issueEstimate(ActorContext ctx, Estimate estimate) {
    checkTenant(ctx, estimate.clinicId, 'estimate.clinicId');
    if (estimate.version > 1 && (estimate.justification ?? '').trim().isEmpty) {
      throw ArgumentError.value(
        estimate.justification,
        'justification',
        'required for estimate version ${estimate.version}',
      );
    }
    return writeTransaction(() async {
      final before = await getEstimate(estimate.id);
      var number = estimate.number;
      if (number.isEmpty) number = await mintLocalDraftNumber(ctx, 'EST');
      final after = estimate.copyWith(number: number);
      if (after.planId != null) {
        final previous = await estimatesForPlan(after.planId!);
        for (final p in previous) {
          if (p.id != after.id &&
              p.version < after.version &&
              p.status != EstimateStatus.superseded) {
            await _writeEstimate(
              ctx,
              p,
              p.copyWith(status: EstimateStatus.superseded),
              action: AuditAction.statusChange,
            );
          }
        }
      }
      return _writeEstimate(ctx, before, after);
    });
  }

  @override
  Future<Estimate> estimateFromPlan(
    ActorContext ctx,
    String planId, {
    GstRateTable? rates,
    String? justification,
    DateTime? validUntil,
    DateTime? at,
  }) => writeTransaction(() async {
    final plan = await getPlan(planId);
    if (plan == null) throw StateError('Plan $planId not found');
    checkTenant(ctx, plan.clinicId, 'plan.clinicId');
    final previous = await estimatesForPlan(planId);
    final version = previous.isEmpty
        ? 1
        : previous.map((e) => e.version).reduce((a, b) => a > b ? a : b) + 1;
    if (version > 1 && (justification ?? '').trim().isEmpty) {
      throw ArgumentError.value(
        justification,
        'justification',
        'required for estimate version $version',
      );
    }
    final now = nowUtc(at);
    final table = rates ?? await loadGstRateTable(plan.clinicId);
    final lines = <EstimateLine>[];
    var subtotal = const Money.zero();
    var discountTotal = const Money.zero();
    var taxTotal = const Money.zero();
    var grandTotal = const Money.zero();
    final planLines = await linesForPlan(planId);
    for (final l in planLines) {
      if (l.isAlternative) continue;
      final rate = table.rateFor(l.gstClass, at: now).ratePercent;
      final taxable = l.net;
      final tax = taxable.percent(rate);
      final description = l.tooth == null
          ? l.laymanName
          : '${l.laymanName} (tooth ${l.tooth!.fdi})';
      lines.add(
        EstimateLine(
          description: description,
          tooth: l.tooth,
          quantity: l.quantity,
          unitFee: l.unitFee,
          discount: l.discount,
          gstClass: l.gstClass,
          taxRatePercent: rate,
          lineTotal: taxable + tax,
        ),
      );
      subtotal += l.gross;
      discountTotal += l.discount;
      taxTotal += tax;
      grandTotal += taxable + tax;
    }
    return issueEstimate(
      ctx,
      Estimate(
        id: newId(),
        clinicId: plan.clinicId,
        patientId: plan.patientId,
        planId: planId,
        version: version,
        number: '',
        lines: lines,
        subtotal: subtotal,
        discountTotal: discountTotal,
        taxTotal: taxTotal,
        grandTotal: grandTotal,
        issuedAt: now,
        issuedBy: ctx.actorId,
        justification: justification,
        validUntil: validUntil,
        status: EstimateStatus.issued,
        // Bound to the plan version and lines the patient saw, so acceptance
        // can tell when the plan changed after the estimate was issued.
        planVersion: plan.version,
        planSnapshotHash: computePlanSnapshotHash(plan, planLines),
        createdAt: now,
      ),
    );
  });

  @override
  Future<Estimate> setEstimateStatus(
    ActorContext ctx,
    String id,
    EstimateStatus status,
  ) => writeTransaction(() async {
    final before = await getEstimate(id);
    if (before == null) throw StateError('Estimate $id not found');
    checkTenant(ctx, before.clinicId, 'estimate.clinicId');
    return _writeEstimate(
      ctx,
      before,
      before.copyWith(status: status),
      action: AuditAction.statusChange,
    );
  });
}
