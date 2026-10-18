import 'package:meta/meta.dart';

import '../dental/clinical_enums.dart';
import 'json_support.dart';

/// How an appointment was booked.
enum AppointmentSource { walkIn, phone, whatsapp, online, practo, recall }

/// A booked slot in the appointment book.
@immutable
class Appointment {
  /// Creates an appointment.
  const Appointment({
    required this.id,
    required this.clinicId,
    required this.patientId,
    required this.providerId,
    this.chairId,
    required this.startsAt,
    required this.endsAt,
    this.status = AppointmentStatus.scheduled,
    this.reason = '',
    this.plannedProcedureIds = const [],
    this.source = AppointmentSource.phone,
    this.notes,
    this.confirmedAt,
    this.reminder24hSentAt,
    this.reminderMorningSentAt,
    this.arrivedAt,
    this.cancelledReason,
    required this.createdAt,
    required this.updatedAt,
  });

  /// UUID v4.
  final String id;

  /// Owning clinic.
  final String clinicId;

  /// Patient being seen.
  final String patientId;

  /// Clinician ([ClinicMember]) the slot is booked with.
  final String providerId;

  /// Chair, when the clinic books by chair.
  final String? chairId;

  /// Slot start.
  final DateTime startsAt;

  /// Slot end.
  final DateTime endsAt;

  /// Lifecycle status.
  final AppointmentStatus status;

  /// Free-text reason / chief complaint at booking.
  final String reason;

  /// Planned procedure ids to be done in this slot.
  final List<String> plannedProcedureIds;

  /// Booking channel.
  final AppointmentSource source;

  /// Front-desk notes.
  final String? notes;

  /// When the patient confirmed.
  final DateTime? confirmedAt;

  /// When the 24-hour reminder went out.
  final DateTime? reminder24hSentAt;

  /// When the same-morning reminder went out.
  final DateTime? reminderMorningSentAt;

  /// When the patient arrived.
  final DateTime? arrivedAt;

  /// Reason given on cancellation.
  final String? cancelledReason;

  /// Row creation time.
  final DateTime createdAt;

  /// Last modification time.
  final DateTime updatedAt;

  /// Booked length.
  Duration get duration => endsAt.difference(startsAt);

  /// Whether this slot overlaps [other] in time (touching edges do not
  /// overlap).
  bool overlaps(Appointment other) =>
      startsAt.isBefore(other.endsAt) && other.startsAt.isBefore(endsAt);

  /// Returns a copy with the given fields replaced.
  Appointment copyWith({
    String? patientId,
    String? providerId,
    String? chairId,
    DateTime? startsAt,
    DateTime? endsAt,
    AppointmentStatus? status,
    String? reason,
    List<String>? plannedProcedureIds,
    AppointmentSource? source,
    String? notes,
    DateTime? confirmedAt,
    DateTime? reminder24hSentAt,
    DateTime? reminderMorningSentAt,
    DateTime? arrivedAt,
    String? cancelledReason,
    DateTime? updatedAt,
  }) => Appointment(
    id: id,
    clinicId: clinicId,
    patientId: patientId ?? this.patientId,
    providerId: providerId ?? this.providerId,
    chairId: chairId ?? this.chairId,
    startsAt: startsAt ?? this.startsAt,
    endsAt: endsAt ?? this.endsAt,
    status: status ?? this.status,
    reason: reason ?? this.reason,
    plannedProcedureIds: plannedProcedureIds ?? this.plannedProcedureIds,
    source: source ?? this.source,
    notes: notes ?? this.notes,
    confirmedAt: confirmedAt ?? this.confirmedAt,
    reminder24hSentAt: reminder24hSentAt ?? this.reminder24hSentAt,
    reminderMorningSentAt: reminderMorningSentAt ?? this.reminderMorningSentAt,
    arrivedAt: arrivedAt ?? this.arrivedAt,
    cancelledReason: cancelledReason ?? this.cancelledReason,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'clinicId': clinicId,
    'patientId': patientId,
    'providerId': providerId,
    'chairId': chairId,
    'startsAt': dateToJson(startsAt),
    'endsAt': dateToJson(endsAt),
    'status': status.name,
    'reason': reason,
    'plannedProcedureIds': plannedProcedureIds,
    'source': source.name,
    'notes': notes,
    'confirmedAt': dateToJson(confirmedAt),
    'reminder24hSentAt': dateToJson(reminder24hSentAt),
    'reminderMorningSentAt': dateToJson(reminderMorningSentAt),
    'arrivedAt': dateToJson(arrivedAt),
    'cancelledReason': cancelledReason,
    'createdAt': dateToJson(createdAt),
    'updatedAt': dateToJson(updatedAt),
  };

