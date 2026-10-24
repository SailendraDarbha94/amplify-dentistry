/// Who is writing, from where. Passed to every repository write so the
/// audit event and outbox row can be stamped; never a global.
class ActorContext {
  /// Creates an actor context.
  const ActorContext({
    required this.clinicId,
    required this.actorId,
    required this.deviceId,
  });

  /// Tenant the write belongs to.
  final String clinicId;

  /// Clinic member performing the write.
  final String actorId;

  /// Device the write originated from.
  final String deviceId;

  @override
  bool operator ==(Object other) =>
      other is ActorContext &&
      other.clinicId == clinicId &&
      other.actorId == actorId &&
      other.deviceId == deviceId;

  @override
  int get hashCode => Object.hash(clinicId, actorId, deviceId);

  @override
  String toString() => 'ActorContext($clinicId, $actorId, $deviceId)';
}
