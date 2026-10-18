import 'package:meta/meta.dart';

import 'json_support.dart';

/// Autoclave cycle class (EN 13060) or chemical sterilisation.
enum SterilisationCycleType { classB, classN, classS, chemical }

/// Result of a biological (spore) indicator.
enum BiologicalIndicatorResult { notDone, pending, pass, fail }

/// Kind of regulatory licence or registration a clinic must hold.
enum LicenceKind {
  aerbRegistration,
  biomedicalWasteAuthorisation,
  clinicalEstablishmentRegistration,
  tradeLicence,
  fireNoc,
  gstRegistration,
  dentalCouncilRegistration,
  other,
}

/// One autoclave / sterilisation run in the sterilisation register.
@immutable
class SterilisationCycle {
  /// Creates a sterilisation cycle.
  const SterilisationCycle({
    required this.id,
    required this.clinicId,
    required this.cycleNumber,
    required this.autoclaveName,
    required this.cycledAt,
    required this.cycleType,
    this.temperatureC,
    this.pressureKpa,
    this.durationMinutes,
    this.chemicalIndicatorPassed = true,
    this.biologicalIndicatorResult,
    this.loadContents,
    required this.operatorId,
    this.note,
    required this.createdAt,
  });

  /// UUID v4.
  final String id;

  /// Owning clinic.
  final String clinicId;

  /// Sequential cycle number printed on pouches.
  final String cycleNumber;

  /// Autoclave identifier.
  final String autoclaveName;

  /// Run time.
  final DateTime cycledAt;

  /// Cycle type.
  final SterilisationCycleType cycleType;

  /// Peak temperature, Celsius.
  final num? temperatureC;

  /// Peak pressure, kPa.
  final num? pressureKpa;

  /// Hold time in minutes.
  final int? durationMinutes;

  /// Whether the chemical indicator changed as expected.
  final bool chemicalIndicatorPassed;

  /// Spore test result, when a spore test was run.
  final BiologicalIndicatorResult? biologicalIndicatorResult;

  /// What was in the load.
  final String? loadContents;

  /// Member who ran the cycle.
  final String operatorId;

  /// Note.
  final String? note;

  /// Row creation time.
  final DateTime createdAt;

  /// Whether the cycle can be relied on (chemical indicator passed and no
  /// failed spore test).
  bool get passed =>
      chemicalIndicatorPassed &&
      biologicalIndicatorResult != BiologicalIndicatorResult.fail;

  /// Returns a copy with the given fields replaced.
  SterilisationCycle copyWith({
    num? temperatureC,
    num? pressureKpa,
    int? durationMinutes,
    bool? chemicalIndicatorPassed,
    BiologicalIndicatorResult? biologicalIndicatorResult,
    String? loadContents,
    String? note,
  }) => SterilisationCycle(
    id: id,
    clinicId: clinicId,
    cycleNumber: cycleNumber,
    autoclaveName: autoclaveName,
    cycledAt: cycledAt,
    cycleType: cycleType,
    temperatureC: temperatureC ?? this.temperatureC,
    pressureKpa: pressureKpa ?? this.pressureKpa,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    chemicalIndicatorPassed:
        chemicalIndicatorPassed ?? this.chemicalIndicatorPassed,
    biologicalIndicatorResult:
        biologicalIndicatorResult ?? this.biologicalIndicatorResult,
    loadContents: loadContents ?? this.loadContents,
    operatorId: operatorId,
    note: note ?? this.note,
    createdAt: createdAt,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'clinicId': clinicId,
    'cycleNumber': cycleNumber,
    'autoclaveName': autoclaveName,
    'cycledAt': dateToJson(cycledAt),
    'cycleType': cycleType.name,
    'temperatureC': temperatureC,
    'pressureKpa': pressureKpa,
    'durationMinutes': durationMinutes,
    'chemicalIndicatorPassed': chemicalIndicatorPassed,
    'biologicalIndicatorResult': biologicalIndicatorResult?.name,
    'loadContents': loadContents,
    'operatorId': operatorId,
    'note': note,
    'createdAt': dateToJson(createdAt),
  };

