import 'package:meta/meta.dart';

import 'json_support.dart';

/// Kind of audited action.
enum AuditAction {
  create,
  update,
  statusChange,
  softDelete,
  view,
  export,
  print,
  share,
  login,
  logout,
  settingsChange,
}

/// One immutable audit-log entry. Clinical rows are never hard-deleted, so
/// every change is a new row here with a before/after snapshot.
@immutable
class AuditEvent {
  /// Creates an audit event.
  const AuditEvent({
    required this.id,
    required this.clinicId,
    required this.actorId,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.before,
    this.after,
    this.reason,
    required this.deviceId,
    required this.occurredAt,
  });

  /// UUID v4.
  final String id;

  /// Owning clinic.
  final String clinicId;

  /// Member who acted.
  final String actorId;

  /// What happened.
  final AuditAction action;

  /// Entity type name (`Procedure`, `Invoice`).
  final String entityType;

  /// Entity id.
  final String entityId;

  /// JSON snapshot before the change (null for creates and reads).
  final Map<String, Object?>? before;

  /// JSON snapshot after the change (null for deletes and reads).
  final Map<String, Object?>? after;

  /// Reason given by the actor, when the action required one.
  final String? reason;

  /// Device that produced the event.
  final String deviceId;

  /// When it happened (device clock).
  final DateTime occurredAt;

  /// Returns a copy with the given fields replaced.
  AuditEvent copyWith({String? reason}) => AuditEvent(
    id: id,
    clinicId: clinicId,
    actorId: actorId,
    action: action,
    entityType: entityType,
    entityId: entityId,
    before: before,
    after: after,
    reason: reason ?? this.reason,
    deviceId: deviceId,
    occurredAt: occurredAt,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'clinicId': clinicId,
    'actorId': actorId,
    'action': action.name,
    'entityType': entityType,
    'entityId': entityId,
    'before': before,
    'after': after,
    'reason': reason,
    'deviceId': deviceId,
    'occurredAt': dateToJson(occurredAt),
  };

  /// Parses the JSON form.
  factory AuditEvent.fromJson(Map<String, Object?> json) => AuditEvent(
    id: json['id'] as String,
    clinicId: json['clinicId'] as String,
    actorId: json['actorId'] as String,
    action: enumFromJson(AuditAction.values, json['action']),
    entityType: json['entityType'] as String,
    entityId: json['entityId'] as String,
    before: objectMapFromJson(json['before']),
    after: objectMapFromJson(json['after']),
    reason: json['reason'] as String?,
    deviceId: json['deviceId'] as String,
    occurredAt: dateFromJson(json['occurredAt']),
  );
}
