/// Drug master, prescriptions, messaging and compliance tables. Columns
/// mirror the row class fields (see `ampdent_core`).
library;

// ignore_for_file: deprecated_member_use

import 'package:ampdent_core/ampdent_core.dart';
import 'package:drift/drift.dart';

import 'converters.dart';
import 'tables_clinic.dart';
import 'tables_patient.dart';

/// Drug master (global, seeded from `ampdent_terminology`).
@TableIndex(name: 'drugs_generic_name', columns: {#genericName})
@UseRowClass(Drug, generateInsertable: true)
class Drugs extends IdTable {
  TextColumn get genericName => text()();
  TextColumn get brandNames => text().map(const StringListConverter())();
  TextColumn get strength => text()();
  TextColumn get form => textEnum<DrugForm>()();
  TextColumn get schedule => textEnum<DrugSchedule>()();
  TextColumn get scheduleEffectiveFrom =>
      text().map(const IsoUtcDateTimeConverter()).nullable()();
  TextColumn get category => text()();
  TextColumn get defaultDose => text()();
  TextColumn get defaultFrequency => text()();
  IntColumn get defaultDurationDays => integer()();
  TextColumn get route => text()();
  TextColumn get allergyGroup => text().nullable()();
  BoolColumn get pregnancyCaution => boolean()();
  BoolColumn get pediatricCaution => boolean()();
  BoolColumn get isActive => boolean()();
}

/// Prescriptions; lines are a JSON column.
@TableIndex(name: 'prescriptions_clinic', columns: {#clinicId})
@TableIndex(name: 'prescriptions_patient', columns: {#patientId, #issuedAt})
@TableIndex(name: 'prescriptions_verification', columns: {#verificationCode})
@UseRowClass(Prescription, generateInsertable: true)
class Prescriptions extends PatientScopedTable {
  TextColumn get visitId => text().nullable()();
  TextColumn get prescriberId => text()();
  TextColumn get prescriberName => text()();
  TextColumn get prescriberRegistrationNumber => text()();
  TextColumn get prescriberQualifications =>
      text().map(const StringListConverter())();
  TextColumn get issuedAt => text().map(const IsoUtcDateTimeConverter())();
  TextColumn get diagnosis => text().nullable()();
  TextColumn get lines => text().map(const PrescriptionLinesConverter())();
  BoolColumn get isRepeatable => boolean()();
  BoolColumn get dispensedByClinic => boolean()();
  TextColumn get verificationCode => text()();
  TextColumn get documentHash => text().nullable()();
  TextColumn get pdfPath => text().nullable()();
  TextColumn get createdAt => text().map(const IsoUtcDateTimeConverter())();
}

/// Outbound message log / outbox.
@TableIndex(name: 'message_logs_clinic', columns: {#clinicId})
@TableIndex(name: 'message_logs_clinic_status', columns: {#clinicId, #status})
@TableIndex(name: 'message_logs_patient', columns: {#patientId})
@UseRowClass(MessageLog, generateInsertable: true)
class MessageLogs extends TenantTable {
  TextColumn get patientId => text().nullable().references(Patients, #id)();
  TextColumn get channel => textEnum<MessageChannel>()();
  TextColumn get category => textEnum<MessageCategory>()();
  TextColumn get templateCode => text()();
  TextColumn get toPhone => text()();
  TextColumn get variables => text().map(const StringMapConverter())();
  TextColumn get renderedPreview => text()();
  TextColumn get status => textEnum<MessageStatus>()();
  TextColumn get providerMessageId => text().nullable()();
  TextColumn get error => text().nullable()();
  IntColumn get costPaise => integer().nullable()();
  TextColumn get createdAt => text().map(const IsoUtcDateTimeConverter())();
  TextColumn get sentAt =>
      text().map(const IsoUtcDateTimeConverter()).nullable()();
  TextColumn get deliveredAt =>
      text().map(const IsoUtcDateTimeConverter()).nullable()();
}

/// Sterilisation register.
@TableIndex(name: 'sterilisation_cycles_clinic', columns: {#clinicId})
@TableIndex(
  name: 'sterilisation_cycles_clinic_cycled',
  columns: {#clinicId, #cycledAt},
)
@UseRowClass(SterilisationCycle, generateInsertable: true)
class SterilisationCycles extends TenantTable {
  TextColumn get cycleNumber => text()();
  TextColumn get autoclaveName => text()();
  TextColumn get cycledAt => text().map(const IsoUtcDateTimeConverter())();
  TextColumn get cycleType => textEnum<SterilisationCycleType>()();
  RealColumn get temperatureC => real().map(const NumConverter()).nullable()();
  RealColumn get pressureKpa => real().map(const NumConverter()).nullable()();
  IntColumn get durationMinutes => integer().nullable()();
  BoolColumn get chemicalIndicatorPassed => boolean()();
  TextColumn get biologicalIndicatorResult =>
      textEnum<BiologicalIndicatorResult>().nullable()();
  TextColumn get loadContents => text().nullable()();
  TextColumn get operatorId => text()();
  TextColumn get note => text().nullable()();
  TextColumn get createdAt => text().map(const IsoUtcDateTimeConverter())();
}

/// Licences and registrations.
@TableIndex(name: 'licences_clinic', columns: {#clinicId})
@TableIndex(name: 'licences_clinic_expires', columns: {#clinicId, #expiresAt})
@UseRowClass(Licence, generateInsertable: true)
class Licences extends TenantTable {
  TextColumn get kind => textEnum<LicenceKind>()();
  TextColumn get identifier => text()();
  TextColumn get authority => text().nullable()();
  TextColumn get issuedAt =>
      text().map(const IsoUtcDateTimeConverter()).nullable()();
  TextColumn get expiresAt =>
      text().map(const IsoUtcDateTimeConverter()).nullable()();
  TextColumn get qaDueAt =>
      text().map(const IsoUtcDateTimeConverter()).nullable()();
  TextColumn get documentPath => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get createdAt => text().map(const IsoUtcDateTimeConverter())();
  TextColumn get updatedAt => text().map(const IsoUtcDateTimeConverter())();
}
