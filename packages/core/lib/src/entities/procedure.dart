import 'package:meta/meta.dart';

import '../dental/clinical_enums.dart';
import '../dental/surfaces.dart';
import '../dental/tooth_id.dart';
import '../money/money.dart';
import 'json_support.dart';

/// A procedure planned or performed on a patient. Append-only: status moves
/// through [ProcedureStatus]; rows are never deleted.
@immutable
class ProcedureRecord {
  /// Creates a procedure record.
  const ProcedureRecord({
    required this.id,
    required this.clinicId,
    required this.patientId,
    this.visitId,
    this.planId,
    this.planLineId,
    required this.catalogItemId,
    required this.code,
    required this.name,
    this.tooth,
    this.teeth = const [],
    this.surfaces = const SurfaceSet.empty(),
    required this.treatmentArea,
    this.status = ProcedureStatus.planned,
    required this.providerId,
    required this.fee,
    this.discount = const Money.zero(),
    this.stageIndex = 0,
    this.totalStages = 1,
    this.stageNames = const [],
    this.plannedAt,
    this.acceptedAt,
    this.startedAt,
    this.completedAt,
    this.labCaseId,
    this.note,
    this.preOpImageIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// UUID v4.
  final String id;

  /// Owning clinic.
  final String clinicId;

  /// Patient.
  final String patientId;

  /// Visit during which work was done.
  final String? visitId;

  /// Treatment plan it came from.
  final String? planId;

  /// Plan line it came from.
  final String? planLineId;

  /// Catalogue item.
  final String catalogItemId;

  /// Catalogue code at the time (frozen).
  final String code;

  /// Name at the time (frozen).
  final String name;

  /// Single tooth for tooth/surface-level work.
  final ToothId? tooth;

  /// Teeth for ranges, quadrants, arches.
  final List<ToothId> teeth;

  /// Surfaces for surface-level work.
  final SurfaceSet surfaces;

  /// Anatomical extent.
  final TreatmentArea treatmentArea;

  /// Lifecycle status.
  final ProcedureStatus status;

  /// Treating clinician.
  final String providerId;

  /// Gross fee.
  final Money fee;

  /// Discount applied.
  final Money discount;

  /// Current stage, 0-based.
  final int stageIndex;

  /// Total stages (1 for single-sitting).
  final int totalStages;

  /// Stage names, when known.
  final List<String> stageNames;

  /// When planned.
  final DateTime? plannedAt;

  /// When the patient accepted.
  final DateTime? acceptedAt;

  /// When started.
  final DateTime? startedAt;

  /// When completed.
  final DateTime? completedAt;

  /// Linked lab case.
  final String? labCaseId;

  /// Note.
  final String? note;

  /// Pre-operative image ids.
  final List<String> preOpImageIds;

  /// Row creation time.
  final DateTime createdAt;

  /// Last modification time.
  final DateTime updatedAt;

  /// Whether this is multi-sitting work.
  bool get isMultiSitting => totalStages > 1;

  /// Name of the current stage, falling back to `Stage n/N`.
  String get currentStageName => stageIndex < stageNames.length
      ? stageNames[stageIndex]
      : 'Stage ${stageIndex + 1}/$totalStages';

  /// Fee after discount.
  Money get netFee => fee - discount;

  /// Returns a copy with the given fields replaced.
  ProcedureRecord copyWith({
    String? visitId,
    String? planId,
    String? planLineId,
    ToothId? tooth,
    List<ToothId>? teeth,
    SurfaceSet? surfaces,
    TreatmentArea? treatmentArea,
    ProcedureStatus? status,
    String? providerId,
    Money? fee,
    Money? discount,
    int? stageIndex,
    int? totalStages,
    List<String>? stageNames,
    DateTime? plannedAt,
    DateTime? acceptedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    String? labCaseId,
    String? note,
    List<String>? preOpImageIds,
    DateTime? updatedAt,
  }) => ProcedureRecord(
    id: id,
    clinicId: clinicId,
    patientId: patientId,
    visitId: visitId ?? this.visitId,
    planId: planId ?? this.planId,
    planLineId: planLineId ?? this.planLineId,
    catalogItemId: catalogItemId,
    code: code,
    name: name,
    tooth: tooth ?? this.tooth,
    teeth: teeth ?? this.teeth,
    surfaces: surfaces ?? this.surfaces,
    treatmentArea: treatmentArea ?? this.treatmentArea,
    status: status ?? this.status,
    providerId: providerId ?? this.providerId,
    fee: fee ?? this.fee,
    discount: discount ?? this.discount,
    stageIndex: stageIndex ?? this.stageIndex,
    totalStages: totalStages ?? this.totalStages,
    stageNames: stageNames ?? this.stageNames,
    plannedAt: plannedAt ?? this.plannedAt,
    acceptedAt: acceptedAt ?? this.acceptedAt,
    startedAt: startedAt ?? this.startedAt,
    completedAt: completedAt ?? this.completedAt,
    labCaseId: labCaseId ?? this.labCaseId,
    note: note ?? this.note,
    preOpImageIds: preOpImageIds ?? this.preOpImageIds,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'clinicId': clinicId,
    'patientId': patientId,
    'visitId': visitId,
    'planId': planId,
    'planLineId': planLineId,
    'catalogItemId': catalogItemId,
    'code': code,
    'name': name,
    'tooth': toothToJson(tooth),
    'teeth': teethToJson(teeth),
    'surfaces': surfaces.code,
    'treatmentArea': treatmentArea.name,
    'status': status.name,
    'providerId': providerId,
    'fee': fee.toJson(),
    'discount': discount.toJson(),
    'stageIndex': stageIndex,
    'totalStages': totalStages,
    'stageNames': stageNames,
    'plannedAt': dateToJson(plannedAt),
    'acceptedAt': dateToJson(acceptedAt),
    'startedAt': dateToJson(startedAt),
    'completedAt': dateToJson(completedAt),
    'labCaseId': labCaseId,
    'note': note,
    'preOpImageIds': preOpImageIds,
    'createdAt': dateToJson(createdAt),
    'updatedAt': dateToJson(updatedAt),
  };

  /// Parses the JSON form.
  factory ProcedureRecord.fromJson(Map<String, Object?> json) =>
      ProcedureRecord(
        id: json['id'] as String,
        clinicId: json['clinicId'] as String,
        patientId: json['patientId'] as String,
        visitId: json['visitId'] as String?,
        planId: json['planId'] as String?,
        planLineId: json['planLineId'] as String?,
        catalogItemId: json['catalogItemId'] as String,
        code: json['code'] as String,
        name: json['name'] as String,
        tooth: toothFromJsonOrNull(json['tooth']),
        teeth: teethFromJson(json['teeth']),
        surfaces: surfacesFromJson(json['surfaces']),
        treatmentArea: enumFromJson(
          TreatmentArea.values,
          json['treatmentArea'],
        ),
        status: enumFromJson(ProcedureStatus.values, json['status']),
        providerId: json['providerId'] as String,
        fee: moneyFromJson(json['fee']),
        discount: moneyFromJsonOrNull(json['discount']) ?? const Money.zero(),
        stageIndex: json['stageIndex'] as int? ?? 0,
        totalStages: json['totalStages'] as int? ?? 1,
        stageNames: stringListFromJson(json['stageNames']),
        plannedAt: dateFromJsonOrNull(json['plannedAt']),
        acceptedAt: dateFromJsonOrNull(json['acceptedAt']),
        startedAt: dateFromJsonOrNull(json['startedAt']),
        completedAt: dateFromJsonOrNull(json['completedAt']),
        labCaseId: json['labCaseId'] as String?,
        note: json['note'] as String?,
        preOpImageIds: stringListFromJson(json['preOpImageIds']),
        createdAt: dateFromJson(json['createdAt']),
        updatedAt: dateFromJson(json['updatedAt']),
      );
}
