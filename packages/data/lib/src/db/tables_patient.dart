/// Patient, scheduling, history, notes, imaging and consent tables. Columns
/// mirror the fields of the row class named in each `@UseRowClass`; see the
/// entity in `ampdent_core` for field documentation.
library;

// ignore_for_file: deprecated_member_use

import 'package:ampdent_core/ampdent_core.dart';
import 'package:drift/drift.dart';

import 'converters.dart';
import 'tables_clinic.dart';

/// Base for patient-scoped tables: `patient_id` references the patient.
abstract class PatientScopedTable extends TenantTable {
  /// Patient the row belongs to.
  TextColumn get patientId => text().references(Patients, #id)();
}

/// Patients.
@TableIndex(name: 'patients_clinic', columns: {#clinicId})
@TableIndex(name: 'patients_clinic_phone', columns: {#clinicId, #phone})
@TableIndex(
  name: 'patients_clinic_number',
  columns: {#clinicId, #patientNumber},
  unique: true,
)
@UseRowClass(Patient, generateInsertable: true)
class Patients extends TenantTable {
  TextColumn get patientNumber => text()();
  TextColumn get firstName => text()();
  TextColumn get lastName => text().nullable()();
  TextColumn get phone => text()();
  TextColumn get altPhone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get dateOfBirth =>
      text().map(const IsoUtcDateTimeConverter()).nullable()();
  RealColumn get approxAgeYears =>
      real().map(const NumConverter()).nullable()();
  TextColumn get ageRecordedAt =>
      text().map(const IsoUtcDateTimeConverter()).nullable()();
  TextColumn get sex => textEnum<Sex>()();
  TextColumn get addressLines => text().map(const StringListConverter())();
  TextColumn get city => text().nullable()();
  TextColumn get pincode => text().nullable()();
  TextColumn get abhaNumber => text().nullable()();
  TextColumn get abhaAddress => text().nullable()();
  TextColumn get guardianName => text().nullable()();
  TextColumn get guardianRelation => text().nullable()();
  TextColumn get guardianPhone => text().nullable()();
  TextColumn get preferredLanguage => text()();
  TextColumn get tags => text().map(const StringListConverter())();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean()();
  TextColumn get createdAt => text().map(const IsoUtcDateTimeConverter())();
  TextColumn get updatedAt => text().map(const IsoUtcDateTimeConverter())();
}

/// Appointment book.
@TableIndex(name: 'appointments_clinic', columns: {#clinicId})
@TableIndex(name: 'appointments_clinic_starts', columns: {#clinicId, #startsAt})
@TableIndex(name: 'appointments_patient', columns: {#patientId})
@UseRowClass(Appointment, generateInsertable: true)
class Appointments extends PatientScopedTable {
  TextColumn get providerId => text()();
  TextColumn get chairId => text().nullable()();
  TextColumn get startsAt => text().map(const IsoUtcDateTimeConverter())();
  TextColumn get endsAt => text().map(const IsoUtcDateTimeConverter())();
  TextColumn get status => textEnum<AppointmentStatus>()();
  TextColumn get reason => text()();
  TextColumn get plannedProcedureIds =>
      text().map(const StringListConverter())();
  TextColumn get source => textEnum<AppointmentSource>()();
  TextColumn get notes => text().nullable()();
  TextColumn get confirmedAt =>
      text().map(const IsoUtcDateTimeConverter()).nullable()();
  TextColumn get reminder24hSentAt =>
      text().map(const IsoUtcDateTimeConverter()).nullable()();
  TextColumn get reminderMorningSentAt =>
      text().map(const IsoUtcDateTimeConverter()).nullable()();
  TextColumn get arrivedAt =>
      text().map(const IsoUtcDateTimeConverter()).nullable()();
  TextColumn get cancelledReason => text().nullable()();
  TextColumn get createdAt => text().map(const IsoUtcDateTimeConverter())();
  TextColumn get updatedAt => text().map(const IsoUtcDateTimeConverter())();
}

/// Clinical encounters.
@TableIndex(name: 'visits_clinic', columns: {#clinicId})
@TableIndex(name: 'visits_patient', columns: {#patientId})
@UseRowClass(Visit, generateInsertable: true)
class Visits extends PatientScopedTable {
  TextColumn get providerId => text()();
  TextColumn get appointmentId => text().nullable()();
  TextColumn get startedAt => text().map(const IsoUtcDateTimeConverter())();
  TextColumn get endedAt =>
      text().map(const IsoUtcDateTimeConverter()).nullable()();
  TextColumn get chiefComplaint => text().nullable()();
  TextColumn get createdAt => text().map(const IsoUtcDateTimeConverter())();
  TextColumn get updatedAt => text().map(const IsoUtcDateTimeConverter())();
}

/// Medical history snapshots (append-only).
@TableIndex(name: 'medical_histories_clinic', columns: {#clinicId})
@TableIndex(
  name: 'medical_histories_patient',
  columns: {#patientId, #recordedAt},
)
@UseRowClass(MedicalHistory, generateInsertable: true)
class MedicalHistories extends PatientScopedTable {
  TextColumn get recordedAt => text().map(const IsoUtcDateTimeConverter())();
  TextColumn get recordedBy => text()();
  TextColumn get allergies => text().map(const AllergiesConverter())();
  TextColumn get medications => text().map(const StringListConverter())();
  BoolColumn get diabetes => boolean()();
  RealColumn get hba1c => real().map(const NumConverter()).nullable()();
  BoolColumn get hypertension => boolean()();
  TextColumn get cardiacCondition => text().nullable()();
  BoolColumn get bleedingDisorder => boolean()();
  TextColumn get anticoagulant => text().nullable()();
  TextColumn get antiresorptive => text().nullable()();
  TextColumn get antiresorptiveRoute =>
      textEnum<AntiresorptiveRoute>().nullable()();
  RealColumn get antiresorptiveYears =>
      real().map(const NumConverter()).nullable()();
  BoolColumn get oncologyTreatment => boolean()();
  BoolColumn get pregnant => boolean()();
  IntColumn get pregnancyTrimester => integer().nullable()();
  BoolColumn get asthma => boolean()();
  BoolColumn get epilepsy => boolean()();
  BoolColumn get thyroid => boolean()();
  BoolColumn get steroids => boolean()();
  BoolColumn get hepatitis => boolean()();
  BoolColumn get hiv => boolean()();
  TextColumn get smoking => textEnum<SmokingStatus>()();
  BoolColumn get alcohol => boolean()();
  TextColumn get otherNotes => text().nullable()();
  TextColumn get createdAt => text().map(const IsoUtcDateTimeConverter())();
}

/// Versioned case-sheet notes.
@TableIndex(name: 'clinical_notes_clinic', columns: {#clinicId})
@TableIndex(name: 'clinical_notes_patient', columns: {#patientId})
@TableIndex(name: 'clinical_notes_visit', columns: {#visitId})
@UseRowClass(ClinicalNote, generateInsertable: true)
class ClinicalNotes extends PatientScopedTable {
  TextColumn get visitId => text()();
  TextColumn get authorId => text()();
  TextColumn get chiefComplaint => text().nullable()();
  TextColumn get historyOfPresentIllness => text().nullable()();
  TextColumn get pastDentalHistory => text().nullable()();
  TextColumn get pastMedicalHistory => text().nullable()();
  TextColumn get personalHistory => text().nullable()();
  TextColumn get extraoralExam => text().nullable()();
  TextColumn get intraoralExam => text().nullable()();
  TextColumn get provisionalDiagnosis => text().nullable()();
  TextColumn get investigations => text().nullable()();
  TextColumn get finalDiagnosis => text().nullable()();
  TextColumn get treatmentDone => text().nullable()();
  TextColumn get advice => text().nullable()();
  TextColumn get followUp => text().nullable()();
  TextColumn get freeText => text().nullable()();
  IntColumn get version => integer()();
  TextColumn get supersedesNoteId => text().nullable()();
  TextColumn get signedAt =>
      text().map(const IsoUtcDateTimeConverter()).nullable()();
  TextColumn get createdAt => text().map(const IsoUtcDateTimeConverter())();
  TextColumn get updatedAt => text().map(const IsoUtcDateTimeConverter())();
}

/// Images, radiographs and scanned documents.
@TableIndex(name: 'image_records_clinic', columns: {#clinicId})
@TableIndex(name: 'image_records_patient', columns: {#patientId, #capturedAt})
@UseRowClass(ImageRecord, generateInsertable: true)
class ImageRecords extends PatientScopedTable {
  TextColumn get visitId => text().nullable()();
  TextColumn get kind => textEnum<ImageKind>()();
  TextColumn get filePath => text()();
  TextColumn get thumbnailPath => text().nullable()();
  TextColumn get capturedAt => text().map(const IsoUtcDateTimeConverter())();
  TextColumn get teeth => text().map(const ToothListConverter())();
  TextColumn get fmxSlot => text().nullable()();
  BoolColumn get isPreOperative => boolean()();
  TextColumn get procedureId => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get sha256 => text().nullable()();
  TextColumn get sharingConsentId => text().nullable()();
  TextColumn get createdAt => text().map(const IsoUtcDateTimeConverter())();
}

/// Procedure consents (immutable once signed).
@TableIndex(name: 'consent_records_clinic', columns: {#clinicId})
@TableIndex(name: 'consent_records_patient', columns: {#patientId, #signedAt})
@UseRowClass(ConsentRecord, generateInsertable: true)
class ConsentRecords extends PatientScopedTable {
  TextColumn get templateCode => text()();
  TextColumn get templateVersionHash => text()();
  TextColumn get languageCode => text()();
  TextColumn get procedureIds => text().map(const StringListConverter())();
  TextColumn get planId => text().nullable()();
  TextColumn get teeth => text().map(const ToothListConverter())();
  TextColumn get renderedText => text()();
  TextColumn get signerName => text()();
  TextColumn get signerRelation => textEnum<SignerRelation>()();
  TextColumn get signerPhone => text().nullable()();
  TextColumn get signatureImagePath => text().nullable()();
  BoolColumn get otpVerified => boolean()();
  TextColumn get signedAt => text().map(const IsoUtcDateTimeConverter())();
  TextColumn get dentistId => text()();
  TextColumn get dentistRegistrationNumber => text()();
  TextColumn get discussionNote => text().nullable()();
  TextColumn get witnessName => text().nullable()();
  TextColumn get deviceId => text()();
  TextColumn get documentHash => text()();
  TextColumn get pdfPath => text().nullable()();
  TextColumn get createdAt => text().map(const IsoUtcDateTimeConverter())();
}

/// DPDP purpose-scoped data consents (one row per grant/withdrawal).
@TableIndex(name: 'data_consents_clinic', columns: {#clinicId})
@TableIndex(name: 'data_consents_patient', columns: {#patientId, #purpose})
@UseRowClass(DataConsent, generateInsertable: true)
class DataConsents extends PatientScopedTable {
  TextColumn get purpose => textEnum<DataPurpose>()();
  BoolColumn get granted => boolean()();
  TextColumn get noticeVersion => text()();
  TextColumn get languageCode => text()();
  TextColumn get channel => text()();
  TextColumn get grantedAt => text().map(const IsoUtcDateTimeConverter())();
  TextColumn get withdrawnAt =>
      text().map(const IsoUtcDateTimeConverter()).nullable()();
  TextColumn get createdAt => text().map(const IsoUtcDateTimeConverter())();
}
