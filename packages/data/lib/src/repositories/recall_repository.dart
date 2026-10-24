import 'package:ampdent_core/ampdent_core.dart';

import 'actor_context.dart';

/// Procedure-triggered recalls.
abstract class RecallRepository {
  /// Creates or updates a recall.
  Future<Recall> upsert(ActorContext ctx, Recall recall);

  /// Recall by id.
  Future<Recall?> getById(String id);

  /// A patient's recalls, soonest due first.
  Future<List<Recall>> forPatient(String patientId);

  /// Open recalls (`due` or `notified`) due on or before [until] (default:
  /// now), overdue first (ascending `dueAt`).
  Future<List<Recall>> due(String clinicId, {DateTime? until, int? limit});

  /// Stream of open recalls due on or before [until].
  Stream<List<Recall>> watchDue(String clinicId, {DateTime? until});

  /// Sum of `estimatedValue` over open recalls due on or before [until].
  Future<Money> dueValue(String clinicId, {DateTime? until});

  /// Marks a recall notified (increments `notifyCount`).
  Future<Recall> markNotified(ActorContext ctx, String id, {DateTime? at});

  /// Links a booked appointment and marks the recall scheduled.
  Future<Recall> markScheduled(
    ActorContext ctx,
    String id,
    String appointmentId,
  );

  /// Marks a recall completed.
  Future<Recall> markCompleted(ActorContext ctx, String id);

  /// Dismisses a recall with a reason.
  Future<Recall> dismiss(ActorContext ctx, String id, String reason);

  /// Creates the recall implied by a completed procedure's code via the
  /// default recall rules; null when no rule matches.
  Future<Recall?> createFromProcedure(
    ActorContext ctx,
    ProcedureRecord procedure, {
    DateTime? completedOn,
  });
}
