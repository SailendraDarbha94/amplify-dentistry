import 'package:meta/meta.dart';

import '../dental/clinical_enums.dart';
import 'json_support.dart';

/// A phase (sitting group) inside a treatment plan.
@immutable
class PlanPhase {
  /// Creates a plan phase.
  const PlanPhase({required this.index, required this.name, this.note});

  /// 0-based phase index referenced by [TreatmentPlanLine.phaseIndex].
  final int index;

  /// Display name (`Phase 1: Pain relief`).
  final String name;

  /// Optional note.
  final String? note;

  /// Returns a copy with the given fields replaced.
  PlanPhase copyWith({String? name, String? note}) =>
      PlanPhase(index: index, name: name ?? this.name, note: note ?? this.note);

  /// JSON form.
  Map<String, Object?> toJson() => {'index': index, 'name': name, 'note': note};

  /// Parses the JSON form.
  factory PlanPhase.fromJson(Map<String, Object?> json) => PlanPhase(
    index: json['index'] as int,
    name: json['name'] as String,
    note: json['note'] as String?,
  );
}

/// A versioned treatment plan. Lines are frozen on acceptance; a revision is
/// a new plan with [supersedesPlanId] set.
@immutable
class TreatmentPlan {
  /// Creates a treatment plan.
  const TreatmentPlan({
    required this.id,
    required this.clinicId,
    required this.patientId,
    required this.title,
    this.status = TreatmentPlanStatus.active,
    this.phases = const [],
    this.version = 1,
    this.supersedesPlanId,
    this.presentedAt,
    this.acceptedAt,
    this.acceptedBySignerName,
    this.acceptedSignatureHash,
    this.snapshotHash,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  /// UUID v4.
  final String id;

  /// Owning clinic.
  final String clinicId;

  /// Patient.
  final String patientId;

  /// Title shown to the patient.
  final String title;

  /// Lifecycle status.
  final TreatmentPlanStatus status;

  /// Phases.
  final List<PlanPhase> phases;

  /// Version number, 1-based.
  final int version;

  /// Earlier plan this one replaces.
  final String? supersedesPlanId;

  /// When presented to the patient.
  final DateTime? presentedAt;

  /// When accepted.
  final DateTime? acceptedAt;

  /// Who signed acceptance.
  final String? acceptedBySignerName;

  /// Hash of the acceptance signature image.
  final String? acceptedSignatureHash;

  /// Hash of the lines at acceptance (see [computePlanSnapshotHash]).
  final String? snapshotHash;

  /// Authoring clinician.
  final String createdBy;

  /// Row creation time.
  final DateTime createdAt;

  /// Last modification time.
  final DateTime updatedAt;

  /// Whether the plan has been accepted and is therefore frozen.
  bool get isAccepted => acceptedAt != null;

  /// Returns a copy with the given fields replaced.
  TreatmentPlan copyWith({
    String? title,
    TreatmentPlanStatus? status,
    List<PlanPhase>? phases,
    int? version,
    String? supersedesPlanId,
    DateTime? presentedAt,
    DateTime? acceptedAt,
    String? acceptedBySignerName,
    String? acceptedSignatureHash,
    String? snapshotHash,
    DateTime? updatedAt,
  }) => TreatmentPlan(
    id: id,
    clinicId: clinicId,
    patientId: patientId,
    title: title ?? this.title,
    status: status ?? this.status,
    phases: phases ?? this.phases,
    version: version ?? this.version,
    supersedesPlanId: supersedesPlanId ?? this.supersedesPlanId,
    presentedAt: presentedAt ?? this.presentedAt,
    acceptedAt: acceptedAt ?? this.acceptedAt,
    acceptedBySignerName: acceptedBySignerName ?? this.acceptedBySignerName,
    acceptedSignatureHash: acceptedSignatureHash ?? this.acceptedSignatureHash,
    snapshotHash: snapshotHash ?? this.snapshotHash,
    createdBy: createdBy,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'clinicId': clinicId,
    'patientId': patientId,
    'title': title,
    'status': status.name,
    'phases': phases.map((p) => p.toJson()).toList(),
    'version': version,
    'supersedesPlanId': supersedesPlanId,
    'presentedAt': dateToJson(presentedAt),
    'acceptedAt': dateToJson(acceptedAt),
    'acceptedBySignerName': acceptedBySignerName,
    'acceptedSignatureHash': acceptedSignatureHash,
    'snapshotHash': snapshotHash,
    'createdBy': createdBy,
    'createdAt': dateToJson(createdAt),
    'updatedAt': dateToJson(updatedAt),
  };

  /// Parses the JSON form.
  factory TreatmentPlan.fromJson(Map<String, Object?> json) => TreatmentPlan(
    id: json['id'] as String,
    clinicId: json['clinicId'] as String,
    patientId: json['patientId'] as String,
    title: json['title'] as String,
    status: enumFromJson(TreatmentPlanStatus.values, json['status']),
    phases:
        (json['phases'] as List?)
            ?.map((e) => PlanPhase.fromJson((e as Map).cast<String, Object?>()))
            .toList() ??
        const [],
    version: json['version'] as int? ?? 1,
    supersedesPlanId: json['supersedesPlanId'] as String?,
    presentedAt: dateFromJsonOrNull(json['presentedAt']),
    acceptedAt: dateFromJsonOrNull(json['acceptedAt']),
    acceptedBySignerName: json['acceptedBySignerName'] as String?,
    acceptedSignatureHash: json['acceptedSignatureHash'] as String?,
    snapshotHash: json['snapshotHash'] as String?,
    createdBy: json['createdBy'] as String,
    createdAt: dateFromJson(json['createdAt']),
    updatedAt: dateFromJson(json['updatedAt']),
  );
}
