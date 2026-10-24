import 'package:ampdent_core/ampdent_core.dart';

import 'actor_context.dart';

/// Every record of one patient, as JSON-ready lists. Section names are in
/// [PatientExportBundle.sectionKeys] and match the keys of [toJson].
class PatientExportBundle {
  /// Creates a bundle.
  const PatientExportBundle({
    required this.exportedAt,
    required this.patient,
    required this.appointments,
    required this.visits,
    required this.toothStates,
    required this.findings,
    required this.procedures,
    required this.treatmentPlans,
    required this.planLines,
    required this.estimates,
    required this.consents,
    required this.dataConsents,
    required this.clinicalNotes,
    required this.medicalHistories,
    required this.perioExams,
    required this.prescriptions,
    required this.images,
    required this.labCases,
    required this.implants,
    required this.invoices,
    required this.payments,
    required this.adjustments,
    required this.ledgerEntries,
    required this.recalls,
    required this.messageLogs,
  });

  /// Export time.
  final DateTime exportedAt;

  /// The patient.
  final Patient patient;

  /// Appointments.
  final List<Appointment> appointments;

  /// Visits.
  final List<Visit> visits;

  /// Tooth-state history.
  final List<ToothStateRecord> toothStates;

  /// Findings.
  final List<Finding> findings;

  /// Procedures.
  final List<ProcedureRecord> procedures;

  /// Treatment plans.
  final List<TreatmentPlan> treatmentPlans;

  /// Plan lines.
  final List<TreatmentPlanLine> planLines;

  /// Estimates.
  final List<Estimate> estimates;

  /// Procedure consents.
  final List<ConsentRecord> consents;

  /// Data consents.
  final List<DataConsent> dataConsents;

  /// Clinical notes (all versions).
  final List<ClinicalNote> clinicalNotes;

  /// Medical histories.
  final List<MedicalHistory> medicalHistories;

  /// Perio exams.
  final List<PerioExam> perioExams;

  /// Prescriptions.
  final List<Prescription> prescriptions;

  /// Images.
  final List<ImageRecord> images;

  /// Lab cases.
  final List<LabCase> labCases;

  /// Implants.
  final List<ImplantRecord> implants;

  /// Invoices.
  final List<Invoice> invoices;

  /// Payments.
  final List<Payment> payments;

  /// Adjustments.
  final List<Adjustment> adjustments;

  /// Ledger entries.
  final List<LedgerEntry> ledgerEntries;

  /// Recalls.
  final List<Recall> recalls;

  /// Message log.
  final List<MessageLog> messageLogs;

  /// Section keys present in [toJson], in order.
  static const List<String> sectionKeys = [
    'patient',
    'appointments',
    'visits',
    'toothStates',
    'findings',
    'procedures',
    'treatmentPlans',
    'planLines',
    'estimates',
    'consents',
    'dataConsents',
    'clinicalNotes',
    'medicalHistories',
    'perioExams',
    'prescriptions',
    'images',
    'labCases',
    'implants',
    'invoices',
    'payments',
    'adjustments',
    'ledgerEntries',
    'recalls',
    'messageLogs',
  ];

  /// JSON form (dates ISO-8601, money as `{paise}`).
  Map<String, Object?> toJson() => {
    'exportedAt': dateToJson(exportedAt),
    'patient': patient.toJson(),
    'appointments': appointments.map((e) => e.toJson()).toList(),
    'visits': visits.map((e) => e.toJson()).toList(),
    'toothStates': toothStates.map((e) => e.toJson()).toList(),
    'findings': findings.map((e) => e.toJson()).toList(),
    'procedures': procedures.map((e) => e.toJson()).toList(),
    'treatmentPlans': treatmentPlans.map((e) => e.toJson()).toList(),
    'planLines': planLines.map((e) => e.toJson()).toList(),
    'estimates': estimates.map((e) => e.toJson()).toList(),
    'consents': consents.map((e) => e.toJson()).toList(),
    'dataConsents': dataConsents.map((e) => e.toJson()).toList(),
    'clinicalNotes': clinicalNotes.map((e) => e.toJson()).toList(),
    'medicalHistories': medicalHistories.map((e) => e.toJson()).toList(),
    'perioExams': perioExams.map((e) => e.toJson()).toList(),
    'prescriptions': prescriptions.map((e) => e.toJson()).toList(),
    'images': images.map((e) => e.toJson()).toList(),
    'labCases': labCases.map((e) => e.toJson()).toList(),
    'implants': implants.map((e) => e.toJson()).toList(),
    'invoices': invoices.map((e) => e.toJson()).toList(),
    'payments': payments.map((e) => e.toJson()).toList(),
    'adjustments': adjustments.map((e) => e.toJson()).toList(),
    'ledgerEntries': ledgerEntries.map((e) => e.toJson()).toList(),
    'recalls': recalls.map((e) => e.toJson()).toList(),
    'messageLogs': messageLogs.map((e) => e.toJson()).toList(),
  };
}

/// Everything belonging to one clinic: master data plus a
/// [PatientExportBundle] per patient and the clinic-level registers.
class ClinicExportBundle {
  /// Creates a bundle.
  const ClinicExportBundle({
    required this.exportedAt,
    required this.clinic,
    required this.chairs,
    required this.members,
    required this.settings,
    required this.catalogItems,
    required this.labs,
    required this.patients,
    required this.sterilisationCycles,
    required this.licences,
    required this.auditEvents,
  });

  /// Export time.
  final DateTime exportedAt;

  /// The clinic.
  final Clinic clinic;

  /// Chairs.
  final List<Chair> chairs;

  /// Members.
  final List<ClinicMember> members;

  /// Settings as key to raw JSON value.
  final Map<String, String> settings;

  /// Clinic-scoped catalogue items.
  final List<CatalogItem> catalogItems;

  /// Labs.
  final List<Lab> labs;

  /// One bundle per patient.
  final List<PatientExportBundle> patients;

  /// Sterilisation register.
  final List<SterilisationCycle> sterilisationCycles;

  /// Licences.
  final List<Licence> licences;

  /// Audit log.
  final List<AuditEvent> auditEvents;

  /// JSON form.
  Map<String, Object?> toJson() => {
    'exportedAt': dateToJson(exportedAt),
    'clinic': clinic.toJson(),
    'chairs': chairs.map((e) => e.toJson()).toList(),
    'members': members.map((e) => e.toJson()).toList(),
    'settings': settings,
    'catalogItems': catalogItems.map((e) => e.toJson()).toList(),
    'labs': labs.map((e) => e.toJson()).toList(),
    'patients': patients.map((e) => e.toJson()).toList(),
    'sterilisationCycles': sterilisationCycles.map((e) => e.toJson()).toList(),
    'licences': licences.map((e) => e.toJson()).toList(),
    'auditEvents': auditEvents.map((e) => e.toJson()).toList(),
  };
}

/// Record export (DPDP access requests, patient transfer, backup). Every
/// export is itself audited.
abstract class ExportRepository {
  /// All records for one patient.
  Future<PatientExportBundle> exportPatient(ActorContext ctx, String patientId);

  /// Everything for the actor's clinic.
  Future<ClinicExportBundle> exportClinic(ActorContext ctx);
}
