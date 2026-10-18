import 'package:meta/meta.dart';

import '../dental/tooth_id.dart';
import 'json_support.dart';

/// Implant fixture lifecycle.
enum ImplantStatus { placed, loaded, failed, explanted }

/// An implant fixture placed at a tooth position, with traceability data
/// (brand, lot, UDI) for recalls and warranty claims.
@immutable
class ImplantRecord {
  /// Creates an implant record.
  const ImplantRecord({
    required this.id,
    required this.clinicId,
    required this.patientId,
    required this.tooth,
    this.procedureId,
    required this.brand,
    this.system,
    required this.diameterMm,
    required this.lengthMm,
    required this.lotNumber,
    this.udi,
    this.expiryDate,
    required this.placedAt,
    this.insertionTorqueNcm,
    this.graftMaterial,
    this.membrane,
    this.status = ImplantStatus.placed,
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

  /// Tooth position.
  final ToothId tooth;

  /// Placement procedure.
  final String? procedureId;

  /// Manufacturer (`Nobel Biocare`, `Osstem`).
  final String brand;

  /// Implant system / line.
  final String? system;

  /// Diameter in mm.
  final num diameterMm;

  /// Length in mm.
  final num lengthMm;

  /// Lot / batch number from the sticker.
  final String lotNumber;

  /// Unique device identifier.
  final String? udi;

  /// Sterile expiry from the sticker.
  final DateTime? expiryDate;

  /// Placement time.
  final DateTime placedAt;

  /// Insertion torque in Ncm.
  final num? insertionTorqueNcm;

  /// Graft material used, if any.
  final String? graftMaterial;

  /// Membrane used, if any.
  final String? membrane;

  /// Status.
  final ImplantStatus status;

  /// Note.
  final String? note;

  /// Row creation time.
  final DateTime createdAt;

  /// Last modification time.
  final DateTime updatedAt;

  /// Returns a copy with the given fields replaced.
  ImplantRecord copyWith({
    String? procedureId,
    String? system,
    String? udi,
    DateTime? expiryDate,
    num? insertionTorqueNcm,
    String? graftMaterial,
    String? membrane,
    ImplantStatus? status,
    String? note,
    DateTime? updatedAt,
  }) => ImplantRecord(
    id: id,
    clinicId: clinicId,
    patientId: patientId,
    tooth: tooth,
    procedureId: procedureId ?? this.procedureId,
    brand: brand,
    system: system ?? this.system,
    diameterMm: diameterMm,
    lengthMm: lengthMm,
    lotNumber: lotNumber,
    udi: udi ?? this.udi,
    expiryDate: expiryDate ?? this.expiryDate,
    placedAt: placedAt,
    insertionTorqueNcm: insertionTorqueNcm ?? this.insertionTorqueNcm,
    graftMaterial: graftMaterial ?? this.graftMaterial,
    membrane: membrane ?? this.membrane,
    status: status ?? this.status,
    note: note ?? this.note,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'clinicId': clinicId,
    'patientId': patientId,
    'tooth': tooth.storageKey,
    'procedureId': procedureId,
    'brand': brand,
    'system': system,
    'diameterMm': diameterMm,
    'lengthMm': lengthMm,
    'lotNumber': lotNumber,
    'udi': udi,
    'expiryDate': dateToJson(expiryDate),
    'placedAt': dateToJson(placedAt),
    'insertionTorqueNcm': insertionTorqueNcm,
    'graftMaterial': graftMaterial,
    'membrane': membrane,
    'status': status.name,
    'note': note,
    'createdAt': dateToJson(createdAt),
    'updatedAt': dateToJson(updatedAt),
  };

  /// Parses the JSON form.
  factory ImplantRecord.fromJson(Map<String, Object?> json) => ImplantRecord(
    id: json['id'] as String,
    clinicId: json['clinicId'] as String,
    patientId: json['patientId'] as String,
    tooth: toothFromJson(json['tooth']),
    procedureId: json['procedureId'] as String?,
    brand: json['brand'] as String,
    system: json['system'] as String?,
    diameterMm: json['diameterMm'] as num,
    lengthMm: json['lengthMm'] as num,
    lotNumber: json['lotNumber'] as String,
    udi: json['udi'] as String?,
    expiryDate: dateFromJsonOrNull(json['expiryDate']),
    placedAt: dateFromJson(json['placedAt']),
    insertionTorqueNcm: json['insertionTorqueNcm'] as num?,
    graftMaterial: json['graftMaterial'] as String?,
    membrane: json['membrane'] as String?,
    status: enumFromJson(ImplantStatus.values, json['status']),
    note: json['note'] as String?,
    createdAt: dateFromJson(json['createdAt']),
    updatedAt: dateFromJson(json['updatedAt']),
  );
}
