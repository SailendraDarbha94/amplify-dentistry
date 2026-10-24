import '../../db/app_database.dart';
import '../../sync/outbox_repository.dart';
import '../appointment_repository.dart';
import '../audit_repository.dart';
import '../billing_repository.dart';
import '../catalog_repository.dart';
import '../chart_repository.dart';
import '../clinic_repository.dart';
import '../clinical_repository.dart';
import '../compliance_repository.dart';
import '../consent_repository.dart';
import '../export_repository.dart';
import '../lab_repository.dart';
import '../message_log_repository.dart';
import '../patient_repository.dart';
import '../perio_repository.dart';
import '../prescription_repository.dart';
import '../recall_repository.dart';
import '../treatment_plan_repository.dart';
import 'drift_appointment_repository.dart';
import 'drift_audit_repository.dart';
import 'drift_billing_repository.dart';
import 'drift_catalog_repository.dart';
import 'drift_chart_repository.dart';
import 'drift_clinic_repository.dart';
import 'drift_clinical_repository.dart';
import 'drift_compliance_repository.dart';
import 'drift_consent_repository.dart';
import 'drift_export_repository.dart';
import 'drift_lab_repository.dart';
import 'drift_message_log_repository.dart';
import 'drift_patient_repository.dart';
import 'drift_perio_repository.dart';
import 'drift_prescription_repository.dart';
import 'drift_recall_repository.dart';
import 'drift_treatment_plan_repository.dart';

/// Every repository wired to one [AppDatabase]; the app exposes these
/// through providers so features depend only on the abstract types.
class DriftRepositories {
  /// Builds all repositories over [db].
  DriftRepositories(this.db)
    : clinics = DriftClinicRepository(db),
      patients = DriftPatientRepository(db),
      appointments = DriftAppointmentRepository(db),
      chart = DriftChartRepository(db),
      catalog = DriftCatalogRepository(db),
      treatmentPlans = DriftTreatmentPlanRepository(db),
      consents = DriftConsentRepository(db),
      clinical = DriftClinicalRepository(db),
      perio = DriftPerioRepository(db),
      prescriptions = DriftPrescriptionRepository(db),
      billing = DriftBillingRepository(db),
      recalls = DriftRecallRepository(db),
      labs = DriftLabRepository(db),
      compliance = DriftComplianceRepository(db),
      audit = DriftAuditRepository(db),
      messages = DriftMessageLogRepository(db),
      export = DriftExportRepository(db),
      outbox = DriftOutboxRepository(db);

  /// The database.
  final AppDatabase db;

  /// Clinic master data.
  final ClinicRepository clinics;

  /// Patients.
  final PatientRepository patients;

  /// Appointments and visits.
  final AppointmentRepository appointments;

  /// Odontogram data.
  final ChartRepository chart;

  /// Procedure catalogue.
  final CatalogRepository catalog;

  /// Plans and estimates.
  final TreatmentPlanRepository treatmentPlans;

  /// Consents.
  final ConsentRepository consents;

  /// Notes, histories, images.
  final ClinicalRepository clinical;

  /// Perio exams.
  final PerioRepository perio;

  /// Drugs and prescriptions.
  final PrescriptionRepository prescriptions;

  /// Billing and ledger.
  final BillingRepository billing;

  /// Recalls.
  final RecallRepository recalls;

  /// Labs and cases.
  final LabRepository labs;

  /// Sterilisation and licences.
  final ComplianceRepository compliance;

  /// Audit log.
  final AuditRepository audit;

  /// Message log.
  final MessageLogRepository messages;

  /// Record export.
  final ExportRepository export;

  /// Sync outbox.
  final OutboxRepository outbox;
}
