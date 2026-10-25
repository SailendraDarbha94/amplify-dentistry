/// Offline-first local store for AmpDent: Drift/SQLite tables for every
/// `ampdent_core` entity, abstract repositories with Drift implementations,
/// append-only audit log, sync outbox and seeding.
///
/// Open [AppDatabase.open] (device) or [AppDatabase.inMemory] (tests), wrap
/// it in [DriftRepositories], and pass an [ActorContext] to every write.
library;

export 'src/db/app_database.dart'
    show
        AppDatabase,
        OutboxEntry,
        PerioSiteRow,
        SettingRow,
        SyncOutboxCompanion,
        SettingsCompanion;
export 'src/db/converters.dart';
export 'src/db/settings_codec.dart';
export 'src/db/tables_clinic.dart' show OutboxOperation;
export 'src/repositories/actor_context.dart';
export 'src/repositories/appointment_repository.dart';
export 'src/repositories/audit_repository.dart';
export 'src/repositories/billing_repository.dart';
export 'src/repositories/catalog_repository.dart';
export 'src/repositories/chart_repository.dart';
export 'src/repositories/clinic_repository.dart';
export 'src/repositories/clinical_repository.dart';
export 'src/repositories/compliance_repository.dart';
export 'src/repositories/consent_repository.dart';
export 'src/repositories/drift/audited_writer.dart';
export 'src/repositories/drift/drift_appointment_repository.dart';
export 'src/repositories/drift/drift_audit_repository.dart';
export 'src/repositories/drift/drift_billing_repository.dart';
export 'src/repositories/drift/drift_catalog_repository.dart';
export 'src/repositories/drift/drift_chart_repository.dart';
export 'src/repositories/drift/drift_clinic_repository.dart';
export 'src/repositories/drift/drift_clinical_repository.dart';
export 'src/repositories/drift/drift_compliance_repository.dart';
export 'src/repositories/drift/drift_consent_repository.dart';
export 'src/repositories/drift/drift_estimate_methods.dart';
export 'src/repositories/drift/drift_export_repository.dart';
export 'src/repositories/drift/drift_lab_repository.dart';
export 'src/repositories/drift/drift_ledger_methods.dart';
export 'src/repositories/drift/drift_message_log_repository.dart';
export 'src/repositories/drift/drift_patient_repository.dart';
export 'src/repositories/drift/drift_perio_repository.dart';
export 'src/repositories/drift/drift_prescription_repository.dart';
export 'src/repositories/drift/drift_recall_repository.dart';
export 'src/repositories/drift/drift_repositories.dart';
export 'src/repositories/drift/drift_treatment_plan_repository.dart';
export 'src/repositories/drift/repository_exception.dart';
export 'src/repositories/drift/settings_access.dart';
export 'src/repositories/export_repository.dart';
export 'src/repositories/lab_repository.dart';
export 'src/repositories/message_log_repository.dart';
export 'src/repositories/patient_repository.dart';
export 'src/repositories/perio_repository.dart';
export 'src/repositories/prescription_repository.dart';
export 'src/repositories/recall_repository.dart';
export 'src/repositories/treatment_plan_repository.dart';
export 'src/seed/seeder.dart';
export 'src/sync/outbox_repository.dart';
export 'src/sync/sync_engine.dart';
