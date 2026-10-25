import 'dart:typed_data';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_documents/ampdent_documents.dart';
import 'package:ampdent_mobile/features/consent/consent_model.dart';

import 'plan_model.dart';

/// Repository orchestration for plans: create, save (materialising chart
/// procedures for every line), present, estimate versions and acceptance
/// (which moves the line procedures to `accepted`).
class PlanService {
  /// Creates the service.
  const PlanService({
    required this.plans,
    required this.chart,
    required this.catalog,
    required this.ctx,
  });

  /// Plan and estimate repository.
  final TreatmentPlanRepository plans;

  /// Procedures on the chart.
  final ChartRepository chart;

  /// Catalogue (for stages when creating procedures).
  final CatalogRepository catalog;

  /// Actor for writes.
  final ActorContext ctx;

  /// Creates an empty active plan (other active plans become inactive).
  Future<TreatmentPlan> createPlan({
    required String patientId,
    String title = defaultPlanTitle,
    DateTime? now,
  }) async {
    final t = (now ?? DateTime.now()).toUtc();
    final plan = TreatmentPlan(
      id: newId(),
      clinicId: ctx.clinicId,
      patientId: patientId,
      title: title,
      phases: [PlanPhase(index: 0, name: defaultPhaseName(0))],
      createdBy: ctx.actorId,
      createdAt: t,
      updatedAt: t,
    );
    await plans.savePlan(ctx, plan, const []);
    return plans.activatePlan(ctx, plan.id);
  }

  /// Loads a plan into an editor.
  Future<PlanEditor?> load(String planId) async {
    final plan = await plans.getPlan(planId);
    if (plan == null) return null;
    return PlanEditor(plan: plan, lines: await plans.linesForPlan(planId));
  }

  /// Saves the editor. Lines without a chart procedure get one (planned, or
  /// planned-inactive for alternatives); existing procedures are re-linked
  /// and their fee, discount and alternative status kept in step. Procedures
  /// of removed lines that are still planned become planned-inactive.
  Future<PlanEditor> save(
    PlanEditor editor, {
    required String providerId,
    DateTime? now,
  }) async {
    final t = (now ?? DateTime.now()).toUtc();
    final before = await plans.linesForPlan(editor.plan.id);
    final keep = {for (final l in editor.lines) l.id};
    final lines = <TreatmentPlanLine>[];
    for (final l in editor.lines) {
      lines.add(await _syncProcedure(l, providerId: providerId, now: t));
    }
    for (final old in before) {
      if (keep.contains(old.id) || old.procedureId == null) continue;
      final proc = await chart.getProcedure(old.procedureId!);
      if (proc != null && proc.status == ProcedureStatus.planned) {
        await chart.setProcedureStatus(
          ctx,
          proc.id,
          ProcedureStatus.plannedInactive,
          reason: 'Removed from plan ${editor.plan.title}',
          at: t,
        );
      }
    }
    final saved = await plans.savePlan(
      ctx,
      editor.plan.copyWith(updatedAt: t),
      lines,
    );
    return editor.saved(saved, await plans.linesForPlan(saved.id));
  }

  Future<TreatmentPlanLine> _syncProcedure(
    TreatmentPlanLine line, {
    required String providerId,
    required DateTime now,
  }) async {
    final existing = line.procedureId == null
        ? null
        : await chart.getProcedure(line.procedureId!);
    if (existing == null) {
      final item = await catalog.getById(line.catalogItemId);
      final proc = procedureFromLine(
        line,
        providerId: providerId,
        now: now,
        item: item,
      );
      await chart.createProcedure(ctx, proc);
      return line.copyWith(procedureId: proc.id);
    }
    final wantedStatus = line.isAlternative
        ? ProcedureStatus.plannedInactive
        : ProcedureStatus.planned;
    final stillPlanned =
        existing.status == ProcedureStatus.planned ||
        existing.status == ProcedureStatus.plannedInactive;
    final fee = line.unitFee.times(line.quantity);
    final changed =
        existing.planId != line.planId ||
        existing.planLineId != line.id ||
        existing.fee != fee ||
        existing.discount != line.discount ||
        (stillPlanned && existing.status != wantedStatus);
    if (changed) {
      await chart.updateProcedure(
        ctx,
        existing.copyWith(
          planId: line.planId,
          planLineId: line.id,
          fee: fee,
          discount: line.discount,
          status: stillPlanned ? wantedStatus : existing.status,
          updatedAt: now,
        ),
      );
    }
    return line;
  }

  /// Stamps `presentedAt` (first presentation only) and saves.
  Future<TreatmentPlan> present(PlanEditor editor, {DateTime? now}) async {
    final t = (now ?? DateTime.now()).toUtc();
    if (editor.plan.presentedAt != null) return editor.plan;
    return plans.savePlan(
      ctx,
      editor.plan.copyWith(presentedAt: t, updatedAt: t),
      editor.lines,
    );
  }

