/// Odontogram, findings, catalogue, procedures, plans, estimates, perio and
/// implant tables. Columns mirror the row class fields (see `ampdent_core`).
library;

// ignore_for_file: deprecated_member_use

import 'package:ampdent_core/ampdent_core.dart';
import 'package:drift/drift.dart';

import 'converters.dart';
import 'tables_clinic.dart';
import 'tables_patient.dart';

/// Tooth-state history (append-only).
@TableIndex(name: 'tooth_state_records_clinic', columns: {#clinicId})
@TableIndex(
  name: 'tooth_state_records_patient_tooth',
  columns: {#patientId, #tooth, #effectiveFrom},
)
@UseRowClass(ToothStateRecord, generateInsertable: true)
class ToothStateRecords extends PatientScopedTable {
  TextColumn get tooth => text().map(const ToothIdConverter())();
  TextColumn get state => textEnum<ToothState>()();
  TextColumn get effectiveFrom => text().map(const IsoUtcDateTimeConverter())();
  TextColumn get source => textEnum<ToothStateSource>()();
  TextColumn get procedureId => text().nullable()();
  TextColumn get recordedBy => text()();
  TextColumn get note => text().nullable()();
  TextColumn get createdAt => text().map(const IsoUtcDateTimeConverter())();
}

/// Clinical findings.
@TableIndex(name: 'findings_clinic', columns: {#clinicId})
@TableIndex(name: 'findings_patient_status', columns: {#patientId, #status})
@UseRowClass(Finding, generateInsertable: true)
class Findings extends PatientScopedTable {
  TextColumn get visitId => text().nullable()();
  TextColumn get tooth => text().map(const ToothIdConverter()).nullable()();
  TextColumn get surfaces => text().map(const SurfaceSetConverter())();
  TextColumn get snomedCode => text().nullable()();
  TextColumn get icd10Code => text().nullable()();
  TextColumn get description => text()();
  TextColumn get icdas => textEnum<IcdasCode>().nullable()();
  TextColumn get status => textEnum<FindingStatus>()();
  TextColumn get recordedAt => text().map(const IsoUtcDateTimeConverter())();
  TextColumn get recordedBy => text()();
  TextColumn get resolvedAt =>
      text().map(const IsoUtcDateTimeConverter()).nullable()();
  TextColumn get resolvedByProcedureId => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get createdAt => text().map(const IsoUtcDateTimeConverter())();
  TextColumn get updatedAt => text().map(const IsoUtcDateTimeConverter())();
}

/// Procedure catalogue: global seed rows (`clinic_id` NULL) plus per-clinic
/// overrides keyed by the same `code`.
@TableIndex(name: 'catalog_items_clinic', columns: {#clinicId})
@TableIndex(name: 'catalog_items_clinic_code', columns: {#clinicId, #code})
@UseRowClass(CatalogItem, generateInsertable: true)
class CatalogItems extends IdTable {
  TextColumn get clinicId => text().nullable().references(Clinics, #id)();
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get laymanName => text()();
  TextColumn get category => textEnum<ProcedureCategory>()();
  TextColumn get treatmentArea => textEnum<TreatmentArea>()();
  IntColumn get defaultFee => integer().map(const MoneyConverter())();
  IntColumn get feeMin => integer().map(const MoneyConverter())();
  IntColumn get feeMax => integer().map(const MoneyConverter())();
  TextColumn get gstClass => textEnum<GstClass>()();
  TextColumn get sacHsnCode => text()();
  IntColumn get durationMinutes => integer()();
  TextColumn get stages => text().map(const StringListConverter())();
  TextColumn get recallInterval => textEnum<RecallInterval>().nullable()();
  TextColumn get consentTemplateCode => text().nullable()();
  BoolColumn get requiresPreOpRadiograph => boolean()();
  TextColumn get externalCodes => text().map(const StringMapConverter())();
  BoolColumn get isActive => boolean()();
  IntColumn get sortOrder => integer()();
}

/// Procedures planned or performed (append-only, status-driven).
@TableIndex(name: 'procedures_clinic', columns: {#clinicId})
@TableIndex(
  name: 'procedures_clinic_patient_status',
  columns: {#clinicId, #patientId, #status},
)
@UseRowClass(ProcedureRecord, generateInsertable: true)
class Procedures extends PatientScopedTable {
  TextColumn get visitId => text().nullable()();
  TextColumn get planId => text().nullable()();
  TextColumn get planLineId => text().nullable()();
  TextColumn get catalogItemId => text()();
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get tooth => text().map(const ToothIdConverter()).nullable()();
  TextColumn get teeth => text().map(const ToothListConverter())();
  TextColumn get surfaces => text().map(const SurfaceSetConverter())();
  TextColumn get treatmentArea => textEnum<TreatmentArea>()();
  TextColumn get status => textEnum<ProcedureStatus>()();
  TextColumn get providerId => text()();
  IntColumn get fee => integer().map(const MoneyConverter())();
  IntColumn get discount => integer().map(const MoneyConverter())();
  IntColumn get stageIndex => integer()();
  IntColumn get totalStages => integer()();
  TextColumn get stageNames => text().map(const StringListConverter())();
  TextColumn get plannedAt =>
      text().map(const IsoUtcDateTimeConverter()).nullable()();
  TextColumn get acceptedAt =>
      text().map(const IsoUtcDateTimeConverter()).nullable()();
  TextColumn get startedAt =>
      text().map(const IsoUtcDateTimeConverter()).nullable()();
  TextColumn get completedAt =>
      text().map(const IsoUtcDateTimeConverter()).nullable()();
  TextColumn get labCaseId => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get preOpImageIds => text().map(const StringListConverter())();
  TextColumn get createdAt => text().map(const IsoUtcDateTimeConverter())();
  TextColumn get updatedAt => text().map(const IsoUtcDateTimeConverter())();
}

/// Treatment plans.
@TableIndex(name: 'treatment_plans_clinic', columns: {#clinicId})
@TableIndex(name: 'treatment_plans_patient', columns: {#patientId, #status})
@UseRowClass(TreatmentPlan, generateInsertable: true)
class TreatmentPlans extends PatientScopedTable {
  TextColumn get title => text()();
  TextColumn get status => textEnum<TreatmentPlanStatus>()();
  TextColumn get phases => text().map(const PlanPhasesConverter())();
  IntColumn get version => integer()();
  TextColumn get supersedesPlanId => text().nullable()();
  TextColumn get presentedAt =>
      text().map(const IsoUtcDateTimeConverter()).nullable()();
  TextColumn get acceptedAt =>
      text().map(const IsoUtcDateTimeConverter()).nullable()();
  TextColumn get acceptedBySignerName => text().nullable()();
  TextColumn get acceptedSignatureHash => text().nullable()();
  TextColumn get snapshotHash => text().nullable()();
  TextColumn get estimateDeclinedReason => text().nullable()();
  TextColumn get createdBy => text()();
  TextColumn get createdAt => text().map(const IsoUtcDateTimeConverter())();
  TextColumn get updatedAt => text().map(const IsoUtcDateTimeConverter())();
}

/// Plan lines. `removedAt` is a data-layer column (not on the entity): a
/// line dropped from an unaccepted plan is marked removed instead of being
/// deleted, so the companion for this table is written by hand.
@TableIndex(name: 'treatment_plan_lines_clinic', columns: {#clinicId})
@TableIndex(name: 'treatment_plan_lines_plan', columns: {#planId})
@UseRowClass(TreatmentPlanLine)
class TreatmentPlanLines extends PatientScopedTable {
  TextColumn get planId => text().references(TreatmentPlans, #id)();
  TextColumn get catalogItemId => text()();
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get laymanName => text()();
  TextColumn get tooth => text().map(const ToothIdConverter()).nullable()();
  TextColumn get teeth => text().map(const ToothListConverter())();
  TextColumn get surfaces => text().map(const SurfaceSetConverter())();
  TextColumn get treatmentArea => textEnum<TreatmentArea>()();
  IntColumn get phaseIndex => integer()();
  IntColumn get sequence => integer()();
  IntColumn get quantity => integer()();
  IntColumn get unitFee => integer().map(const MoneyConverter())();
  IntColumn get discount => integer().map(const MoneyConverter())();
  TextColumn get gstClass => textEnum<GstClass>()();
  BoolColumn get isAlternative => boolean()();
  TextColumn get alternativeGroup => text().nullable()();
  TextColumn get procedureId => text().nullable()();
  TextColumn get note => text().nullable()();

  /// When the line was dropped from its (unaccepted) plan; null while live.
  TextColumn get removedAt =>
      text().map(const IsoUtcDateTimeConverter()).nullable()();
}

/// Versioned estimates; lines are a JSON column.
@TableIndex(name: 'estimates_clinic', columns: {#clinicId})
@TableIndex(name: 'estimates_patient', columns: {#patientId})
@TableIndex(name: 'estimates_plan', columns: {#planId, #version})
@UseRowClass(Estimate, generateInsertable: true)
class Estimates extends PatientScopedTable {
  TextColumn get planId => text().nullable()();
  IntColumn get version => integer()();
  TextColumn get number => text()();
  TextColumn get lines => text().map(const EstimateLinesConverter())();
  IntColumn get subtotal => integer().map(const MoneyConverter())();
  IntColumn get discountTotal => integer().map(const MoneyConverter())();
  IntColumn get taxTotal => integer().map(const MoneyConverter())();
  IntColumn get grandTotal => integer().map(const MoneyConverter())();
  TextColumn get issuedAt => text().map(const IsoUtcDateTimeConverter())();
  TextColumn get issuedBy => text()();
  TextColumn get justification => text().nullable()();
  TextColumn get validUntil =>
      text().map(const IsoUtcDateTimeConverter()).nullable()();
  TextColumn get status => textEnum<EstimateStatus>()();
  IntColumn get planVersion => integer().nullable()();
  TextColumn get planSnapshotHash => text().nullable()();
  TextColumn get createdAt => text().map(const IsoUtcDateTimeConverter())();
}

/// Perio exams; site and tooth readings are JSON columns (source of truth)
/// and additionally flattened into [PerioSiteReadings] for querying.
@TableIndex(name: 'perio_exams_clinic', columns: {#clinicId})
@TableIndex(name: 'perio_exams_patient', columns: {#patientId, #examinedAt})
@UseRowClass(PerioExam, generateInsertable: true)
class PerioExams extends PatientScopedTable {
  TextColumn get visitId => text().nullable()();
  TextColumn get examinedAt => text().map(const IsoUtcDateTimeConverter())();
  TextColumn get examinerId => text()();
  TextColumn get sites => text().map(const PerioSitesConverter())();
  TextColumn get teeth => text().map(const PerioTeethConverter())();
  TextColumn get bpe => text().map(const BpeMapConverter())();
  TextColumn get bpeFurcation => text()
      .map(const SextantSetConverter())
      .withDefault(const Constant('[]'))();
  TextColumn get stage => textEnum<PeriodontitisStage>().nullable()();
  TextColumn get grade => textEnum<PeriodontitisGrade>().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get createdAt => text().map(const IsoUtcDateTimeConverter())();
}

/// Flattened perio site readings, one row per exam/tooth/site, derived from
/// `PerioExams.sites` so trends per site can be queried with SQL.
@TableIndex(
  name: 'perio_site_readings_patient_tooth',
  columns: {#patientId, #tooth},
)
@DataClassName('PerioSiteRow')
class PerioSiteReadings extends Table {
  /// Owning exam.
  TextColumn get examId => text().references(PerioExams, #id)();

  /// Owning clinic.
  TextColumn get clinicId => text()();

  /// Patient.
  TextColumn get patientId => text()();

  /// Exam time (denormalised for ordering).
  TextColumn get examinedAt => text().map(const IsoUtcDateTimeConverter())();

  /// Tooth.
  TextColumn get tooth => text().map(const ToothIdConverter())();

  /// Site.
  TextColumn get site => textEnum<PerioSite>()();

  /// Probing depth, mm.
  IntColumn get probingDepth => integer().nullable()();

  /// Gingival margin relative to CEJ, mm (negative = recession).
  IntColumn get gingivalMargin => integer().nullable()();

  /// Bleeding on probing.
  BoolColumn get bleeding => boolean()();

  /// Suppuration.
  BoolColumn get suppuration => boolean()();

  /// Plaque present.
  BoolColumn get plaque => boolean()();

  /// Calculus present.
  BoolColumn get calculus => boolean()();

  /// Mucogingival junction distance, mm.
  IntColumn get mucogingivalJunction => integer().nullable()();

  @override
  Set<Column> get primaryKey => {examId, tooth, site};
}

/// Implant fixtures with traceability.
@TableIndex(name: 'implant_records_clinic', columns: {#clinicId})
@TableIndex(name: 'implant_records_patient', columns: {#patientId})
@UseRowClass(ImplantRecord, generateInsertable: true)
class ImplantRecords extends PatientScopedTable {
  TextColumn get tooth => text().map(const ToothIdConverter())();
  TextColumn get procedureId => text().nullable()();
  TextColumn get brand => text()();
  TextColumn get system => text().nullable()();
  RealColumn get diameterMm => real().map(const NumConverter())();
  RealColumn get lengthMm => real().map(const NumConverter())();
  TextColumn get lotNumber => text()();
  TextColumn get udi => text().nullable()();
  TextColumn get expiryDate =>
      text().map(const IsoUtcDateTimeConverter()).nullable()();
  TextColumn get placedAt => text().map(const IsoUtcDateTimeConverter())();
  RealColumn get insertionTorqueNcm =>
      real().map(const NumConverter()).nullable()();
  TextColumn get graftMaterial => text().nullable()();
  TextColumn get membrane => text().nullable()();
  TextColumn get status => textEnum<ImplantStatus>()();
  TextColumn get note => text().nullable()();
  TextColumn get createdAt => text().map(const IsoUtcDateTimeConverter())();
  TextColumn get updatedAt => text().map(const IsoUtcDateTimeConverter())();
}