  /// Parses the JSON form.
  factory SterilisationCycle.fromJson(
    Map<String, Object?> json,
  ) => SterilisationCycle(
    id: json['id'] as String,
    clinicId: json['clinicId'] as String,
    cycleNumber: json['cycleNumber'] as String,
    autoclaveName: json['autoclaveName'] as String,
    cycledAt: dateFromJson(json['cycledAt']),
    cycleType: enumFromJson(SterilisationCycleType.values, json['cycleType']),
    temperatureC: json['temperatureC'] as num?,
    pressureKpa: json['pressureKpa'] as num?,
    durationMinutes: json['durationMinutes'] as int?,
    chemicalIndicatorPassed: json['chemicalIndicatorPassed'] as bool? ?? true,
    biologicalIndicatorResult: enumFromJsonOrNull(
      BiologicalIndicatorResult.values,
      json['biologicalIndicatorResult'],
    ),
    loadContents: json['loadContents'] as String?,
    operatorId: json['operatorId'] as String,
    note: json['note'] as String?,
    createdAt: dateFromJson(json['createdAt']),
  );
}

/// A licence / registration with its expiry and QA due dates.
@immutable
class Licence {
  /// Creates a licence.
  const Licence({
    required this.id,
    required this.clinicId,
    required this.kind,
    required this.identifier,
    this.authority,
    this.issuedAt,
    this.expiresAt,
    this.qaDueAt,
    this.documentPath,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  /// UUID v4.
  final String id;

  /// Owning clinic.
  final String clinicId;

  /// Kind.
  final LicenceKind kind;

  /// Licence / registration number.
  final String identifier;

  /// Issuing authority.
  final String? authority;

  /// Issue date.
  final DateTime? issuedAt;

  /// Expiry date.
  final DateTime? expiresAt;

  /// Next quality-assurance test due (AERB X-ray QA every two years).
  final DateTime? qaDueAt;

  /// Scanned document path.
  final String? documentPath;

  /// Note.
  final String? note;

  /// Row creation time.
  final DateTime createdAt;

  /// Last modification time.
  final DateTime updatedAt;

  /// Days until expiry as of [asOf]; negative when expired, null when the
  /// licence has no expiry.
  int? daysToExpiry(DateTime asOf) => expiresAt?.difference(asOf).inDays;

  /// Returns a copy with the given fields replaced.
  Licence copyWith({
    String? identifier,
    String? authority,
    DateTime? issuedAt,
    DateTime? expiresAt,
    DateTime? qaDueAt,
    String? documentPath,
    String? note,
    DateTime? updatedAt,
  }) => Licence(
    id: id,
    clinicId: clinicId,
    kind: kind,
    identifier: identifier ?? this.identifier,
    authority: authority ?? this.authority,
    issuedAt: issuedAt ?? this.issuedAt,
    expiresAt: expiresAt ?? this.expiresAt,
    qaDueAt: qaDueAt ?? this.qaDueAt,
    documentPath: documentPath ?? this.documentPath,
    note: note ?? this.note,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'clinicId': clinicId,
    'kind': kind.name,
    'identifier': identifier,
    'authority': authority,
    'issuedAt': dateToJson(issuedAt),
    'expiresAt': dateToJson(expiresAt),
    'qaDueAt': dateToJson(qaDueAt),
    'documentPath': documentPath,
    'note': note,
    'createdAt': dateToJson(createdAt),
    'updatedAt': dateToJson(updatedAt),
  };

  /// Parses the JSON form.
  factory Licence.fromJson(Map<String, Object?> json) => Licence(
    id: json['id'] as String,
    clinicId: json['clinicId'] as String,
    kind: enumFromJson(LicenceKind.values, json['kind']),
    identifier: json['identifier'] as String,
    authority: json['authority'] as String?,
    issuedAt: dateFromJsonOrNull(json['issuedAt']),
    expiresAt: dateFromJsonOrNull(json['expiresAt']),
    qaDueAt: dateFromJsonOrNull(json['qaDueAt']),
    documentPath: json['documentPath'] as String?,
    note: json['note'] as String?,
    createdAt: dateFromJson(json['createdAt']),
    updatedAt: dateFromJson(json['updatedAt']),
  );
}
