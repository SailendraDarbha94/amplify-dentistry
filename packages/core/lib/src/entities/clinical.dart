import 'package:meta/meta.dart';

import '../dental/clinical_enums.dart';
import '../dental/dentition.dart';
import '../dental/surfaces.dart';
import '../dental/tooth_id.dart';
import 'json_support.dart';

/// Where a tooth-state record came from.
enum ToothStateSource { ageDefault, clinician, procedure, import }

/// One dated entry in a tooth's state history. Append-only; the current
/// state is the latest [effectiveFrom] per tooth (see [currentToothStates]).
@immutable
class ToothStateRecord {
  /// Creates a tooth-state record.
  const ToothStateRecord({
    required this.id,
    required this.clinicId,
    required this.patientId,
    required this.tooth,
    required this.state,
    required this.effectiveFrom,
    required this.source,
    this.procedureId,
    required this.recordedBy,
    this.note,
    required this.createdAt,
  });

  /// UUID v4.
  final String id;

  /// Owning clinic.
  final String clinicId;

  /// Patient whose chart this belongs to.
  final String patientId;

  /// Tooth (FDI canonical).
  final ToothId tooth;

  /// State from this date onwards.
  final ToothState state;

  /// When the state became true clinically.
  final DateTime effectiveFrom;

  /// Origin of the record.
  final ToothStateSource source;

  /// Procedure that caused the change (extraction, implant).
  final String? procedureId;

  /// Member who recorded it.
  final String recordedBy;

  /// Optional note.
  final String? note;

  /// Row creation time.
  final DateTime createdAt;

  /// Returns a copy with the given fields replaced.
  ToothStateRecord copyWith({
    ToothState? state,
    DateTime? effectiveFrom,
    ToothStateSource? source,
    String? procedureId,
    String? note,
  }) => ToothStateRecord(
    id: id,
    clinicId: clinicId,
    patientId: patientId,
    tooth: tooth,
    state: state ?? this.state,
    effectiveFrom: effectiveFrom ?? this.effectiveFrom,
    source: source ?? this.source,
    procedureId: procedureId ?? this.procedureId,
    recordedBy: recordedBy,
    note: note ?? this.note,
    createdAt: createdAt,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'clinicId': clinicId,
    'patientId': patientId,
    'tooth': tooth.storageKey,
    'state': state.name,
    'effectiveFrom': dateToJson(effectiveFrom),
    'source': source.name,
    'procedureId': procedureId,
    'recordedBy': recordedBy,
    'note': note,
    'createdAt': dateToJson(createdAt),
  };

  /// Parses the JSON form.
  factory ToothStateRecord.fromJson(Map<String, Object?> json) =>
      ToothStateRecord(
        id: json['id'] as String,
        clinicId: json['clinicId'] as String,
        patientId: json['patientId'] as String,
        tooth: toothFromJson(json['tooth']),
        state: enumFromJson(ToothState.values, json['state']),
        effectiveFrom: dateFromJson(json['effectiveFrom']),
        source: enumFromJson(ToothStateSource.values, json['source']),
        procedureId: json['procedureId'] as String?,
        recordedBy: json['recordedBy'] as String,
        note: json['note'] as String?,
        createdAt: dateFromJson(json['createdAt']),
      );
}

/// Collapses a history of tooth-state records to the latest state per tooth
/// (latest [ToothStateRecord.effectiveFrom]; ties broken by `createdAt`).
Map<ToothId, ToothState> currentToothStates(
  Iterable<ToothStateRecord> records,
) {
  final latest = <ToothId, ToothStateRecord>{};
  for (final r in records) {
    final existing = latest[r.tooth];
    if (existing == null || _isNewer(r, existing)) latest[r.tooth] = r;
  }
  return latest.map((tooth, r) => MapEntry(tooth, r.state));
}

bool _isNewer(ToothStateRecord a, ToothStateRecord b) {
  final cmp = a.effectiveFrom.compareTo(b.effectiveFrom);
  if (cmp != 0) return cmp > 0;
  return a.createdAt.isAfter(b.createdAt);
}

