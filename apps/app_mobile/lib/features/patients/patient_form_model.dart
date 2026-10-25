import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_messaging/ampdent_messaging.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_terminology/ampdent_terminology.dart';
import 'package:flutter/foundation.dart';

/// Data-consent purposes the patient form offers as toggles.
const List<DataPurpose> patientFormConsentPurposes = [
  DataPurpose.appointmentReminders,
  DataPurpose.recallReminders,
  DataPurpose.marketing,
  DataPurpose.photoUse,
];

/// Short label for a consent toggle.
String dataPurposeLabel(DataPurpose purpose) => switch (purpose) {
  DataPurpose.appointmentReminders => 'Appointment reminders',
  DataPurpose.recallReminders => 'Recall reminders',
  DataPurpose.marketing => 'Offers and campaigns (marketing)',
  DataPurpose.photoUse => 'Use of clinical photos',
  DataPurpose.treatmentRecords => 'Treatment records',
  DataPurpose.billing => 'Billing',
  DataPurpose.thirdPartySharing => 'Sharing with labs and referrals',
  DataPurpose.research => 'Research',
};

/// Languages the app can message in (English shipped; others planned).
const List<(String, String)> patientLanguages = [
  ('en', 'English'),
  ('hi', 'Hindi'),
  ('te', 'Telugu'),
];

/// Patient-form copy (English; translation hook via `AppStrings` later).
abstract final class PatientStrings {
  /// Shown when neither a date of birth nor an approximate age is given.
  static const String ageRequired =
      'Enter the date of birth or an approximate age';
}

/// Guardian relations offered in the form.
const List<String> guardianRelations = [
  'Mother',
  'Father',
  'Guardian',
  'Spouse',
  'Sibling',
  'Other',
];

/// Whether the patient is under 18 given a DOB or an approximate age.
bool patientIsMinor({
  DateTime? dateOfBirth,
  num? approxAgeYears,
  required DateTime now,
}) {
  if (dateOfBirth != null) {
    return now.difference(dateOfBirth).inDays / 365.25 < 18;
  }
  return approxAgeYears != null && approxAgeYears < 18;
}

/// Pure validators for the patient form.
abstract final class PatientValidators {
  static final RegExp _abha = RegExp(r'^[0-9]{14}$');
  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// First name is the only mandatory name.
  static String? firstName(String? value) =>
      (value ?? '').trim().isEmpty ? 'First name is required' : null;

  /// Primary phone: an Indian mobile.
  static String? phone(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Phone is required';
    return PhoneNumbers.isValidIndianMobile(v)
        ? null
        : 'Enter a valid 10-digit Indian mobile number';
  }

  /// Optional Indian mobile.
  static String? optionalMobile(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    return PhoneNumbers.isValidIndianMobile(v)
        ? null
        : 'Enter a valid 10-digit Indian mobile number';
  }

  /// Optional email.
  static String? email(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    return _email.hasMatch(v) ? null : 'Enter a valid email';
  }

  /// Approximate age: 0-120; blank only when a date of birth is recorded
  /// ([required] is false), so a patient is never saved with an unknown age.
  static String? approxAge(String? value, {bool required = false}) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return required ? PatientStrings.ageRequired : null;
    final n = num.tryParse(v);
    if (n == null || n < 0 || n > 120) return 'Enter an age in years';
    return null;
  }

  /// Optional 14-digit ABHA number (digits only, spaces/dashes ignored).
  static String? abhaNumber(String? value) {
    final v = (value ?? '').replaceAll(RegExp(r'[\s-]'), '');
    if (v.isEmpty) return null;
    return _abha.hasMatch(v) ? null : 'ABHA number is 14 digits';
  }

  /// Guardian name: mandatory when [required] (patient under 18).
  static String? guardianName(String? value, {required bool required}) {
    if (!required) return null;
    return (value ?? '').trim().isEmpty
        ? MobileStrings.guardianRequiredForMinor
        : null;
  }

  /// Guardian phone: mandatory Indian mobile when [required].
  static String? guardianPhone(String? value, {required bool required}) {
    final v = (value ?? '').trim();
    if (v.isEmpty) {
      return required ? MobileStrings.guardianRequiredForMinor : null;
    }
    return PhoneNumbers.isValidIndianMobile(v)
        ? null
        : 'Enter a valid 10-digit Indian mobile number';
  }
}

/// Values collected by the patient form, independent of widgets.
@immutable
class PatientFormData {
  /// Creates form data.
  const PatientFormData({
    this.firstName = '',
    this.lastName = '',
    this.phone = '',
    this.altPhone = '',
    this.email = '',
    this.dateOfBirth,
    this.approxAgeYears,
    this.sex = Sex.unspecified,
    this.addressLines = const [],
    this.city = '',
    this.pincode = '',
    this.abhaNumber = '',
    this.preferredLanguage = 'en',
    this.guardianName = '',
    this.guardianRelation = '',
    this.guardianPhone = '',
    this.notes = '',
    this.consents = const {},
  });

  /// Builds form data from an existing patient and their latest consents.
  factory PatientFormData.fromPatient(
    Patient patient,
    Map<DataPurpose, DataConsent> latestConsents,
  ) => PatientFormData(
    firstName: patient.firstName,
    lastName: patient.lastName ?? '',
    phone: patient.phone,
    altPhone: patient.altPhone ?? '',
    email: patient.email ?? '',
    dateOfBirth: patient.dateOfBirth,
    approxAgeYears: patient.approxAgeYears,
    sex: patient.sex,
    addressLines: patient.addressLines,
    city: patient.city ?? '',
    pincode: patient.pincode ?? '',
    abhaNumber: patient.abhaNumber ?? '',
    preferredLanguage: patient.preferredLanguage,
    guardianName: patient.guardianName ?? '',
    guardianRelation: patient.guardianRelation ?? '',
    guardianPhone: patient.guardianPhone ?? '',
    notes: patient.notes ?? '',
    consents: {
      for (final p in patientFormConsentPurposes)
        p: latestConsents[p]?.isActive ?? false,
    },
  );

