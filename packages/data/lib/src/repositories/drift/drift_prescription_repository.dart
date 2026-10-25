import 'package:ampdent_core/ampdent_core.dart';
import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../../seed/seeder.dart';
import '../actor_context.dart';
import '../prescription_repository.dart';
import 'audited_writer.dart';

/// Drift implementation of [PrescriptionRepository].
class DriftPrescriptionRepository extends DatabaseAccessor<AppDatabase>
    with AuditedWriter
    implements PrescriptionRepository {
  /// Creates the repository over [db].
  DriftPrescriptionRepository(super.db);

  $DrugsTable get _drugs => attachedDatabase.drugs;
  $PrescriptionsTable get _rx => attachedDatabase.prescriptions;

  @override
  Future<int> seedDrugMasterIfEmpty() async =>
      (await Seeder(attachedDatabase).seedGlobal()).drugsInserted;

  @override
  Future<List<Drug>> drugs({bool includeInactive = false}) =>
      (select(_drugs)
            ..where(
              (t) => includeInactive
                  ? const Constant(true)
                  : t.isActive.equals(true),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.genericName)]))
          .get();

  @override
  Future<Drug?> getDrug(String id) =>
      (select(_drugs)..where((t) => t.id.equals(id))).getSingleOrNull();

  @override
  Future<List<Drug>> searchDrugs(String query, {int limit = 50}) {
    final q = query.trim();
    if (q.isEmpty) return Future.value(const []);
    return (select(_drugs)
          ..where(
            (t) =>
                t.isActive.equals(true) &
                (t.genericName.contains(q) | t.brandNames.contains(q)),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.genericName)])
          ..limit(limit))
        .get();
  }

  @override
  Future<Drug> upsertDrug(ActorContext ctx, Drug drug) {
    final clinicId = drug.clinicId;
    if (clinicId != null) checkTenant(ctx, clinicId, 'drug.clinicId');
    return writeTransaction(
      () async => audited(
        ctx: ctx,
        table: _drugs,
        entityType: 'Drug',
        entityId: drug.id,
        before: await getDrug(drug.id),
        after: drug,
        insertable: drug.toInsertable(),
        toJson: (d) => d.toJson(),
      ),
    );
  }

  @override
  Future<Prescription> issuePrescription(
    ActorContext ctx,
    Prescription prescription,
  ) {
    checkTenant(ctx, prescription.clinicId, 'prescription.clinicId');
    return writeTransaction(() async {
      final before = await getPrescription(prescription.id);
      if (before != null) {
        throw StateError('Prescription ${prescription.id} is immutable');
      }
      final rx = prescription.verificationCode.isEmpty
          ? Prescription(
              id: prescription.id,
              clinicId: prescription.clinicId,
              patientId: prescription.patientId,
              visitId: prescription.visitId,
              prescriberId: prescription.prescriberId,
              prescriberName: prescription.prescriberName,
              prescriberRegistrationNumber:
                  prescription.prescriberRegistrationNumber,
              prescriberQualifications: prescription.prescriberQualifications,
              issuedAt: prescription.issuedAt,
              diagnosis: prescription.diagnosis,
              lines: prescription.lines,
              isRepeatable: prescription.isRepeatable,
              dispensedByClinic: prescription.dispensedByClinic,
              verificationCode: newVerificationCode(),
              documentHash: prescription.documentHash,
              pdfPath: prescription.pdfPath,
              patientSnapshot: prescription.patientSnapshot,
              createdAt: prescription.createdAt,
            )
          : prescription;
      return audited<Prescription>(
        ctx: ctx,
        table: _rx,
        entityType: 'Prescription',
        entityId: rx.id,
        before: null,
        after: rx,
        insertable: rx.toInsertable(),
        toJson: (p) => p.toJson(),
      );
    });
  }

  /// Eight uppercase alphanumeric characters derived from a fresh UUID.
  static String newVerificationCode() =>
      newId().replaceAll('-', '').substring(0, 8).toUpperCase();

  @override
  Future<Prescription?> getPrescription(String id) =>
      (select(_rx)..where((t) => t.id.equals(id))).getSingleOrNull();

  @override
  Future<Prescription?> byVerificationCode(String code) =>
      (select(_rx)
            ..where((t) => t.verificationCode.equals(code))
            ..limit(1))
          .getSingleOrNull();

  SimpleSelectStatement<$PrescriptionsTable, Prescription> _forPatient(
    String patientId,
  ) => select(_rx)
    ..where((t) => t.patientId.equals(patientId))
    ..orderBy([(t) => OrderingTerm.desc(t.issuedAt)]);

  @override
  Future<List<Prescription>> prescriptionsForPatient(String patientId) =>
      _forPatient(patientId).get();

  @override
  Stream<List<Prescription>> watchPrescriptions(String patientId) =>
      _forPatient(patientId).watch();
}
