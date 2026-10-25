/// Billing, ledger, recall and lab tables. Columns mirror the row class
/// fields (see `ampdent_core`).
library;

// ignore_for_file: deprecated_member_use

import 'package:ampdent_core/ampdent_core.dart';
import 'package:drift/drift.dart';

import 'converters.dart';
import 'tables_clinic.dart';
import 'tables_patient.dart';

/// Invoices / receipts; lines are a JSON column.
@TableIndex(name: 'invoices_clinic', columns: {#clinicId})
@TableIndex(name: 'invoices_clinic_patient', columns: {#clinicId, #patientId})
@TableIndex(name: 'invoices_clinic_status', columns: {#clinicId, #status})
@UseRowClass(Invoice, generateInsertable: true)
class Invoices extends PatientScopedTable {
  TextColumn get number => text()();
  TextColumn get documentType => textEnum<InvoiceDocumentType>()();
  TextColumn get status => textEnum<InvoiceStatus>()();
  TextColumn get issuedAt => text().map(const IsoUtcDateTimeConverter())();
  TextColumn get lines => text().map(const InvoiceLinesConverter())();
  IntColumn get subtotal => integer().map(const MoneyConverter())();
  IntColumn get discountTotal => integer().map(const MoneyConverter())();
  IntColumn get taxableTotal => integer().map(const MoneyConverter())();
  IntColumn get taxTotal => integer().map(const MoneyConverter())();
  IntColumn get grandTotal => integer().map(const MoneyConverter())();
  IntColumn get amountPaid => integer().map(const MoneyConverter())();
  TextColumn get notes => text().nullable()();
  TextColumn get issuedBy => text()();
  TextColumn get dentistId => text().nullable()();
  TextColumn get dentistName => text().nullable()();
  TextColumn get dentistQualifications => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();
  TextColumn get dentistRegistrationNumber => text().nullable()();
  TextColumn get dentistRegistrationCouncil => text().nullable()();
  TextColumn get voidReason => text().nullable()();
  TextColumn get createdAt => text().map(const IsoUtcDateTimeConverter())();
  TextColumn get updatedAt => text().map(const IsoUtcDateTimeConverter())();
}

/// Payments (append-only events).
@TableIndex(name: 'payments_clinic', columns: {#clinicId})
@TableIndex(name: 'payments_patient', columns: {#patientId, #receivedAt})
@TableIndex(name: 'payments_invoice', columns: {#invoiceId})
@UseRowClass(Payment, generateInsertable: true)
class Payments extends PatientScopedTable {
  TextColumn get invoiceId => text().nullable()();
  IntColumn get amount => integer().map(const MoneyConverter())();
  TextColumn get method => textEnum<PaymentMethod>()();
  TextColumn get reference => text().nullable()();
  TextColumn get gatewayToken => text().nullable()();
  TextColumn get cardLast4 => text().nullable()();
  TextColumn get cardBrand => text().nullable()();
  TextColumn get receivedAt => text().map(const IsoUtcDateTimeConverter())();
  TextColumn get receivedBy => text()();
  BoolColumn get isRefund => boolean()();
  TextColumn get note => text().nullable()();
  TextColumn get createdAt => text().map(const IsoUtcDateTimeConverter())();
}

/// Approved account adjustments.
@TableIndex(name: 'adjustments_clinic', columns: {#clinicId})
@TableIndex(name: 'adjustments_patient', columns: {#patientId})
@UseRowClass(Adjustment, generateInsertable: true)
class Adjustments extends PatientScopedTable {
  TextColumn get invoiceId => text().nullable()();
  TextColumn get type => textEnum<AdjustmentType>()();
  IntColumn get amount => integer().map(const MoneyConverter())();
  TextColumn get reason => text()();
  TextColumn get approvedBy => text()();
  TextColumn get createdAt => text().map(const IsoUtcDateTimeConverter())();
}

/// Patient ledger postings (append-only).
@TableIndex(name: 'ledger_entries_clinic', columns: {#clinicId})
@TableIndex(name: 'ledger_entries_patient', columns: {#patientId, #occurredAt})
@TableIndex(name: 'ledger_entries_reference', columns: {#referenceId})
@UseRowClass(LedgerEntry, generateInsertable: true)
class LedgerEntries extends PatientScopedTable {
  TextColumn get entryType => textEnum<LedgerEntryType>()();
  IntColumn get amount => integer().map(const MoneyConverter())();
  TextColumn get referenceId => text()();
  TextColumn get occurredAt => text().map(const IsoUtcDateTimeConverter())();
  TextColumn get description => text()();
}

/// Recalls.
@TableIndex(name: 'recalls_clinic', columns: {#clinicId})
@TableIndex(
  name: 'recalls_clinic_due_status',
  columns: {#clinicId, #dueAt, #status},
)
@TableIndex(name: 'recalls_patient', columns: {#patientId})
@UseRowClass(Recall, generateInsertable: true)
class Recalls extends PatientScopedTable {
  TextColumn get type => textEnum<RecallType>()();
  TextColumn get triggeredByProcedureId => text().nullable()();
  TextColumn get dueAt => text().map(const IsoUtcDateTimeConverter())();
  TextColumn get interval => textEnum<RecallInterval>().nullable()();
  TextColumn get status => textEnum<RecallStatus>()();
  TextColumn get lastNotifiedAt =>
      text().map(const IsoUtcDateTimeConverter()).nullable()();
  IntColumn get notifyCount => integer()();
  TextColumn get appointmentId => text().nullable()();
  IntColumn get estimatedValue => integer().map(const MoneyConverter())();
  TextColumn get note => text().nullable()();
  TextColumn get createdAt => text().map(const IsoUtcDateTimeConverter())();
  TextColumn get updatedAt => text().map(const IsoUtcDateTimeConverter())();
}

/// Dental laboratories.
@TableIndex(name: 'labs_clinic', columns: {#clinicId})
@UseRowClass(Lab, generateInsertable: true)
class Labs extends TenantTable {
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get whatsappPhone => text().nullable()();
  TextColumn get turnaroundDays => text().map(const IntMapConverter())();
  BoolColumn get isActive => boolean()();
}

/// Lab cases.
@TableIndex(name: 'lab_cases_clinic', columns: {#clinicId})
@TableIndex(name: 'lab_cases_clinic_status', columns: {#clinicId, #status})
@TableIndex(name: 'lab_cases_patient', columns: {#patientId})
@UseRowClass(LabCase, generateInsertable: true)
class LabCases extends PatientScopedTable {
  TextColumn get procedureId => text().nullable()();
  TextColumn get labId => text()();
  TextColumn get caseType => textEnum<LabCaseType>()();
  TextColumn get teeth => text().map(const ToothListConverter())();
  TextColumn get material => text().nullable()();
  TextColumn get shade => text().nullable()();
  TextColumn get impressionType => text().nullable()();
  TextColumn get instructions => text().nullable()();
  IntColumn get labFee => integer().map(const MoneyConverter())();
  TextColumn get status => textEnum<LabCaseStatus>()();
  TextColumn get createdAt => text().map(const IsoUtcDateTimeConverter())();
  TextColumn get sentAt =>
      text().map(const IsoUtcDateTimeConverter()).nullable()();
  TextColumn get dueAt =>
      text().map(const IsoUtcDateTimeConverter()).nullable()();
  TextColumn get receivedAt =>
      text().map(const IsoUtcDateTimeConverter()).nullable()();
  TextColumn get qualityCheckedAt =>
      text().map(const IsoUtcDateTimeConverter()).nullable()();
  TextColumn get fittedAt =>
      text().map(const IsoUtcDateTimeConverter()).nullable()();
  TextColumn get remakeReason => text().nullable()();
  TextColumn get remakeOfCaseId => text().nullable()();
  TextColumn get slipPdfPath => text().nullable()();
  TextColumn get updatedAt => text().map(const IsoUtcDateTimeConverter())();
}