  /// Version the next estimate for [planId] would get.
  Future<int> nextEstimateVersion(String planId) async {
    final existing = await plans.estimatesForPlan(planId);
    var max = 0;
    for (final e in existing) {
      if (e.version > max) max = e.version;
    }
    return max + 1;
  }

  /// Every estimate from version 2 on needs a justification (DCI 5.7.1).
  static bool estimateNeedsJustification(int version) => version > 1;

  /// Why the plan cannot be accepted (or its treatment started) yet, or null
  /// when it can: an estimate must have been issued for [plan], unless the
  /// patient's refusal of a written estimate is recorded (on the plan, or
  /// given as [estimateDeclinedReason] for this acceptance). When the latest
  /// estimate carries a plan snapshot hash and [lines] differ from it, the
  /// plan changed since the patient saw the estimate.
  Future<String?> estimateGap(
    TreatmentPlan plan,
    Iterable<TreatmentPlanLine> lines, {
    String? estimateDeclinedReason,
  }) async {
    final declined = (estimateDeclinedReason ?? plan.estimateDeclinedReason)
        ?.trim();
    final latest = latestEstimate(await plans.estimatesForPlan(plan.id));
    if (latest == null) {
      return declined == null || declined.isEmpty
          ? PlanStrings.estimateRequired
          : null;
    }
    if (estimateMatchesPlan(latest, plan, lines) == false) {
      return PlanStrings.planChangedSinceEstimate;
    }
    return null;
  }

  /// Throws [StateError] when treatment on [planId] may not start yet: no
  /// estimate was issued and no refusal recorded (see [estimateGap]). Call
  /// before moving a plan line's procedure to in progress.
  Future<void> ensureEstimateBeforeTreatment(String planId) async {
    final plan = await plans.getPlan(planId);
    if (plan == null) return;
    final gap = await estimateGap(plan, await plans.linesForPlan(planId));
    if (gap != null) throw StateError(gap);
  }

  /// Issues the next estimate version from the plan's live lines and binds
  /// it to the plan version and snapshot hash of those lines, so acceptance
  /// can tell when the plan changed after the patient saw the estimate.
  /// Throws [ArgumentError] when a revision has no justification.
  Future<Estimate> issueEstimate(
    String planId, {
    String? justification,
    DateTime? validUntil,
    DateTime? now,
  }) async {
    final version = await nextEstimateVersion(planId);
    if (estimateNeedsJustification(version) &&
        (justification ?? '').trim().isEmpty) {
      throw ArgumentError.value(
        justification,
        'justification',
        'required for estimate version $version',
      );
    }
    // The repository binds the estimate to the plan version and the
    // snapshot hash of the lines it was issued from.
    return plans.estimateFromPlan(
      ctx,
      planId,
      justification: justification?.trim(),
      validUntil: validUntil,
      at: now,
    );
  }

  /// Records acceptance with the signer and signature, freezes the lines
  /// (snapshot hash) and moves every default line's procedure to
  /// `accepted`. Requires an issued estimate that still matches the lines,
  /// unless [estimateDeclinedReason] records that the patient declined a
  /// written one. A minor cannot accept for themselves; an unknown age blocks.
  Future<TreatmentPlan> accept(
    PlanEditor editor, {
    required Patient patient,
    required String signerName,
    required SignerRelation relation,
    Uint8List? signaturePng,
    String? estimateDeclinedReason,
    DateTime? now,
  }) async {
    final t = (now ?? DateTime.now()).toUtc();
    if (patient.ageStatus(t) == AgeStatus.unknown) {
      throw StateError(ConsentStrings.ageUnknown);
    }
    if (patient.isMinor(t) && relation == SignerRelation.self) {
      throw StateError(ConsentStrings.minorCannotSelfSign);
    }
    if (signerName.trim().isEmpty) {
      throw StateError(ConsentStrings.signerNameRequired);
    }
    if (signaturePng == null) {
      throw StateError(ConsentStrings.signatureRequired);
    }
    if (editor.dirty) throw StateError('Save the plan before accepting it');
    final gap = await estimateGap(
      editor.plan,
      editor.lines,
      estimateDeclinedReason: estimateDeclinedReason,
    );
    if (gap != null) throw StateError(gap);
    final plan = await plans.acceptPlan(
      ctx,
      editor.plan.id,
      signerName: '${signerName.trim()} (${signerRelationLabel(relation)})',
      signatureHash: sha256Hex(signaturePng),
      estimateDeclinedReason: estimateDeclinedReason,
      at: t,
    );
    for (final l in editor.lines) {
      if (l.isAlternative || l.procedureId == null) continue;
      final proc = await chart.getProcedure(l.procedureId!);
      if (proc != null &&
          (proc.status == ProcedureStatus.planned ||
              proc.status == ProcedureStatus.plannedInactive)) {
        await chart.setProcedureStatus(
          ctx,
          proc.id,
          ProcedureStatus.accepted,
          at: t,
        );
      }
    }
    return plan;
  }

  /// Creates version n+1 of an accepted plan and returns the new plan.
  Future<TreatmentPlan> revise(String planId, {String? title}) =>
      plans.revisePlan(ctx, planId, title: title);
}