  /// Parses the JSON form.
  factory Appointment.fromJson(Map<String, Object?> json) => Appointment(
    id: json['id'] as String,
    clinicId: json['clinicId'] as String,
    patientId: json['patientId'] as String,
    providerId: json['providerId'] as String,
    chairId: json['chairId'] as String?,
    startsAt: dateFromJson(json['startsAt']),
    endsAt: dateFromJson(json['endsAt']),
    status: enumFromJson(AppointmentStatus.values, json['status']),
    reason: json['reason'] as String? ?? '',
    plannedProcedureIds: stringListFromJson(json['plannedProcedureIds']),
    source: enumFromJson(AppointmentSource.values, json['source']),
    notes: json['notes'] as String?,
    confirmedAt: dateFromJsonOrNull(json['confirmedAt']),
    reminder24hSentAt: dateFromJsonOrNull(json['reminder24hSentAt']),
    reminderMorningSentAt: dateFromJsonOrNull(json['reminderMorningSentAt']),
    arrivedAt: dateFromJsonOrNull(json['arrivedAt']),
    cancelledReason: json['cancelledReason'] as String?,
    createdAt: dateFromJson(json['createdAt']),
    updatedAt: dateFromJson(json['updatedAt']),
  );
}

/// A clinical encounter. Findings, procedures, notes and images hang off a
/// visit; an appointment is optional (walk-ins).
@immutable
class Visit {
  /// Creates a visit.
  const Visit({
    required this.id,
    required this.clinicId,
    required this.patientId,
    required this.providerId,
    this.appointmentId,
    required this.startedAt,
    this.endedAt,
    this.chiefComplaint,
    required this.createdAt,
    required this.updatedAt,
  });

  /// UUID v4.
  final String id;

  /// Owning clinic.
  final String clinicId;

  /// Patient seen.
  final String patientId;

  /// Treating clinician.
  final String providerId;

  /// Appointment this visit fulfilled, if any.
  final String? appointmentId;

  /// Check-in / chair time.
  final DateTime startedAt;

  /// Check-out time; null while in progress.
  final DateTime? endedAt;

  /// Chief complaint in the patient's words.
  final String? chiefComplaint;

  /// Row creation time.
  final DateTime createdAt;

  /// Last modification time.
  final DateTime updatedAt;

  /// Whether the visit is still open.
  bool get isOpen => endedAt == null;

  /// Returns a copy with the given fields replaced.
  Visit copyWith({
    String? providerId,
    String? appointmentId,
    DateTime? startedAt,
    DateTime? endedAt,
    String? chiefComplaint,
    DateTime? updatedAt,
  }) => Visit(
    id: id,
    clinicId: clinicId,
    patientId: patientId,
    providerId: providerId ?? this.providerId,
    appointmentId: appointmentId ?? this.appointmentId,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt ?? this.endedAt,
    chiefComplaint: chiefComplaint ?? this.chiefComplaint,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'clinicId': clinicId,
    'patientId': patientId,
    'providerId': providerId,
    'appointmentId': appointmentId,
    'startedAt': dateToJson(startedAt),
    'endedAt': dateToJson(endedAt),
    'chiefComplaint': chiefComplaint,
    'createdAt': dateToJson(createdAt),
    'updatedAt': dateToJson(updatedAt),
  };

  /// Parses the JSON form.
  factory Visit.fromJson(Map<String, Object?> json) => Visit(
    id: json['id'] as String,
    clinicId: json['clinicId'] as String,
    patientId: json['patientId'] as String,
    providerId: json['providerId'] as String,
    appointmentId: json['appointmentId'] as String?,
    startedAt: dateFromJson(json['startedAt']),
    endedAt: dateFromJsonOrNull(json['endedAt']),
    chiefComplaint: json['chiefComplaint'] as String?,
    createdAt: dateFromJson(json['createdAt']),
    updatedAt: dateFromJson(json['updatedAt']),
  );
}
