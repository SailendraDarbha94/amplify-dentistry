import 'package:meta/meta.dart';

import '../dental/clinical_enums.dart';
import 'drug.dart';
import 'json_support.dart';

/// One drug on a prescription (frozen copy of the drug master values).
@immutable
class PrescriptionLine {
  /// Creates a prescription line.
  const PrescriptionLine({
    this.drugId,
    required this.genericName,
    this.brandName,
    required this.strength,
    required this.form,
    required this.dose,
    required this.frequency,
    required this.durationDays,
    required this.quantity,
    required this.route,
    this.instructions,
    this.schedule = DrugSchedule.h,
  });

  /// Drug master id, null for a free-typed drug.
  final String? drugId;

  /// Generic name (always printed; Code 1.5).
  final String genericName;

  /// Brand name, if prescribed by brand.
  final String? brandName;

  /// Strength.
  final String strength;

  /// Dosage form.
  final DrugForm form;

  /// Dose (`1 tab`).
  final String dose;

  /// Frequency (`TDS`, `1-0-1`).
  final String frequency;

  /// Course length in days.
  final int durationDays;

  /// Total units to dispense.
  final int quantity;

  /// Route.
  final String route;

  /// Instructions (`after food`).
  final String? instructions;

  /// Schedule at the time of prescribing.
  final DrugSchedule schedule;

  /// Returns a copy with the given fields replaced.
  PrescriptionLine copyWith({
    String? brandName,
    String? dose,
    String? frequency,
    int? durationDays,
    int? quantity,
    String? instructions,
  }) => PrescriptionLine(
    drugId: drugId,
    genericName: genericName,
    brandName: brandName ?? this.brandName,
    strength: strength,
    form: form,
    dose: dose ?? this.dose,
    frequency: frequency ?? this.frequency,
    durationDays: durationDays ?? this.durationDays,
    quantity: quantity ?? this.quantity,
    route: route,
    instructions: instructions ?? this.instructions,
    schedule: schedule,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'drugId': drugId,
    'genericName': genericName,
    'brandName': brandName,
    'strength': strength,
    'form': form.name,
    'dose': dose,
    'frequency': frequency,
    'durationDays': durationDays,
    'quantity': quantity,
    'route': route,
    'instructions': instructions,
    'schedule': schedule.name,
  };

  /// Parses the JSON form.
  factory PrescriptionLine.fromJson(Map<String, Object?> json) =>
      PrescriptionLine(
        drugId: json['drugId'] as String?,
        genericName: json['genericName'] as String,
        brandName: json['brandName'] as String?,
        strength: json['strength'] as String,
        form: enumFromJson(DrugForm.values, json['form']),
        dose: json['dose'] as String,
        frequency: json['frequency'] as String,
        durationDays: json['durationDays'] as int,
        quantity: json['quantity'] as int,
        route: json['route'] as String,
        instructions: json['instructions'] as String?,
        schedule: enumFromJson(DrugSchedule.values, json['schedule']),
      );
}

/// A signed prescription. Prescriber identity and registration number are
/// frozen onto the row (DCI Code 3.4.1).
@immutable
class Prescription {
  /// Creates a prescription.
  const Prescription({
    required this.id,
    required this.clinicId,
    required this.patientId,
    this.visitId,
    required this.prescriberId,
    required this.prescriberName,
    required this.prescriberRegistrationNumber,
    this.prescriberQualifications = const [],
    required this.issuedAt,
    this.diagnosis,
    this.lines = const [],
    this.isRepeatable = false,
    this.dispensedByClinic = false,
    required this.verificationCode,
    this.documentHash,
    this.pdfPath,
    required this.createdAt,
  });

  /// UUID v4.
  final String id;

  /// Owning clinic.
  final String clinicId;

  /// Patient.
  final String patientId;

  /// Visit, if any.
  final String? visitId;

  /// Prescribing clinician.
  final String prescriberId;