  /// Given name.
  final String firstName;

  /// Family name.
  final String lastName;

  /// Primary mobile as typed.
  final String phone;

  /// Alternate phone.
  final String altPhone;

  /// Email.
  final String email;

  /// Date of birth when known.
  final DateTime? dateOfBirth;

  /// Approximate age when DOB is unknown.
  final num? approxAgeYears;

  /// Sex.
  final Sex sex;

  /// Address lines.
  final List<String> addressLines;

  /// City.
  final String city;

  /// PIN code.
  final String pincode;

  /// ABHA number.
  final String abhaNumber;

  /// Message language code.
  final String preferredLanguage;

  /// Guardian name.
  final String guardianName;

  /// Guardian relation.
  final String guardianRelation;

  /// Guardian phone.
  final String guardianPhone;

  /// Front-desk notes.
  final String notes;

  /// Consent toggles by purpose.
  final Map<DataPurpose, bool> consents;

  /// Whether the guardian section is mandatory.
  bool isMinor(DateTime now) => patientIsMinor(
    dateOfBirth: dateOfBirth,
    approxAgeYears: approxAgeYears,
    now: now,
  );

  static String? _nullIfBlank(String value) =>
      value.trim().isEmpty ? null : value.trim();

  /// Converts to a [Patient]. For a new patient pass an empty
  /// [patientNumber]; the repository mints one.
  Patient toPatient({
    required String id,
    required String clinicId,
    required String patientNumber,
    required DateTime now,
    DateTime? createdAt,
  }) {
    final gp = _nullIfBlank(guardianPhone);
    return Patient(
      id: id,
      clinicId: clinicId,
      patientNumber: patientNumber,
      firstName: firstName.trim(),
      lastName: _nullIfBlank(lastName),
      phone: PhoneNumbers.tryNormaliseIndian(phone) ?? phone.trim(),
      altPhone: _nullIfBlank(altPhone) == null
          ? null
          : PhoneNumbers.tryNormaliseIndian(altPhone) ?? altPhone.trim(),
      email: _nullIfBlank(email),
      dateOfBirth: dateOfBirth,
      approxAgeYears: dateOfBirth == null ? approxAgeYears : null,
      ageRecordedAt: dateOfBirth == null && approxAgeYears != null ? now : null,
      sex: sex,
      addressLines: addressLines
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList(),
      city: _nullIfBlank(city),
      pincode: _nullIfBlank(pincode),
      abhaNumber: _nullIfBlank(abhaNumber.replaceAll(RegExp(r'[\s-]'), '')),
      guardianName: _nullIfBlank(guardianName),
      guardianRelation: _nullIfBlank(guardianRelation),
      guardianPhone: gp == null
          ? null
          : PhoneNumbers.tryNormaliseIndian(gp) ?? gp,
      preferredLanguage: preferredLanguage,
      notes: _nullIfBlank(notes),
      createdAt: createdAt ?? now,
      updatedAt: now,
    );
  }
}

/// Persists a [PatientFormData]: upserts the patient and writes a
/// [DataConsent] row for every toggle whose value changed.
class PatientSaver {
  /// Creates a saver.
  const PatientSaver({
    required this.patients,
    required this.consents,
    required this.clinics,
    required this.ctx,
  });

  /// Patient repository.
  final PatientRepository patients;

  /// Clinic repository, used to mint the patient number for a new patient.
  final ClinicRepository clinics;

  /// Consent repository.
  final ConsentRepository consents;

  /// Actor for the writes.
  final ActorContext ctx;

  /// Saves and returns the stored patient. Throws [StateError] when the age
  /// is unknown (no date of birth or approximate age) or a minor has no
  /// guardian.
  Future<Patient> save(
    PatientFormData data, {
    Patient? existing,
    DateTime? now,
  }) async {
    final at = (now ?? DateTime.now()).toUtc();
    var patient = data.toPatient(
      id: existing?.id ?? newId(),
      clinicId: ctx.clinicId,
      patientNumber: existing?.patientNumber ?? '',
      now: at,
      createdAt: existing?.createdAt,
    );
    if (!patient.hasKnownAge) throw StateError(PatientStrings.ageRequired);
    if (patient.requiresGuardian(at)) {
      throw StateError(MobileStrings.guardianRequiredForMinor);
    }
    if (patient.patientNumber.isEmpty) {
      patient = patient.copyWith(
        patientNumber: await clinics.nextPatientNumber(ctx),
      );
    }
    final saved = await patients.upsert(ctx, patient);
    final latest = existing == null
        ? const <DataPurpose, DataConsent>{}
        : await consents.latestDataConsents(saved.id);
    for (final entry in data.consents.entries) {
      final current = latest[entry.key]?.isActive ?? false;
      if (existing != null && current == entry.value) continue;
      if (existing == null && !entry.value) continue;
      await consents.recordDataConsent(
        ctx,
        DataConsent(
          id: newId(),
          clinicId: ctx.clinicId,
          patientId: saved.id,
          purpose: entry.key,
          granted: entry.value,
          noticeVersion: dpdpDataProcessingNotice.version,
          languageCode: data.preferredLanguage,
          channel: 'inClinic',
          grantedAt: at,
          createdAt: at,
        ),
      );
    }
    return saved;
  }
}
