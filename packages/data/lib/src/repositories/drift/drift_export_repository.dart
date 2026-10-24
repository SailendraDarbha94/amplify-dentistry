import 'package:ampdent_core/ampdent_core.dart';
import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../actor_context.dart';
import '../export_repository.dart';
import 'audited_writer.dart';

/// Drift implementation of [ExportRepository].
class DriftExportRepository extends DatabaseAccessor<AppDatabase>
    with AuditedWriter
    implements ExportRepository {
  /// Creates the repository over [db].
  DriftExportRepository(super.db);

  AppDatabase get _db => attachedDatabase;

  Future<List<R>> _byPatient<T extends Table, R>(
    TableInfo<T, R> table,
    Expression<bool> Function(T) where,
  ) => (select(table)..where(where)).get();

  @override
  Future<PatientExportBundle> exportPatient(
    ActorContext ctx,
    String patientId,
  ) => transaction(() async {
    final patient = await (select(
      _db.patients,
    )..where((t) => t.id.equals(patientId))).getSingleOrNull();
    if (patient == null) throw StateError('Patient $patientId not found');
    checkTenant(ctx, patient.clinicId, 'patient.clinicId');
    final now = nowUtc();
    final bundle = PatientExportBundle(
      exportedAt: now,
      patient: patient,
      appointments: await _byPatient(
        _db.appointments,
        (t) => t.patientId.equals(patientId),
      ),
      visits: await _byPatient(
        _db.visits,
        (t) => t.patientId.equals(patientId),
      ),
      toothStates: await _byPatient(
        _db.toothStateRecords,
        (t) => t.patientId.equals(patientId),
      ),
      findings: await _byPatient(
        _db.findings,
        (t) => t.patientId.equals(patientId),
      ),
      procedures: await _byPatient(
        _db.procedures,
        (t) => t.patientId.equals(patientId),
      ),
      treatmentPlans: await _byPatient(
        _db.treatmentPlans,
        (t) => t.patientId.equals(patientId),
      ),
      planLines: await _byPatient(
        _db.treatmentPlanLines,
        (t) => t.patientId.equals(patientId) & t.removedAt.isNull(),
      ),
      estimates: await _byPatient(
        _db.estimates,
        (t) => t.patientId.equals(patientId),
      ),
      consents: await _byPatient(
        _db.consentRecords,
        (t) => t.patientId.equals(patientId),
      ),
      dataConsents: await _byPatient(
        _db.dataConsents,
        (t) => t.patientId.equals(patientId),
      ),
      clinicalNotes: await _byPatient(
        _db.clinicalNotes,
        (t) => t.patientId.equals(patientId),
      ),
      medicalHistories: await _byPatient(
        _db.medicalHistories,
        (t) => t.patientId.equals(patientId),
      ),
      perioExams: await _byPatient(
        _db.perioExams,
        (t) => t.patientId.equals(patientId),
      ),
      prescriptions: await _byPatient(
        _db.prescriptions,
        (t) => t.patientId.equals(patientId),
      ),
      images: await _byPatient(
        _db.imageRecords,
        (t) => t.patientId.equals(patientId),
      ),
      labCases: await _byPatient(
        _db.labCases,
        (t) => t.patientId.equals(patientId),
      ),
      implants: await _byPatient(
        _db.implantRecords,
        (t) => t.patientId.equals(patientId),
      ),
      invoices: await _byPatient(
        _db.invoices,
        (t) => t.patientId.equals(patientId),
      ),
      payments: await _byPatient(
        _db.payments,
        (t) => t.patientId.equals(patientId),
      ),
      adjustments: await _byPatient(
        _db.adjustments,
        (t) => t.patientId.equals(patientId),
      ),
      ledgerEntries: await _byPatient(
        _db.ledgerEntries,
        (t) => t.patientId.equals(patientId),
      ),
      recalls: await _byPatient(
        _db.recalls,
        (t) => t.patientId.equals(patientId),
      ),
      messageLogs: await _byPatient(
        _db.messageLogs,
        (t) => t.patientId.equals(patientId),
      ),
    );
    await recordAccess(
      ctx: ctx,
      action: AuditAction.export,
      entityType: 'Patient',
      entityId: patientId,
    );
    return bundle;
  });

  @override
  Future<ClinicExportBundle> exportClinic(ActorContext ctx) =>
      transaction(() async {
        final clinicId = ctx.clinicId;
        final clinic = await (select(
          _db.clinics,
        )..where((t) => t.id.equals(clinicId))).getSingleOrNull();
        if (clinic == null) throw StateError('Clinic $clinicId not found');
        final now = nowUtc();
        final patients =
            await (select(_db.patients)
                  ..where((t) => t.clinicId.equals(clinicId))
                  ..orderBy([(t) => OrderingTerm.asc(t.patientNumber)]))
                .get();
        final bundles = <PatientExportBundle>[];
        for (final p in patients) {
          bundles.add(await exportPatient(ctx, p.id));
        }
        final settings = await (select(
          _db.settings,
        )..where((t) => t.clinicId.equals(clinicId))).get();
        final bundle = ClinicExportBundle(
          exportedAt: now,
          clinic: clinic,
          chairs: await _byPatient(
            _db.chairs,
            (t) => t.clinicId.equals(clinicId),
          ),
          members: await _byPatient(
            _db.clinicMembers,
            (t) => t.clinicId.equals(clinicId),
          ),
          settings: {for (final s in settings) s.settingKey: s.valueJson},
          catalogItems: await _byPatient(
            _db.catalogItems,
            (t) => t.clinicId.equals(clinicId),
          ),
          labs: await _byPatient(_db.labs, (t) => t.clinicId.equals(clinicId)),
          patients: bundles,
          sterilisationCycles: await _byPatient(
            _db.sterilisationCycles,
            (t) => t.clinicId.equals(clinicId),
          ),
          licences: await _byPatient(
            _db.licences,
            (t) => t.clinicId.equals(clinicId),
          ),
          auditEvents: await _byPatient(
            _db.auditEvents,
            (t) => t.clinicId.equals(clinicId),
          ),
        );
        await recordAccess(
          ctx: ctx,
          action: AuditAction.export,
          entityType: 'Clinic',
          entityId: clinicId,
        );
        return bundle;
      });
}
