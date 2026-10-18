import 'package:meta/meta.dart';

import '../dental/clinical_enums.dart';
import '../dental/tooth_id.dart';
import '../money/money.dart';
import 'json_support.dart';

/// Kind of prosthetic lab work.
enum LabCaseType {
  crownPfm,
  crownZirconia,
  crownMetal,
  bridge,
  inlayOnlay,
  veneer,
  completeDenture,
  partialDenture,
  castPartial,
  nightGuard,
  aligner,
  retainer,
  implantCrown,
  other,
}

/// An external dental laboratory the clinic sends work to.
@immutable
class Lab {
  /// Creates a lab.
  const Lab({
    required this.id,
    required this.clinicId,
    required this.name,
    this.phone,
    this.whatsappPhone,
    this.turnaroundDays = const {},
    this.isActive = true,
  });

  /// UUID v4.
  final String id;

  /// Owning clinic.
  final String clinicId;

  /// Lab name.
  final String name;

  /// Phone.
  final String? phone;

  /// WhatsApp number for slips and chasers.
  final String? whatsappPhone;

  /// Working-day turnaround by [LabCaseType] name.
  final Map<String, int> turnaroundDays;

  /// Inactive labs are hidden from pickers.
  final bool isActive;

  /// Turnaround for [type], or null when not configured.
  int? turnaroundFor(LabCaseType type) => turnaroundDays[type.name];

  /// Returns a copy with the given fields replaced.
  Lab copyWith({
    String? name,
    String? phone,
    String? whatsappPhone,
    Map<String, int>? turnaroundDays,
    bool? isActive,
  }) => Lab(
    id: id,
    clinicId: clinicId,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    whatsappPhone: whatsappPhone ?? this.whatsappPhone,
    turnaroundDays: turnaroundDays ?? this.turnaroundDays,
    isActive: isActive ?? this.isActive,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'clinicId': clinicId,
    'name': name,
    'phone': phone,
    'whatsappPhone': whatsappPhone,
    'turnaroundDays': turnaroundDays,
    'isActive': isActive,
  };

  /// Parses the JSON form.
  factory Lab.fromJson(Map<String, Object?> json) => Lab(
    id: json['id'] as String,
    clinicId: json['clinicId'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String?,
    whatsappPhone: json['whatsappPhone'] as String?,
    turnaroundDays: intMapFromJson(json['turnaroundDays']),
    isActive: json['isActive'] as bool? ?? true,
  );
}

/// A lab case from impression to fit, with remake tracking.
@immutable
class LabCase {
  /// Creates a lab case.
  const LabCase({
    required this.id,
    required this.clinicId,
    required this.patientId,
    this.procedureId,
    required this.labId,
    required this.caseType,
    this.teeth = const [],
    this.material,
    this.shade,
    this.impressionType,
    this.instructions,
    this.labFee = const Money.zero(),
    this.status = LabCaseStatus.created,
    required this.createdAt,
    this.sentAt,
    this.dueAt,
    this.receivedAt,
    this.qualityCheckedAt,
    this.fittedAt,
    this.remakeReason,
    this.remakeOfCaseId,
    this.slipPdfPath,
    required this.updatedAt,
  });

  /// UUID v4.
  final String id;

  /// Owning clinic.
  final String clinicId;

  /// Patient.
  final String patientId;

  /// Procedure the work is for.
  final String? procedureId;

  /// Lab.
  final String labId;

  /// Kind of work.
  final LabCaseType caseType;

  /// Teeth involved.
  final List<ToothId> teeth;

  /// Material (`Zirconia`, `PFM`).
  final String? material;

  /// Shade (`A2`).
  final String? shade;

  /// Impression type (`PVS`, `intraoral scan`).
  final String? impressionType;

  /// Instructions to the lab.
  final String? instructions;

  /// Lab's fee to the clinic.
  final Money labFee;

  /// Workflow status.
  final LabCaseStatus status;

  /// Row creation time.
  final DateTime createdAt;

  /// When sent.
  final DateTime? sentAt;

  /// Expected return date.
  final DateTime? dueAt;

  /// When received back.
  final DateTime? receivedAt;

  /// When quality checked.
  final DateTime? qualityCheckedAt;

  /// When fitted.
  final DateTime? fittedAt;

  /// Reason for a remake, if this case was remade.
  final String? remakeReason;

  /// Original case this is a remake of.
  final String? remakeOfCaseId;

  /// Rendered lab slip PDF.
  final String? slipPdfPath;

  /// Last modification time.
  final DateTime updatedAt;

  /// Whether the case is overdue as of [asOf].
  bool isOverdue(DateTime asOf) =>
      status.isOpen &&
      receivedAt == null &&
      dueAt != null &&
      asOf.isAfter(dueAt!);

