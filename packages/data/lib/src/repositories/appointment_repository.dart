import 'package:ampdent_core/ampdent_core.dart';

import 'actor_context.dart';

/// Appointment book and visits.
abstract class AppointmentRepository {
  /// Appointments starting in `[from, to)`, ordered by start.
  Future<List<Appointment>> range(String clinicId, DateTime from, DateTime to);

  /// Stream of appointments starting in `[from, to)`, ordered by start.
  Stream<List<Appointment>> watchRange(
    String clinicId,
    DateTime from,
    DateTime to,
  );

  /// Appointment by id.
  Future<Appointment?> getById(String id);

  /// Stream of a patient's appointments, newest first.
  Stream<List<Appointment>> watchForPatient(String patientId);

  /// Creates or updates an appointment (audited).
  Future<Appointment> upsert(ActorContext ctx, Appointment appointment);

  /// Moves an appointment to [status], stamping `confirmedAt`, `arrivedAt`
  /// or `cancelledReason` as appropriate.
  Future<Appointment> changeStatus(
    ActorContext ctx,
    String id,
    AppointmentStatus status, {
    String? reason,
    DateTime? at,
  });

  /// Chair-occupying appointments overlapping `[start, end)` on [chairId]
  /// or with [providerId] (either may be null), excluding [excludeId].
  Future<List<Appointment>> conflicts({
    required String clinicId,
    String? chairId,
    String? providerId,
    required DateTime start,
    required DateTime end,
    String? excludeId,
  });

  /// Opens a visit (check-in).
  Future<Visit> startVisit(ActorContext ctx, Visit visit);

  /// Updates a visit.
  Future<Visit> updateVisit(ActorContext ctx, Visit visit);

  /// Closes a visit.
  Future<Visit> endVisit(ActorContext ctx, String visitId, {DateTime? at});

  /// Visit by id.
  Future<Visit?> getVisit(String id);

  /// The patient's open visit, if any.
  Future<Visit?> openVisit(String patientId);

  /// Stream of a patient's visits, newest first.
  Stream<List<Visit>> watchVisits(String patientId);
}
