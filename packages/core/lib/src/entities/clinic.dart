import 'package:meta/meta.dart';

import '../dental/clinical_enums.dart';
import '../dental/notation.dart';
import 'json_support.dart';

/// A dental clinic: the tenant. Every other tenant-scoped row carries this
/// clinic's [id] as `clinicId`.
@immutable
class Clinic {
  /// Creates a clinic.
  const Clinic({
    required this.id,
    required this.name,
    this.legalName,
    this.addressLines = const [],
    required this.city,
    required this.stateCode,
    required this.pincode,
    required this.phone,
    this.whatsappPhone,
    this.email,
    this.gstin,
    this.defaultNotation = ToothNotation.fdi,
    this.timeZone = 'Asia/Kolkata',
    this.upiVpa,
    this.logoPath,
    required this.createdAt,
    required this.updatedAt,
  });

  /// UUID v4.
  final String id;

  /// Display name printed on documents.
  final String name;

  /// Registered legal name when it differs from [name].
  final String? legalName;

  /// Street address lines.
  final List<String> addressLines;

  /// City or town.
  final String city;

  /// Two-digit GST state code (e.g. `36` Telangana).
  final String stateCode;

  /// Six-digit PIN code.
  final String pincode;

  /// Primary landline / mobile.
  final String phone;

  /// WhatsApp Business number, if different.
  final String? whatsappPhone;

  /// Contact email.
  final String? email;

  /// GSTIN when GST-registered; null means unregistered (receipts only).
  final String? gstin;

  /// Tooth notation shown in the UI; FDI is always stored.
  final ToothNotation defaultNotation;

  /// IANA time zone of the clinic.
  final String timeZone;

  /// UPI VPA used to render a static QR on invoices.
  final String? upiVpa;

  /// Local path of the clinic logo.
  final String? logoPath;

  /// Row creation time.
  final DateTime createdAt;

  /// Last modification time.
  final DateTime updatedAt;

  /// Whether the clinic is GST registered.
  bool get isGstRegistered => gstin != null && gstin!.isNotEmpty;

  /// Returns a copy with the given fields replaced.
  Clinic copyWith({
    String? name,
    String? legalName,
    List<String>? addressLines,
    String? city,
    String? stateCode,
    String? pincode,
    String? phone,
    String? whatsappPhone,
    String? email,
    String? gstin,
    ToothNotation? defaultNotation,
    String? timeZone,
    String? upiVpa,
    String? logoPath,
    DateTime? updatedAt,
  }) => Clinic(
    id: id,
    name: name ?? this.name,
    legalName: legalName ?? this.legalName,
    addressLines: addressLines ?? this.addressLines,
    city: city ?? this.city,
    stateCode: stateCode ?? this.stateCode,
    pincode: pincode ?? this.pincode,
    phone: phone ?? this.phone,
    whatsappPhone: whatsappPhone ?? this.whatsappPhone,
    email: email ?? this.email,
    gstin: gstin ?? this.gstin,
    defaultNotation: defaultNotation ?? this.defaultNotation,
    timeZone: timeZone ?? this.timeZone,
    upiVpa: upiVpa ?? this.upiVpa,
    logoPath: logoPath ?? this.logoPath,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'legalName': legalName,
    'addressLines': addressLines,
    'city': city,
    'stateCode': stateCode,
    'pincode': pincode,
    'phone': phone,
    'whatsappPhone': whatsappPhone,
    'email': email,
    'gstin': gstin,
    'defaultNotation': defaultNotation.name,
    'timeZone': timeZone,
    'upiVpa': upiVpa,
    'logoPath': logoPath,
    'createdAt': dateToJson(createdAt),
    'updatedAt': dateToJson(updatedAt),
  };

  /// Parses the JSON form.
  factory Clinic.fromJson(Map<String, Object?> json) => Clinic(
    id: json['id'] as String,
    name: json['name'] as String,
    legalName: json['legalName'] as String?,
    addressLines: stringListFromJson(json['addressLines']),
    city: json['city'] as String,
    stateCode: json['stateCode'] as String,
    pincode: json['pincode'] as String,
    phone: json['phone'] as String,
    whatsappPhone: json['whatsappPhone'] as String?,
    email: json['email'] as String?,
    gstin: json['gstin'] as String?,
    defaultNotation: enumFromJson(
      ToothNotation.values,
      json['defaultNotation'],
    ),
    timeZone: json['timeZone'] as String? ?? 'Asia/Kolkata',
    upiVpa: json['upiVpa'] as String?,
    logoPath: json['logoPath'] as String?,
    createdAt: dateFromJson(json['createdAt']),
    updatedAt: dateFromJson(json['updatedAt']),
  );
}

/// A dental chair (operatory) that appointments are booked against.
@immutable
class Chair {
  /// Creates a chair.
  const Chair({
    required this.id,
    required this.clinicId,
    required this.name,
    this.sortOrder = 0,
    this.isActive = true,
  });