  /// Returns a copy with the given fields replaced.
  LabCase copyWith({
    String? procedureId,
    String? labId,
    LabCaseType? caseType,
    List<ToothId>? teeth,
    String? material,
    String? shade,
    String? impressionType,
    String? instructions,
    Money? labFee,
    LabCaseStatus? status,
    DateTime? sentAt,
    DateTime? dueAt,
    DateTime? receivedAt,
    DateTime? qualityCheckedAt,
    DateTime? fittedAt,
    String? remakeReason,
    String? remakeOfCaseId,
    String? slipPdfPath,
    DateTime? updatedAt,
  }) => LabCase(
    id: id,
    clinicId: clinicId,
    patientId: patientId,
    procedureId: procedureId ?? this.procedureId,
    labId: labId ?? this.labId,
    caseType: caseType ?? this.caseType,
    teeth: teeth ?? this.teeth,
    material: material ?? this.material,
    shade: shade ?? this.shade,
    impressionType: impressionType ?? this.impressionType,
    instructions: instructions ?? this.instructions,
    labFee: labFee ?? this.labFee,
    status: status ?? this.status,
    createdAt: createdAt,
    sentAt: sentAt ?? this.sentAt,
    dueAt: dueAt ?? this.dueAt,
    receivedAt: receivedAt ?? this.receivedAt,
    qualityCheckedAt: qualityCheckedAt ?? this.qualityCheckedAt,
    fittedAt: fittedAt ?? this.fittedAt,
    remakeReason: remakeReason ?? this.remakeReason,
    remakeOfCaseId: remakeOfCaseId ?? this.remakeOfCaseId,
    slipPdfPath: slipPdfPath ?? this.slipPdfPath,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'clinicId': clinicId,
    'patientId': patientId,
    'procedureId': procedureId,
    'labId': labId,
    'caseType': caseType.name,
    'teeth': teethToJson(teeth),
    'material': material,
    'shade': shade,
    'impressionType': impressionType,
    'instructions': instructions,
    'labFee': labFee.toJson(),
    'status': status.name,
    'createdAt': dateToJson(createdAt),
    'sentAt': dateToJson(sentAt),
    'dueAt': dateToJson(dueAt),
    'receivedAt': dateToJson(receivedAt),
    'qualityCheckedAt': dateToJson(qualityCheckedAt),
    'fittedAt': dateToJson(fittedAt),
    'remakeReason': remakeReason,
    'remakeOfCaseId': remakeOfCaseId,
    'slipPdfPath': slipPdfPath,
    'updatedAt': dateToJson(updatedAt),
  };

  /// Parses the JSON form.
  factory LabCase.fromJson(Map<String, Object?> json) => LabCase(
    id: json['id'] as String,
    clinicId: json['clinicId'] as String,
    patientId: json['patientId'] as String,
    procedureId: json['procedureId'] as String?,
    labId: json['labId'] as String,
    caseType: enumFromJson(LabCaseType.values, json['caseType']),
    teeth: teethFromJson(json['teeth']),
    material: json['material'] as String?,
    shade: json['shade'] as String?,
    impressionType: json['impressionType'] as String?,
    instructions: json['instructions'] as String?,
    labFee: moneyFromJsonOrNull(json['labFee']) ?? const Money.zero(),
    status: enumFromJson(LabCaseStatus.values, json['status']),
    createdAt: dateFromJson(json['createdAt']),
    sentAt: dateFromJsonOrNull(json['sentAt']),
    dueAt: dateFromJsonOrNull(json['dueAt']),
    receivedAt: dateFromJsonOrNull(json['receivedAt']),
    qualityCheckedAt: dateFromJsonOrNull(json['qualityCheckedAt']),
    fittedAt: dateFromJsonOrNull(json['fittedAt']),
    remakeReason: json['remakeReason'] as String?,
    remakeOfCaseId: json['remakeOfCaseId'] as String?,
    slipPdfPath: json['slipPdfPath'] as String?,
    updatedAt: dateFromJson(json['updatedAt']),
  );
}

/// Adds [turnaroundWorkingDays] working days to [sentAt], skipping the weekly
/// off ([weeklyOffWeekday], Sunday by default) and any [holidays] (compared
/// by calendar date). The result keeps the time of day of [sentAt].
DateTime computeDueDate(
  DateTime sentAt,
  int turnaroundWorkingDays, {
  Set<DateTime> holidays = const {},
  int weeklyOffWeekday = DateTime.sunday,
}) {
  final holidayKeys = holidays.map(_dateKey).toSet();
  var current = sentAt;
  var remaining = turnaroundWorkingDays;
  while (remaining > 0) {
    current = current.add(const Duration(days: 1));
    final isOff =
        current.weekday == weeklyOffWeekday ||
        holidayKeys.contains(_dateKey(current));
    if (!isOff) remaining--;
  }
  return current;
}

String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';
