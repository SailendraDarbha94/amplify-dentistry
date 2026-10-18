import 'package:meta/meta.dart';

import '../dental/tooth_id.dart';
import 'json_support.dart';

/// Capacity in which a consent form was signed.
enum SignerRelation { self, parent, guardian, spouse, attendant }

/// Purposes for DPDP (Digital Personal Data Protection Act) consent.
enum DataPurpose {
  treatmentRecords,
  billing,
  appointmentReminders,
  recallReminders,
  marketing,
  photoUse,
  thirdPartySharing,
  research,
}

/// Informed consent for a procedure or plan: the rendered text, the teeth,
/// the signer's capacity, the signature and a hash of the whole document.
/// Never merged with [DataConsent].
@immutable
class ConsentRecord {
  /// Creates a consent record.
  const ConsentRecord({
    required this.id,
    required this.clinicId,
    required this.patientId,
    required this.templateCode,
    required this.templateVersionHash,
    required this.languageCode,
    this.procedureIds = const [],
    this.planId,
    this.teeth = const [],
    required this.renderedText,
    required this.signerName,
    required this.signerRelation,
    this.signerPhone,
    this.signatureImagePath,
    this.otpVerified = false,
    required this.signedAt,
    required this.dentistId,
    required this.dentistRegistrationNumber,
    this.discussionNote,
    this.witnessName,
    required this.deviceId,
    required this.documentHash,
    this.pdfPath,
    required this.createdAt,
  });

  /// UUID v4.
  final String id;

  /// Owning clinic.
  final String clinicId;

  /// Patient.
  final String patientId;

  /// Consent template code (`rct`, `extraction`).
  final String templateCode;

  /// Hash of the template version used, so later edits do not alter history.
  final String templateVersionHash;

  /// Language the form was rendered in.
  final String languageCode;

  /// Procedures consented to.
  final List<String> procedureIds;

  /// Plan consented to, if plan-level.
  final String? planId;

  /// Teeth named in the consent.
  final List<ToothId> teeth;

  /// Full rendered text as shown to the signer.
  final String renderedText;

  /// Signer's name.
  final String signerName;

  /// Signer's capacity.
  final SignerRelation signerRelation;

  /// Signer's phone (for OTP).
  final String? signerPhone;

  /// Captured signature image.
  final String? signatureImagePath;

  /// Whether an OTP confirmed the signer's phone.
  final bool otpVerified;

  /// Signing time.
  final DateTime signedAt;

  /// Dentist who obtained consent.
  final String dentistId;

  /// Registration number printed on the form.
  final String dentistRegistrationNumber;

  /// Note of the risks/alternatives discussion.
  final String? discussionNote;

  /// Witness, if any.
  final String? witnessName;

  /// Device that captured the consent.
  final String deviceId;

  /// SHA-256 over text, teeth, signer and signature.
  final String documentHash;

  /// Rendered PDF path.
  final String? pdfPath;

  /// Row creation time.
  final DateTime createdAt;

  /// Returns a copy with the given fields replaced.
  ConsentRecord copyWith({
    String? signatureImagePath,
    bool? otpVerified,
    String? discussionNote,
    String? witnessName,
    String? documentHash,
    String? pdfPath,
  }) => ConsentRecord(
    id: id,
    clinicId: clinicId,
    patientId: patientId,
    templateCode: templateCode,
    templateVersionHash: templateVersionHash,
    languageCode: languageCode,
    procedureIds: procedureIds,
    planId: planId,
    teeth: teeth,
    renderedText: renderedText,
    signerName: signerName,
    signerRelation: signerRelation,
    signerPhone: signerPhone,
    signatureImagePath: signatureImagePath ?? this.signatureImagePath,
    otpVerified: otpVerified ?? this.otpVerified,
    signedAt: signedAt,
    dentistId: dentistId,
    dentistRegistrationNumber: dentistRegistrationNumber,
    discussionNote: discussionNote ?? this.discussionNote,
    witnessName: witnessName ?? this.witnessName,
    deviceId: deviceId,
    documentHash: documentHash ?? this.documentHash,
    pdfPath: pdfPath ?? this.pdfPath,
    createdAt: createdAt,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'clinicId': clinicId,
    'patientId': patientId,
    'templateCode': templateCode,
    'templateVersionHash': templateVersionHash,
    'languageCode': languageCode,
    'procedureIds': procedureIds,
    'planId': planId,
    'teeth': teethToJson(teeth),
    'renderedText': renderedText,
    'signerName': signerName,
    'signerRelation': signerRelation.name,
    'signerPhone': signerPhone,
    'signatureImagePath': signatureImagePath,
    'otpVerified': otpVerified,
    'signedAt': dateToJson(signedAt),
    'dentistId': dentistId,
    'dentistRegistrationNumber': dentistRegistrationNumber,
    'discussionNote': discussionNote,
    'witnessName': witnessName,
    'deviceId': deviceId,
    'documentHash': documentHash,
    'pdfPath': pdfPath,
    'createdAt': dateToJson(createdAt),
  };