  /// UUID v4.
  final String id;

  /// Owning clinic.
  final String clinicId;

  /// Short label (`Chair 1`, `Surgery`).
  final String name;

  /// Display order in the appointment book.
  final int sortOrder;

  /// Inactive chairs are hidden from booking but kept for history.
  final bool isActive;

  /// Returns a copy with the given fields replaced.
  Chair copyWith({String? name, int? sortOrder, bool? isActive}) => Chair(
    id: id,
    clinicId: clinicId,
    name: name ?? this.name,
    sortOrder: sortOrder ?? this.sortOrder,
    isActive: isActive ?? this.isActive,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'clinicId': clinicId,
    'name': name,
    'sortOrder': sortOrder,
    'isActive': isActive,
  };

  /// Parses the JSON form.
  factory Chair.fromJson(Map<String, Object?> json) => Chair(
    id: json['id'] as String,
    clinicId: json['clinicId'] as String,
    name: json['name'] as String,
    sortOrder: json['sortOrder'] as int? ?? 0,
    isActive: json['isActive'] as bool? ?? true,
  );
}

/// A person working at a clinic: dentist, specialist, reception, assistant,
/// accountant or lab contact. Registration details feed every prescription,
/// certificate and receipt (DCI Code 3.4.1).
@immutable
class ClinicMember {
  /// Creates a clinic member.
  const ClinicMember({
    required this.id,
    required this.clinicId,
    required this.displayName,
    required this.role,
    this.registrationNumber,
    this.registrationCouncil,
    this.qualifications = const [],
    this.hprId,
    required this.phone,
    this.email,
    this.feeSharePercent,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// UUID v4.
  final String id;

  /// Owning clinic.
  final String clinicId;

  /// Name as printed on documents (`Dr. A. Rao`).
  final String displayName;

  /// Role driving permissions and fee-share rules.
  final ClinicRole role;

  /// State Dental Council registration number (clinicians).
  final String? registrationNumber;

  /// Issuing council (`Telangana State Dental Council`).
  final String? registrationCouncil;

  /// Degrees (`BDS`, `MDS (Endodontics)`).
  final List<String> qualifications;

  /// ABDM Healthcare Professional Registry id.
  final String? hprId;

  /// Mobile number (also the login identity).
  final String phone;

  /// Email, optional.
  final String? email;

  /// Fee share for visiting specialists, percent of net fee.
  final num? feeSharePercent;

  /// Inactive members cannot log in but remain on historical records.
  final bool isActive;

  /// Row creation time.
  final DateTime createdAt;

  /// Last modification time.
  final DateTime updatedAt;

  /// Whether this member can author clinical records.
  bool get isClinician => role.isClinician;

  /// Returns a copy with the given fields replaced.
  ClinicMember copyWith({
    String? displayName,
    ClinicRole? role,
    String? registrationNumber,
    String? registrationCouncil,
    List<String>? qualifications,
    String? hprId,
    String? phone,
    String? email,
    num? feeSharePercent,
    bool? isActive,
    DateTime? updatedAt,
  }) => ClinicMember(
    id: id,
    clinicId: clinicId,
    displayName: displayName ?? this.displayName,
    role: role ?? this.role,
    registrationNumber: registrationNumber ?? this.registrationNumber,
    registrationCouncil: registrationCouncil ?? this.registrationCouncil,
    qualifications: qualifications ?? this.qualifications,
    hprId: hprId ?? this.hprId,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    feeSharePercent: feeSharePercent ?? this.feeSharePercent,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'clinicId': clinicId,
    'displayName': displayName,
    'role': role.name,
    'registrationNumber': registrationNumber,
    'registrationCouncil': registrationCouncil,
    'qualifications': qualifications,
    'hprId': hprId,
    'phone': phone,
    'email': email,
    'feeSharePercent': feeSharePercent,
    'isActive': isActive,
    'createdAt': dateToJson(createdAt),
    'updatedAt': dateToJson(updatedAt),
  };

  /// Parses the JSON form.
  factory ClinicMember.fromJson(Map<String, Object?> json) => ClinicMember(
    id: json['id'] as String,
    clinicId: json['clinicId'] as String,
    displayName: json['displayName'] as String,
    role: enumFromJson(ClinicRole.values, json['role']),
    registrationNumber: json['registrationNumber'] as String?,
    registrationCouncil: json['registrationCouncil'] as String?,
    qualifications: stringListFromJson(json['qualifications']),
    hprId: json['hprId'] as String?,
    phone: json['phone'] as String,
    email: json['email'] as String?,
    feeSharePercent: json['feeSharePercent'] as num?,
    isActive: json['isActive'] as bool? ?? true,
    createdAt: dateFromJson(json['createdAt']),
    updatedAt: dateFromJson(json['updatedAt']),
  );
}
