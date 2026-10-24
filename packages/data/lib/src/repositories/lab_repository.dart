import 'package:ampdent_core/ampdent_core.dart';

import 'actor_context.dart';

/// Labs and lab cases with timestamped status transitions.
abstract class LabRepository {
  /// Creates or updates a lab.
  Future<Lab> upsertLab(ActorContext ctx, Lab lab);

  /// Lab by id.
  Future<Lab?> getLab(String id);

  /// Labs of a clinic ordered by name.
  Future<List<Lab>> labs(String clinicId, {bool includeInactive = false});

  /// Marks a lab inactive.
  Future<Lab> deactivateLab(ActorContext ctx, String id);

  /// Creates a case.
  Future<LabCase> createCase(ActorContext ctx, LabCase labCase);

  /// Updates a case's editable fields.
  Future<LabCase> updateCase(ActorContext ctx, LabCase labCase);

  /// Case by id.
  Future<LabCase?> getCase(String id);

  /// Cases for a patient, newest first.
  Future<List<LabCase>> casesForPatient(String patientId);

  /// Open cases of the clinic, due soonest first.
  Future<List<LabCase>> openCases(String clinicId);

  /// Stream of open cases.
  Stream<List<LabCase>> watchOpenCases(String clinicId);

  /// Open cases past their due date as of [asOf].
  Future<List<LabCase>> overdueCases(String clinicId, {DateTime? asOf});

  /// Marks a case sent and computes `dueAt` from the lab's turnaround for
  /// the case type (or [turnaroundWorkingDays]; default 7 working days).
  Future<LabCase> markSent(
    ActorContext ctx,
    String id, {
    DateTime? at,
    int? turnaroundWorkingDays,
    Set<DateTime> holidays = const {},
  });

  /// Marks a case received.
  Future<LabCase> markReceived(ActorContext ctx, String id, {DateTime? at});

  /// Marks a case quality checked.
  Future<LabCase> markQualityChecked(
    ActorContext ctx,
    String id, {
    DateTime? at,
  });

  /// Marks a case fitted.
  Future<LabCase> markFitted(ActorContext ctx, String id, {DateTime? at});

  /// Marks the case `remakeRequested` and creates a new case pointing back
  /// through `remakeOfCaseId`; returns the new case.
  Future<LabCase> requestRemake(
    ActorContext ctx,
    String id, {
    required String reason,
    DateTime? at,
  });

  /// Cancels a case with a reason.
  Future<LabCase> cancelCase(ActorContext ctx, String id, String reason);
}