  /// Parses the JSON form.
  factory ConsentRecord.fromJson(Map<String, Object?> json) => ConsentRecord(
    id: json['id'] as String,
    clinicId: json['clinicId'] as String,
    patientId: json['patientId'] as String,
    templateCode: json['templateCode'] as String,
    templateVersionHash: json['templateVersionHash'] as String,
    languageCode: json['languageCode'] as String,
    procedureIds: stringListFromJson(json['procedureIds']),
    planId: json['planId'] as String?,
    teeth: teethFromJson(json['teeth']),
    renderedText: json['renderedText'] as String,
    signerName: json['signerName'] as String,
    signerRelation: enumFromJson(SignerRelation.values, json['signerRelation']),
    signerPhone: json['signerPhone'] as String?,
    signatureImagePath: json['signatureImagePath'] as String?,
    otpVerified: json['otpVerified'] as bool? ?? false,
    signedAt: dateFromJson(json['signedAt']),
    dentistId: json['dentistId'] as String,
    dentistRegistrationNumber: json['dentistRegistrationNumber'] as String,
    discussionNote: json['discussionNote'] as String?,
    witnessName: json['witnessName'] as String?,
    deviceId: json['deviceId'] as String,
    documentHash: json['documentHash'] as String,
    pdfPath: json['pdfPath'] as String?,
    createdAt: dateFromJson(json['createdAt']),
  );
}

/// DPDP purpose-scoped data-processing consent. One row per grant or
/// withdrawal event per purpose.
@immutable
class DataConsent {
  /// Creates a data consent.
  const DataConsent({
    required this.id,
    required this.clinicId,
    required this.patientId,
    required this.purpose,
    required this.granted,
    required this.noticeVersion,
    required this.languageCode,
    required this.channel,
    required this.grantedAt,
    this.withdrawnAt,
    required this.createdAt,
  });

  /// UUID v4.
  final String id;

  /// Owning clinic.
  final String clinicId;

  /// Patient (data principal).
  final String patientId;

  /// Purpose consented to.
  final DataPurpose purpose;

  /// Whether consent was granted (false = declined).
  final bool granted;

  /// Version of the privacy notice shown.
  final String noticeVersion;

  /// Language of the notice.
  final String languageCode;

  /// How consent was captured (`inClinic`, `whatsapp`, `web`).
  final String channel;

  /// When granted or declined.
  final DateTime grantedAt;

  /// When withdrawn, if later withdrawn.
  final DateTime? withdrawnAt;

  /// Row creation time.
  final DateTime createdAt;

  /// Whether this consent is currently in force.
  bool get isActive => granted && withdrawnAt == null;

  /// Returns a copy with the given fields replaced.
  DataConsent copyWith({DateTime? withdrawnAt}) => DataConsent(
    id: id,
    clinicId: clinicId,
    patientId: patientId,
    purpose: purpose,
    granted: granted,
    noticeVersion: noticeVersion,
    languageCode: languageCode,
    channel: channel,
    grantedAt: grantedAt,
    withdrawnAt: withdrawnAt ?? this.withdrawnAt,
    createdAt: createdAt,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'clinicId': clinicId,
    'patientId': patientId,
    'purpose': purpose.name,
    'granted': granted,
    'noticeVersion': noticeVersion,
    'languageCode': languageCode,
    'channel': channel,
    'grantedAt': dateToJson(grantedAt),
    'withdrawnAt': dateToJson(withdrawnAt),
    'createdAt': dateToJson(createdAt),
  };

  /// Parses the JSON form.
  factory DataConsent.fromJson(Map<String, Object?> json) => DataConsent(
    id: json['id'] as String,
    clinicId: json['clinicId'] as String,
    patientId: json['patientId'] as String,
    purpose: enumFromJson(DataPurpose.values, json['purpose']),
    granted: json['granted'] as bool,
    noticeVersion: json['noticeVersion'] as String,
    languageCode: json['languageCode'] as String,
    channel: json['channel'] as String,
    grantedAt: dateFromJson(json['grantedAt']),
    withdrawnAt: dateFromJsonOrNull(json['withdrawnAt']),
    createdAt: dateFromJson(json['createdAt']),
  );
}
