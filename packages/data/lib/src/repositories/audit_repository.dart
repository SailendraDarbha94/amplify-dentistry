import 'package:ampdent_core/ampdent_core.dart';

import 'actor_context.dart';

/// The immutable audit log. Repositories append to it on every write; this
/// interface appends standalone events (views, logins) and queries it.
abstract class AuditRepository {
  /// Appends an event.
  Future<AuditEvent> append(
    ActorContext ctx, {
    required AuditAction action,
    required String entityType,
    required String entityId,
    Map<String, Object?>? before,
    Map<String, Object?>? after,
    String? reason,
    DateTime? at,
  });

  /// Events for one entity, oldest first.
  Future<List<AuditEvent>> forEntity(
    String clinicId,
    String entityType,
    String entityId,
  );

  /// Events by an actor, newest first, optionally in `[from, to)`.
  Future<List<AuditEvent>> forActor(
    String clinicId,
    String actorId, {
    DateTime? from,
    DateTime? to,
    int? limit,
  });

  /// Events in `[from, to)`, newest first.
  Future<List<AuditEvent>> inRange(
    String clinicId,
    DateTime from,
    DateTime to, {
    int? limit,
  });

  /// Stream of the most recent events.
  Stream<List<AuditEvent>> watchRecent(String clinicId, {int limit = 100});

  /// Number of events for the clinic.
  Future<int> count(String clinicId);
}
