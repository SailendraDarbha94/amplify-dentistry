import 'package:ampdent_core/ampdent_core.dart';

import 'actor_context.dart';

/// Odontogram data: tooth-state history, findings, procedures and implants.
/// Everything is append-only; "deleting" moves a row to a `deleted` status.
abstract class ChartRepository {
  /// Tooth-state history for a patient (optionally one tooth), oldest first.
  Future<List<ToothStateRecord>> toothStateHistory(
    String patientId, {
    ToothId? tooth,
  });

  /// Stream of the tooth-state history.
  Stream<List<ToothStateRecord>> watchToothStateHistory(String patientId);

  /// Current state per tooth, collapsed from the history.
  Future<Map<ToothId, ToothState>> currentStates(String patientId);

  /// Stream of the current state per tooth.
  Stream<Map<ToothId, ToothState>> watchCurrentStates(String patientId);

  /// Appends a tooth-state record.
  Future<ToothStateRecord> recordToothState(
    ActorContext ctx,
    ToothStateRecord record,
  );

  /// Appends many tooth-state records in one transaction (one audit event
  /// and one outbox row per record, all stamped with the same instant), for
  /// the 52-row age-default seed. Nothing is written when any record fails
  /// validation.
  Future<List<ToothStateRecord>> recordToothStates(
    ActorContext ctx,
    List<ToothStateRecord> records,
  );

  /// Findings for a patient, newest first.
  Future<List<Finding>> findings(
    String patientId, {
    bool includeDeleted = false,
  });

  /// Stream of findings.
  Stream<List<Finding>> watchFindings(
    String patientId, {
    bool includeDeleted = false,
  });

  /// Finding by id.
  Future<Finding?> getFinding(String id);

  /// Adds a finding.
  Future<Finding> addFinding(ActorContext ctx, Finding finding);

  /// Updates a finding (audited with before/after).
  Future<Finding> updateFinding(ActorContext ctx, Finding finding);

  /// Resolves a finding, optionally by a procedure.
  Future<Finding> resolveFinding(
    ActorContext ctx,
    String id, {
    String? procedureId,
    DateTime? at,
  });

  /// Soft-deletes a finding with a reason.
  Future<Finding> deleteFinding(ActorContext ctx, String id, String reason);

  /// Procedure by id.
  Future<ProcedureRecord?> getProcedure(String id);

  /// Procedures for a patient, optionally filtered by status.
  Future<List<ProcedureRecord>> proceduresForPatient(
    String patientId, {
    Iterable<ProcedureStatus>? statuses,
    bool includeDeleted = false,
  });

  /// Stream of a patient's procedures (deleted excluded unless asked).
  Stream<List<ProcedureRecord>> watchProceduresForPatient(
    String patientId, {
    bool includeDeleted = false,
  });

  /// Completed procedures of a clinic, newest first, optionally limited to
  /// those completed at or after [from] and before [to].
  Future<List<ProcedureRecord>> completedProceduresForClinic(
    String clinicId, {
    DateTime? from,
    DateTime? to,
  });

  /// Creates a procedure.
  Future<ProcedureRecord> createProcedure(
    ActorContext ctx,
    ProcedureRecord procedure,
  );

  /// Updates a procedure's editable fields.
  Future<ProcedureRecord> updateProcedure(
    ActorContext ctx,
    ProcedureRecord procedure,
  );

  /// Moves a procedure to [status], stamping `acceptedAt`, `startedAt` or
  /// `completedAt` as appropriate. `deleted` requires a [reason]. Throws
  /// [StateError] when the procedure is already in [status], so a repeated
  /// completion never writes a second status change or recall.
  Future<ProcedureRecord> setProcedureStatus(
    ActorContext ctx,
    String id,
    ProcedureStatus status, {
    String? reason,
    DateTime? at,
  });

  /// Advances a multi-sitting procedure one stage: the first advance marks
  /// it `inProgress`; the final stage marks it `completed`.
  Future<ProcedureRecord> advanceStage(
    ActorContext ctx,
    String id, {
    DateTime? at,
  });

  /// Soft-deletes a procedure with a reason.
  Future<ProcedureRecord> deleteProcedure(
    ActorContext ctx,
    String id,
    String reason,
  );

  /// Implants for a patient.
  Future<List<ImplantRecord>> implantsForPatient(String patientId);

  /// Creates or updates an implant record.
  Future<ImplantRecord> upsertImplant(ActorContext ctx, ImplantRecord implant);
}
