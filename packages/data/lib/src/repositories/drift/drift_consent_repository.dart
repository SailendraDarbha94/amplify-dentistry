import 'package:ampdent_core/ampdent_core.dart';
import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../actor_context.dart';
import '../consent_repository.dart';
import 'audited_writer.dart';

/// Drift implementation of [ConsentRepository].
class DriftConsentRepository extends DatabaseAccessor<AppDatabase>
    with AuditedWriter
    implements ConsentRepository {
  /// Creates the repository over [db].
  DriftConsentRepository(super.db);

  $ConsentRecordsTable get _c => attachedDatabase.consentRecords;
  $DataConsentsTable get _d => attachedDatabase.dataConsents;

  @override
  Future<ConsentRecord> recordConsent(ActorContext ctx, ConsentRecord consent) {
    checkTenant(ctx, consent.clinicId, 'consent.clinicId');
    return writeTransaction(() async {
      final before = await getConsent(consent.id);
      if (before != null) {
        throw StateError('Consent ${consent.id} is immutable once signed');
      }
      return audited<ConsentRecord>(
        ctx: ctx,
        table: _c,
        entityType: 'ConsentRecord',
        entityId: consent.id,
        before: null,
        after: consent,
        insertable: consent.toInsertable(),
        toJson: (c) => c.toJson(),
      );
    });
  }

  @override
  Future<ConsentRecord?> getConsent(String id) =>
      (select(_c)..where((t) => t.id.equals(id))).getSingleOrNull();

  SimpleSelectStatement<$ConsentRecordsTable, ConsentRecord> _forPatient(
    String patientId,
  ) => select(_c)
    ..where((t) => t.patientId.equals(patientId))
    ..orderBy([(t) => OrderingTerm.desc(t.signedAt)]);

  @override
  Future<List<ConsentRecord>> consentsForPatient(String patientId) =>
      _forPatient(patientId).get();

  @override
  Stream<List<ConsentRecord>> watchConsents(String patientId) =>
      _forPatient(patientId).watch();

  @override
  Future<List<ConsentRecord>> consentsForProcedure(String procedureId) =>
      (select(_c)
            ..where((t) => t.procedureIds.contains('"$procedureId"'))
            ..orderBy([(t) => OrderingTerm.desc(t.signedAt)]))
          .get();

  @override
  Future<DataConsent> recordDataConsent(ActorContext ctx, DataConsent consent) {
    checkTenant(ctx, consent.clinicId, 'consent.clinicId');
    return writeTransaction(
      () async => audited(
        ctx: ctx,
        table: _d,
        entityType: 'DataConsent',
        entityId: consent.id,
        before: await _dataConsent(consent.id),
        after: consent,
        insertable: consent.toInsertable(),
        toJson: (c) => c.toJson(),
      ),
    );
  }

  Future<DataConsent?> _dataConsent(String id) =>
      (select(_d)..where((t) => t.id.equals(id))).getSingleOrNull();

  @override
  Future<DataConsent> withdrawDataConsent(
    ActorContext ctx,
    String id, {
    DateTime? at,
  }) => writeTransaction(() async {
    final before = await _dataConsent(id);
    if (before == null) throw StateError('Data consent $id not found');
    checkTenant(ctx, before.clinicId, 'consent.clinicId');
    final after = before.copyWith(withdrawnAt: nowUtc(at));
    return audited(
      ctx: ctx,
      table: _d,
      entityType: 'DataConsent',
      entityId: id,
      before: before,
      after: after,
      insertable: after.toInsertable(),
      toJson: (c) => c.toJson(),
      action: AuditAction.statusChange,
    );
  });

  SimpleSelectStatement<$DataConsentsTable, DataConsent> _dataForPatient(
    String patientId,
  ) => select(_d)
    ..where((t) => t.patientId.equals(patientId))
    ..orderBy([
      (t) => OrderingTerm.desc(t.grantedAt),
      (t) => OrderingTerm.desc(t.createdAt),
    ]);

  @override
  Future<List<DataConsent>> dataConsentsForPatient(String patientId) =>
      _dataForPatient(patientId).get();

  @override
  Stream<List<DataConsent>> watchDataConsents(String patientId) =>
      _dataForPatient(patientId).watch();

  @override
  Future<Map<DataPurpose, DataConsent>> latestDataConsents(
    String patientId,
  ) async {
    final out = <DataPurpose, DataConsent>{};
    for (final c in await dataConsentsForPatient(patientId)) {
      out.putIfAbsent(c.purpose, () => c);
    }
    return out;
  }

  @override
  Future<bool> hasActiveDataConsent(
    String patientId,
    DataPurpose purpose,
  ) async => (await latestDataConsents(patientId))[purpose]?.isActive ?? false;
}
