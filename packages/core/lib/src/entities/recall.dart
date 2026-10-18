import 'package:meta/meta.dart';

import '../dental/clinical_enums.dart';
import '../money/money.dart';
import 'json_support.dart';

/// Kind of recall.
enum RecallType {
  hygiene,
  review,
  orthoAdjustment,
  implantReview,
  postOp,
  custom,
}

/// Recall lifecycle.
enum RecallStatus { due, notified, scheduled, completed, dismissed }

/// A recall (review) owed to a patient, usually triggered by a completed
/// procedure's [RecallInterval].
@immutable
class Recall {
  /// Creates a recall.
  const Recall({
    required this.id,
    required this.clinicId,
    required this.patientId,
    required this.type,
    this.triggeredByProcedureId,
    required this.dueAt,
    this.interval,
    this.status = RecallStatus.due,
    this.lastNotifiedAt,
    this.notifyCount = 0,
    this.appointmentId,
    this.estimatedValue = const Money.zero(),
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  /// UUID v4.
  final String id;

  /// Owning clinic.
  final String clinicId;

  /// Patient.
  final String patientId;

  /// Kind.
  final RecallType type;

  /// Procedure whose completion created this recall.
  final String? triggeredByProcedureId;

  /// When the patient is due.
  final DateTime dueAt;

  /// Interval that produced [dueAt].
  final RecallInterval? interval;

  /// Status.
  final RecallStatus status;

  /// Last reminder time.
  final DateTime? lastNotifiedAt;

  /// Number of reminders sent.
  final int notifyCount;

  /// Appointment booked for it.
  final String? appointmentId;

  /// Expected revenue, for the recall-value dashboard.
  final Money estimatedValue;

  /// Note.
  final String? note;

  /// Row creation time.
  final DateTime createdAt;

  /// Last modification time.
  final DateTime updatedAt;

  /// Whether the recall is past due and still open as of [asOf].
  bool isOverdue(DateTime asOf) =>
      (status == RecallStatus.due || status == RecallStatus.notified) &&
      asOf.isAfter(dueAt);

  /// Returns a copy with the given fields replaced.
  Recall copyWith({
    RecallType? type,
    DateTime? dueAt,
    RecallInterval? interval,
    RecallStatus? status,
    DateTime? lastNotifiedAt,
    int? notifyCount,
    String? appointmentId,
    Money? estimatedValue,
    String? note,
    DateTime? updatedAt,
  }) => Recall(
    id: id,
    clinicId: clinicId,
    patientId: patientId,
    type: type ?? this.type,
    triggeredByProcedureId: triggeredByProcedureId,
    dueAt: dueAt ?? this.dueAt,
    interval: interval ?? this.interval,
    status: status ?? this.status,
    lastNotifiedAt: lastNotifiedAt ?? this.lastNotifiedAt,
    notifyCount: notifyCount ?? this.notifyCount,
    appointmentId: appointmentId ?? this.appointmentId,
    estimatedValue: estimatedValue ?? this.estimatedValue,
    note: note ?? this.note,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'clinicId': clinicId,
    'patientId': patientId,
    'type': type.name,
    'triggeredByProcedureId': triggeredByProcedureId,
    'dueAt': dateToJson(dueAt),
    'interval': interval?.name,
    'status': status.name,
    'lastNotifiedAt': dateToJson(lastNotifiedAt),
    'notifyCount': notifyCount,
    'appointmentId': appointmentId,
    'estimatedValue': estimatedValue.toJson(),
    'note': note,
    'createdAt': dateToJson(createdAt),
    'updatedAt': dateToJson(updatedAt),
  };

  /// Parses the JSON form.
  factory Recall.fromJson(Map<String, Object?> json) => Recall(
    id: json['id'] as String,
    clinicId: json['clinicId'] as String,
    patientId: json['patientId'] as String,
    type: enumFromJson(RecallType.values, json['type']),
    triggeredByProcedureId: json['triggeredByProcedureId'] as String?,
    dueAt: dateFromJson(json['dueAt']),
    interval: enumFromJsonOrNull(RecallInterval.values, json['interval']),
    status: enumFromJson(RecallStatus.values, json['status']),
    lastNotifiedAt: dateFromJsonOrNull(json['lastNotifiedAt']),
    notifyCount: json['notifyCount'] as int? ?? 0,
    appointmentId: json['appointmentId'] as String?,
    estimatedValue:
        moneyFromJsonOrNull(json['estimatedValue']) ?? const Money.zero(),
    note: json['note'] as String?,
    createdAt: dateFromJson(json['createdAt']),
    updatedAt: dateFromJson(json['updatedAt']),
  );
}