  /// Prescriber name as printed.
  final String prescriberName;

  /// Registration number as printed.
  final String prescriberRegistrationNumber;

  /// Qualifications as printed.
  final List<String> prescriberQualifications;

  /// Issue time.
  final DateTime issuedAt;

  /// Diagnosis printed on the Rx.
  final String? diagnosis;

  /// Lines.
  final List<PrescriptionLine> lines;

  /// Whether the Rx may be refilled.
  final bool isRepeatable;

  /// Whether the clinic dispensed the drugs itself.
  final bool dispensedByClinic;

  /// Short code printed for pharmacist verification.
  final String verificationCode;

  /// SHA-256 of the rendered document.
  final String? documentHash;

  /// Rendered PDF path.
  final String? pdfPath;

  /// Row creation time.
  final DateTime createdAt;

  /// Whether any line is Schedule H1 (retailer register required).
  bool get hasScheduleH1 => lines.any((l) => l.schedule == DrugSchedule.h1);

  /// Returns a copy with the given fields replaced.
  Prescription copyWith({
    String? diagnosis,
    List<PrescriptionLine>? lines,
    bool? isRepeatable,
    bool? dispensedByClinic,
    String? documentHash,
    String? pdfPath,
  }) => Prescription(
    id: id,
    clinicId: clinicId,
    patientId: patientId,
    visitId: visitId,
    prescriberId: prescriberId,
    prescriberName: prescriberName,
    prescriberRegistrationNumber: prescriberRegistrationNumber,
    prescriberQualifications: prescriberQualifications,
    issuedAt: issuedAt,
    diagnosis: diagnosis ?? this.diagnosis,
    lines: lines ?? this.lines,
    isRepeatable: isRepeatable ?? this.isRepeatable,
    dispensedByClinic: dispensedByClinic ?? this.dispensedByClinic,
    verificationCode: verificationCode,
    documentHash: documentHash ?? this.documentHash,
    pdfPath: pdfPath ?? this.pdfPath,
    createdAt: createdAt,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'clinicId': clinicId,
    'patientId': patientId,
    'visitId': visitId,
    'prescriberId': prescriberId,
    'prescriberName': prescriberName,
    'prescriberRegistrationNumber': prescriberRegistrationNumber,
    'prescriberQualifications': prescriberQualifications,
    'issuedAt': dateToJson(issuedAt),
    'diagnosis': diagnosis,
    'lines': lines.map((l) => l.toJson()).toList(),
    'isRepeatable': isRepeatable,
    'dispensedByClinic': dispensedByClinic,
    'verificationCode': verificationCode,
    'documentHash': documentHash,
    'pdfPath': pdfPath,
    'createdAt': dateToJson(createdAt),
  };

  /// Parses the JSON form.
  factory Prescription.fromJson(Map<String, Object?> json) => Prescription(
    id: json['id'] as String,
    clinicId: json['clinicId'] as String,
    patientId: json['patientId'] as String,
    visitId: json['visitId'] as String?,
    prescriberId: json['prescriberId'] as String,
    prescriberName: json['prescriberName'] as String,
    prescriberRegistrationNumber:
        json['prescriberRegistrationNumber'] as String,
    prescriberQualifications: stringListFromJson(
      json['prescriberQualifications'],
    ),
    issuedAt: dateFromJson(json['issuedAt']),
    diagnosis: json['diagnosis'] as String?,
    lines:
        (json['lines'] as List?)
            ?.map(
              (e) =>
                  PrescriptionLine.fromJson((e as Map).cast<String, Object?>()),
            )
            .toList() ??
        const [],
    isRepeatable: json['isRepeatable'] as bool? ?? false,
    dispensedByClinic: json['dispensedByClinic'] as bool? ?? false,
    verificationCode: json['verificationCode'] as String,
    documentHash: json['documentHash'] as String?,
    pdfPath: json['pdfPath'] as String?,
    createdAt: dateFromJson(json['createdAt']),
  );
}