/// A clinical finding (condition) on a tooth, surface set or the mouth.
@immutable
class Finding {
  /// Creates a finding.
  const Finding({
    required this.id,
    required this.clinicId,
    required this.patientId,
    this.visitId,
    this.tooth,
    this.surfaces = const SurfaceSet.empty(),
    this.snomedCode,
    this.icd10Code,
    required this.description,
    this.icdas,
    this.status = FindingStatus.active,
    required this.recordedAt,
    required this.recordedBy,
    this.resolvedAt,
    this.resolvedByProcedureId,
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

  /// Visit during which it was recorded.
  final String? visitId;

  /// Tooth, null for mouth-level findings.
  final ToothId? tooth;

  /// Affected surfaces (empty when whole tooth or not applicable).
  final SurfaceSet surfaces;

  /// SNOMED CT concept id.
  final String? snomedCode;

  /// ICD-10 code (K00-K14 range for dental).
  final String? icd10Code;

  /// Human description (`Dental caries, dentine`).
  final String description;

  /// ICDAS II caries code when relevant.
  final IcdasCode? icdas;

  /// Lifecycle status.
  final FindingStatus status;

  /// When observed.
  final DateTime recordedAt;

  /// Member who recorded it.
  final String recordedBy;

  /// When resolved.
  final DateTime? resolvedAt;

  /// Procedure that resolved it.
  final String? resolvedByProcedureId;

  /// Optional note.
  final String? note;

  /// Row creation time.
  final DateTime createdAt;

  /// Last modification time.
  final DateTime updatedAt;

  /// Returns a copy with the given fields replaced.
  Finding copyWith({
    String? visitId,
    ToothId? tooth,
    SurfaceSet? surfaces,
    String? snomedCode,
    String? icd10Code,
    String? description,
    IcdasCode? icdas,
    FindingStatus? status,
    DateTime? recordedAt,
    DateTime? resolvedAt,
    String? resolvedByProcedureId,
    String? note,
    DateTime? updatedAt,
  }) => Finding(
    id: id,
    clinicId: clinicId,
    patientId: patientId,
    visitId: visitId ?? this.visitId,
    tooth: tooth ?? this.tooth,
    surfaces: surfaces ?? this.surfaces,
    snomedCode: snomedCode ?? this.snomedCode,
    icd10Code: icd10Code ?? this.icd10Code,
    description: description ?? this.description,
    icdas: icdas ?? this.icdas,
    status: status ?? this.status,
    recordedAt: recordedAt ?? this.recordedAt,
    recordedBy: recordedBy,
    resolvedAt: resolvedAt ?? this.resolvedAt,
    resolvedByProcedureId: resolvedByProcedureId ?? this.resolvedByProcedureId,
    note: note ?? this.note,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'clinicId': clinicId,
    'patientId': patientId,
    'visitId': visitId,
    'tooth': toothToJson(tooth),
    'surfaces': surfaces.code,
    'snomedCode': snomedCode,
    'icd10Code': icd10Code,
    'description': description,
    'icdas': icdas?.name,
    'status': status.name,
    'recordedAt': dateToJson(recordedAt),
    'recordedBy': recordedBy,
    'resolvedAt': dateToJson(resolvedAt),
    'resolvedByProcedureId': resolvedByProcedureId,
    'note': note,
    'createdAt': dateToJson(createdAt),
    'updatedAt': dateToJson(updatedAt),
  };

  /// Parses the JSON form.
  factory Finding.fromJson(Map<String, Object?> json) => Finding(
    id: json['id'] as String,
    clinicId: json['clinicId'] as String,
    patientId: json['patientId'] as String,
    visitId: json['visitId'] as String?,
    tooth: toothFromJsonOrNull(json['tooth']),
    surfaces: surfacesFromJson(json['surfaces']),
    snomedCode: json['snomedCode'] as String?,
    icd10Code: json['icd10Code'] as String?,
    description: json['description'] as String,
    icdas: enumFromJsonOrNull(IcdasCode.values, json['icdas']),
    status: enumFromJson(FindingStatus.values, json['status']),
    recordedAt: dateFromJson(json['recordedAt']),
    recordedBy: json['recordedBy'] as String,
    resolvedAt: dateFromJsonOrNull(json['resolvedAt']),
    resolvedByProcedureId: json['resolvedByProcedureId'] as String?,
    note: json['note'] as String?,
    createdAt: dateFromJson(json['createdAt']),
    updatedAt: dateFromJson(json['updatedAt']),
  );
}
