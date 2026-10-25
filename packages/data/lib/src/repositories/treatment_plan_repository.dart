import 'package:ampdent_core/ampdent_core.dart';

import 'actor_context.dart';

/// Treatment plans with lines, acceptance snapshots and versioned estimates.
abstract class TreatmentPlanRepository {
  /// Plan by id.
  Future<TreatmentPlan?> getPlan(String planId);

  /// Live lines of a plan ordered by phase then sequence.
  Future<List<TreatmentPlanLine>> linesForPlan(String planId);

  /// Stream of a patient's plans, newest first.
  Stream<List<TreatmentPlan>> watchPlans(String patientId);

  /// Stream of a plan's live lines.
  Stream<List<TreatmentPlanLine>> watchLines(String planId);

  /// The patient's active plan, if any.
  Future<TreatmentPlan?> activePlan(String patientId);

  /// Saves the plan and its full line set. Lines missing from [lines] are
  /// marked removed (never deleted). Throws [StateError] when the plan has
  /// been accepted (lines are frozen); revise it instead.
  Future<TreatmentPlan> savePlan(
    ActorContext ctx,
    TreatmentPlan plan,
    List<TreatmentPlanLine> lines,
  );

  /// Makes [planId] the active plan and moves other active plans of the
  /// patient to `inactive`.
  Future<TreatmentPlan> activatePlan(ActorContext ctx, String planId);

  /// Changes a plan's status.
  Future<TreatmentPlan> setPlanStatus(
    ActorContext ctx,
    String planId,
    TreatmentPlanStatus status,
  );

  /// Records acceptance: computes and stores the snapshot hash over the live
  /// lines, stamps the signer and moves the plan to `accepted`.
  Future<TreatmentPlan> acceptPlan(
    ActorContext ctx,
    String planId, {
    required String signerName,
    String? signatureHash,
    String? estimateDeclinedReason,
    DateTime? at,
  });

  /// Creates version n+1 of a plan (copying live lines with new ids) and
  /// marks the old plan `superseded`.
  Future<TreatmentPlan> revisePlan(
    ActorContext ctx,
    String planId, {
    String? title,
  });

  /// Estimates for a plan, oldest version first.
  Future<List<Estimate>> estimatesForPlan(String planId);

  /// Estimates for a patient, newest first.
  Future<List<Estimate>> estimatesForPatient(String patientId);

  /// Estimate by id.
  Future<Estimate?> getEstimate(String id);

  /// Stores an estimate. Throws [ArgumentError] when `version > 1` and no
  /// justification is given; earlier issued versions for the same plan move
  /// to `superseded`. An empty `number` is replaced with a minted draft
  /// number.
  Future<Estimate> issueEstimate(ActorContext ctx, Estimate estimate);

  /// Builds and stores the next estimate version from a plan's live lines
  /// using the clinic's GST rate table (or [rates]).
  Future<Estimate> estimateFromPlan(
    ActorContext ctx,
    String planId, {
    GstRateTable? rates,
    String? justification,
    DateTime? validUntil,
    DateTime? at,
  });

  /// Changes an estimate's status.
  Future<Estimate> setEstimateStatus(
    ActorContext ctx,
    String id,
    EstimateStatus status,
  );
}
