import 'package:ampdent_core/ampdent_core.dart';
import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../actor_context.dart';
import '../patient_repository.dart';
import 'audited_writer.dart';

/// Drift implementation of [PatientRepository].
class DriftPatientRepository extends DatabaseAccessor<AppDatabase>
    with AuditedWriter
    implements PatientRepository {
  /// Creates the repository over [db].
  DriftPatientRepository(super.db);

  $PatientsTable get _t => attachedDatabase.patients;

  Expression<bool> _matches($PatientsTable t, String query) {
    final q = query.trim();
    if (q.isEmpty) return const Constant(true);
    return t.firstName.contains(q) |
        t.lastName.contains(q) |
        t.phone.contains(q) |
        t.altPhone.contains(q) |
        t.patientNumber.contains(q) |
        (t.firstName + const Constant(' ') + t.lastName).contains(q);
  }

  SimpleSelectStatement<$PatientsTable, Patient> _query(
    String clinicId, {
    String? query,
    bool includeInactive = false,
    int? limit,
  }) {
    final q = select(_t)
      ..where(
        (t) =>
            t.clinicId.equals(clinicId) &
            (includeInactive ? const Constant(true) : t.isActive.equals(true)) &
            _matches(t, query ?? ''),
      )
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    if (limit != null) q.limit(limit);
    return q;
  }

  @override
  Stream<List<Patient>> watchAll(
    String clinicId, {
    String? query,
    bool includeInactive = false,
  }) =>
      _query(clinicId, query: query, includeInactive: includeInactive).watch();

  @override
  Future<Patient?> getById(String id) =>
      (select(_t)..where((t) => t.id.equals(id))).getSingleOrNull();

  @override
  Stream<Patient?> watchById(String id) =>
      (select(_t)..where((t) => t.id.equals(id))).watchSingleOrNull();

  @override
  Stream<List<Patient>> watchByIds(Iterable<String> ids) {
    final list = ids.toList();
    if (list.isEmpty) return Stream.value(const []);
    return (select(_t)..where((t) => t.id.isIn(list))).watch();
  }

  @override
  Future<Patient> upsert(ActorContext ctx, Patient patient) {
    checkTenant(ctx, patient.clinicId, 'patient.clinicId');
    return writeTransaction(
      () async => audited(
        ctx: ctx,
        table: _t,
        entityType: 'Patient',
        entityId: patient.id,
        before: await getById(patient.id),
        after: patient,
        insertable: patient.toInsertable(),
        toJson: (p) => p.toJson(),
      ),
    );
  }

  @override
  Future<List<Patient>> search(
    String clinicId,
    String query, {
    int limit = 50,
  }) => _query(clinicId, query: query, limit: limit).get();

  @override
  Future<List<Patient>> findByPhone(String clinicId, String phone) =>
      (select(_t)..where(
            (t) =>
                t.clinicId.equals(clinicId) &
                t.isActive.equals(true) &
                (t.phone.equals(phone) | t.altPhone.equals(phone)),
          ))
          .get();

  @override
  Future<Patient?> findByNumber(String clinicId, String patientNumber) =>
      (select(_t)..where(
            (t) =>
                t.clinicId.equals(clinicId) &
                t.patientNumber.equals(patientNumber),
          ))
          .getSingleOrNull();

  @override
  Future<Patient> deactivate(ActorContext ctx, String id, {String? reason}) =>
      writeTransaction(() async {
        final before = await getById(id);
        if (before == null) throw StateError('Patient $id not found');
        checkTenant(ctx, before.clinicId, 'patient.clinicId');
        final after = before.copyWith(isActive: false, updatedAt: nowUtc());
        return audited(
          ctx: ctx,
          table: _t,
          entityType: 'Patient',
          entityId: id,
          before: before,
          after: after,
          insertable: after.toInsertable(),
          toJson: (p) => p.toJson(),
          action: AuditAction.softDelete,
          reason: reason,
        );
      });

  @override
  Future<int> count(String clinicId) async {
    final c = countAll();
    final row =
        await (selectOnly(_t)
              ..addColumns([c])
              ..where(_t.clinicId.equals(clinicId) & _t.isActive.equals(true)))
            .getSingle();
    return row.read(c) ?? 0;
  }
}
