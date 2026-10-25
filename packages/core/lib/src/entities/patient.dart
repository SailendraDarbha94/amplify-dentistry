import 'package:meta/meta.dart';

import '../dental/clinical_enums.dart';
import 'json_support.dart';

/// A patient of one clinic. Age may be known from [dateOfBirth] or recorded
/// approximately ([approxAgeYears] at [ageRecordedAt]) when the DOB is
/// unknown, which is common in Indian practice.
/// Whether a patient is an adult, a minor, or of unknown age (no date of
/// birth and no approximate age on record). Unknown is never silently treated
/// as adult: consent, messaging and guardian rules must resolve it first.
enum AgeStatus {
  /// 18 or older.
  adult,

  /// Under 18.
  minor,

  /// No date of birth or approximate age recorded.
  unknown,
}

@immutable
class Patient {
  /// Creates a patient.
  const Patient({
    required this.id,
    required this.clinicId,
    required this.patientNumber,
    required this.firstName,
    this.lastName,
    required this.phone,
    this.altPhone,
    this.email,
    this.dateOfBirth,
    this.approxAgeYears,
    this.ageRecordedAt,
    this.sex = Sex.unspecified,
    this.addressLines = const [],
    this.city,
    this.pincode,
    this.abhaNumber,
    this.abhaAddress,
    this.guardianName,
    this.guardianRelation,
    this.guardianPhone,
    this.preferredLanguage = 'en',
    this.tags = const [],
    this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// UUID v4.
  final String id;

  /// Owning clinic.
  final String clinicId;

  /// Clinic-local human number such as `P-00001`.
  final String patientNumber;

  /// Given name.
  final String firstName;

  /// Family name, optional (single-name patients are common).
  final String? lastName;

  /// Primary mobile.
  final String phone;

  /// Alternate phone.
  final String? altPhone;

  /// Email, optional.
  final String? email;

  /// Date of birth when known.
  final DateTime? dateOfBirth;

  /// Approximate age in years when [dateOfBirth] is unknown.
  final num? approxAgeYears;

  /// When [approxAgeYears] was recorded, so it can be aged forward.
  final DateTime? ageRecordedAt;

  /// Sex as recorded for prescriptions.
  final Sex sex;

  /// Street address lines.
  final List<String> addressLines;

  /// City or town.
  final String? city;

  /// PIN code.
  final String? pincode;

  /// 14-digit ABHA number (encrypted at rest by the data layer).
  final String? abhaNumber;

  /// ABHA address (`name@abdm`).
  final String? abhaAddress;

  /// Guardian name; required for minors.
  final String? guardianName;

  /// Guardian relation (`father`, `mother`, `guardian`).
  final String? guardianRelation;

  /// Guardian phone; all messaging for a minor goes here.
  final String? guardianPhone;

  /// BCP-47 language code for messages (`en`, `hi`, `te`).
  final String preferredLanguage;

  /// Free-form tags (`vip`, `anxious`, `ortho`).
  final List<String> tags;

  /// Front-desk notes.
  final String? notes;

  /// Inactive patients are hidden from search but never deleted.
  final bool isActive;

  /// Row creation time.
  final DateTime createdAt;

  /// Last modification time.
  final DateTime updatedAt;

  /// Full name for display.
  String get displayName => lastName == null || lastName!.isEmpty
      ? firstName
      : '$firstName $lastName';

  /// Age in years as of [asOf], from the DOB or the recorded approximate age
  /// aged forward; null when neither is known.
  double? ageYears(DateTime asOf) {
    final dob = dateOfBirth;
    if (dob != null) return _yearsBetween(dob, asOf);
    final approx = approxAgeYears;
    if (approx == null) return null;
    final recorded = ageRecordedAt;
    if (recorded == null) return approx.toDouble();
    return approx + _yearsBetween(recorded, asOf);
  }

  /// Whether a date of birth or an approximate age is on record.
  bool get hasKnownAge => dateOfBirth != null || approxAgeYears != null;

  /// Tri-state age status at [asOf]: [AgeStatus.unknown] when neither a date
  /// of birth nor an approximate age is recorded.
  AgeStatus ageStatus(DateTime asOf) {
    final age = ageYears(asOf);
    if (age == null) return AgeStatus.unknown;
    return age < 18 ? AgeStatus.minor : AgeStatus.adult;
  }

  /// Whether the patient is known to be under 18 at [asOf]. Unknown age
  /// returns false here; use [ageStatus] or [isMinorOrNull] where an unknown
  /// age must block (consent, messaging, guardian rules).
  bool isMinor(DateTime asOf) => ageStatus(asOf) == AgeStatus.minor;

  /// True for a minor, false for an adult, null when the age is unknown.
  bool? isMinorOrNull(DateTime asOf) => switch (ageStatus(asOf)) {
    AgeStatus.minor => true,
    AgeStatus.adult => false,
    AgeStatus.unknown => null,
  };

  /// Whether a guardian must be recorded before the patient can be treated or
  /// messaged: true for a minor without a guardian name and phone, and true
  /// when the age is unknown (it must be resolved first).
  bool requiresGuardian(DateTime asOf) => switch (ageStatus(asOf)) {
    AgeStatus.adult => false,
    AgeStatus.unknown => true,
    AgeStatus.minor =>
      (guardianName ?? '').isEmpty || (guardianPhone ?? '').isEmpty,
  };

  /// Phone that notifications go to: the guardian's for a minor when one is
  /// recorded, otherwise the patient's own.
  String messagingPhone(DateTime asOf) {
    final gp = guardianPhone;
    if (isMinor(asOf) && gp != null && gp.isNotEmpty) return gp;
    return phone;
  }

  static double _yearsBetween(DateTime from, DateTime to) =>
      to.difference(from).inDays / 365.25;

  /// Returns a copy with the given fields replaced.
  Patient copyWith({
    String? patientNumber,
    String? firstName,
    String? lastName,
    String? phone,
    String? altPhone,
    String? email,
    DateTime? dateOfBirth,
    num? approxAgeYears,
    DateTime? ageRecordedAt,
    Sex? sex,
    List<String>? addressLines,
    String? city,
    String? pincode,
    String? abhaNumber,
    String? abhaAddress,
    String? guardianName,
    String? guardianRelation,
    String? guardianPhone,
    String? preferredLanguage,
    List<String>? tags,
    String? notes,
    bool? isActive,
    DateTime? updatedAt,
  }) => Patient(
    id: id,
    clinicId: clinicId,
    patientNumber: patientNumber ?? this.patientNumber,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    phone: phone ?? this.phone,
    altPhone: altPhone ?? this.altPhone,
    email: email ?? this.email,
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    approxAgeYears: approxAgeYears ?? this.approxAgeYears,
    ageRecordedAt: ageRecordedAt ?? this.ageRecordedAt,
    sex: sex ?? this.sex,
    addressLines: addressLines ?? this.addressLines,
    city: city ?? this.city,
    pincode: pincode ?? this.pincode,
    abhaNumber: abhaNumber ?? this.abhaNumber,
    abhaAddress: abhaAddress ?? this.abhaAddress,
    guardianName: guardianName ?? this.guardianName,
    guardianRelation: guardianRelation ?? this.guardianRelation,
    guardianPhone: guardianPhone ?? this.guardianPhone,
    preferredLanguage: preferredLanguage ?? this.preferredLanguage,
    tags: tags ?? this.tags,
    notes: notes ?? this.notes,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'clinicId': clinicId,
    'patientNumber': patientNumber,
    'firstName': firstName,
    'lastName': lastName,
    'phone': phone,
    'altPhone': altPhone,
    'email': email,
    'dateOfBirth': dateToJson(dateOfBirth),
    'approxAgeYears': approxAgeYears,
    'ageRecordedAt': dateToJson(ageRecordedAt),
    'sex': sex.name,
    'addressLines': addressLines,
    'city': city,
    'pincode': pincode,
    'abhaNumber': abhaNumber,
    'abhaAddress': abhaAddress,
    'guardianName': guardianName,
    'guardianRelation': guardianRelation,
    'guardianPhone': guardianPhone,
    'preferredLanguage': preferredLanguage,
    'tags': tags,
    'notes': notes,
    'isActive': isActive,
    'createdAt': dateToJson(createdAt),
    'updatedAt': dateToJson(updatedAt),
  };

  /// Parses the JSON form.
  factory Patient.fromJson(Map<String, Object?> json) => Patient(
    id: json['id'] as String,
    clinicId: json['clinicId'] as String,
    patientNumber: json['patientNumber'] as String,
    firstName: json['firstName'] as String,
    lastName: json['lastName'] as String?,
    phone: json['phone'] as String,
    altPhone: json['altPhone'] as String?,
    email: json['email'] as String?,
    dateOfBirth: dateFromJsonOrNull(json['dateOfBirth']),
    approxAgeYears: json['approxAgeYears'] as num?,
    ageRecordedAt: dateFromJsonOrNull(json['ageRecordedAt']),
    sex: enumFromJsonOrNull(Sex.values, json['sex']) ?? Sex.unspecified,
    addressLines: stringListFromJson(json['addressLines']),
    city: json['city'] as String?,
    pincode: json['pincode'] as String?,
    abhaNumber: json['abhaNumber'] as String?,
    abhaAddress: json['abhaAddress'] as String?,
    guardianName: json['guardianName'] as String?,
    guardianRelation: json['guardianRelation'] as String?,
    guardianPhone: json['guardianPhone'] as String?,
    preferredLanguage: json['preferredLanguage'] as String? ?? 'en',
    tags: stringListFromJson(json['tags']),
    notes: json['notes'] as String?,
    isActive: json['isActive'] as bool? ?? true,
    createdAt: dateFromJson(json['createdAt']),
    updatedAt: dateFromJson(json['updatedAt']),
  );
}
