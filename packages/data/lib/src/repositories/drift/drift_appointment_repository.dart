import 'package:ampdent_core/ampdent_core.dart';
import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../../db/converters.dart';
import '../actor_context.dart';
import '../appointment_repository.dart';
import 'audited_writer.dart';

/// Drift implementation of [AppointmentRepository].
class DriftAppointmentRepository extends DatabaseAccessor<AppDatabase>
    with AuditedWriter
    implements AppointmentRepository {
  /// Creates the repository over [db].
  DriftAppointmentRepository(super.db);

  $AppointmentsTable get _a => attachedDatabase.appointments;
  $VisitsTable get _v => attachedDatabase.visits;

  SimpleSelectStatement<$AppointmentsTable, Appointment> _rangeQuery(
    String clinicId,
    DateTime from,
    DateTime to,
  ) => select(_a)
    ..where(
      (t) =>
          t.clinicId.equals(clinicId) &
          t.startsAt.isBiggerOrEqualValue(encodeIsoUtc(from)) &
          t.startsAt.isSmallerThanValue(encodeIsoUtc(to)),
    )
    ..orderBy([(t) => OrderingTerm.asc(t.startsAt)]);

  @override
  Future<List<Appointment>> range(
    String clinicId,
    DateTime from,
    DateTime to,
  ) => _rangeQuery(clinicId, from, to).get();

  @override
  Stream<List<Appointment>> watchRange(
    String clinicId,
    DateTime from,
    DateTime to,
  ) => _rangeQuery(clinicId, from, to).watch();

  @override
  Future<Appointment?> getById(String id) =>
      (select(_a)..where((t) => t.id.equals(id))).getSingleOrNull();

  @override
  Stream<List<Appointment>> watchForPatient(String patientId) =>
      (select(_a)
            ..where((t) => t.patientId.equals(patientId))
            ..orderBy([(t) => OrderingTerm.desc(t.startsAt)]))
          .watch();

  @override
  Future<Appointment> upsert(ActorContext ctx, Appointment appointment) {
    checkTenant(ctx, appointment.clinicId, 'appointment.clinicId');
    if (!appointment.endsAt.isAfter(appointment.startsAt)) {
      throw ArgumentError.value(
        appointment.endsAt,
        'appointment.endsAt',
        'must be after startsAt',
      );
    }
    return writeTransaction(
      () async => audited(
        ctx: ctx,
        table: _a,
        entityType: 'Appointment',
        entityId: appointment.id,
        before: await getById(appointment.id),
        after: appointment,
        insertable: appointment.toInsertable(),
        toJson: (a) => a.toJson(),
      ),
    );
  }

  @override
  Future<Appointment> changeStatus(
    ActorContext ctx,
    String id,
    AppointmentStatus status, {
    String? reason,
    DateTime? at,
  }) => writeTransaction(() async {
    final before = await getById(id);
    if (before == null) throw StateError('Appointment $id not found');
    checkTenant(ctx, before.clinicId, 'appointment.clinicId');
    final now = nowUtc(at);
    final after = before.copyWith(
      status: status,
      confirmedAt: status == AppointmentStatus.confirmed ? now : null,
      arrivedAt: status == AppointmentStatus.arrived ? now : null,
      cancelledReason: status == AppointmentStatus.cancelled ? reason : null,
      updatedAt: now,
    );
    return audited(
      ctx: ctx,
      table: _a,
      entityType: 'Appointment',
      entityId: id,
      before: before,
      after: after,
      insertable: after.toInsertable(),
      toJson: (a) => a.toJson(),
      action: AuditAction.statusChange,
      reason: reason,
    );
  });

  @override
  Future<List<Appointment>> conflicts({
    required String clinicId,
    String? chairId,
    String? providerId,
    required DateTime start,
    required DateTime end,
    String? excludeId,
  }) {
    if (chairId == null && providerId == null) return Future.value(const []);
    final occupying = AppointmentStatus.values
        .where((s) => s.occupiesChair)
        .toList();
    return (select(_a)..where((t) {
          Expression<bool> resource = const Constant(false);
          if (chairId != null) resource = resource | t.chairId.equals(chairId);
          if (providerId != null) {
            resource = resource | t.providerId.equals(providerId);
          }
          var where =
              t.clinicId.equals(clinicId) &
              t.status.isInValues(occupying) &
              t.startsAt.isSmallerThanValue(encodeIsoUtc(end)) &
              t.endsAt.isBiggerThanValue(encodeIsoUtc(start)) &
              resource;
          if (excludeId != null) where = where & t.id.equals(excludeId).not();
          return where;
        }))
        .get();
  }

  @override
  Future<Visit> startVisit(ActorContext ctx, Visit visit) {
    checkTenant(ctx, visit.clinicId, 'visit.clinicId');
    return writeTransaction(
      () async => audited(
        ctx: ctx,
        table: _v,
        entityType: 'Visit',
        entityId: visit.id,
        before: await getVisit(visit.id),
        after: visit,
        insertable: visit.toInsertable(),
        toJson: (v) => v.toJson(),
      ),
    );
  }

  @override
  Future<Visit> updateVisit(ActorContext ctx, Visit visit) =>
      startVisit(ctx, visit);

  @override
  Future<Visit> endVisit(ActorContext ctx, String visitId, {DateTime? at}) =>
      writeTransaction(() async {
        final before = await getVisit(visitId);
        if (before == null) throw StateError('Visit $visitId not found');
        checkTenant(ctx, before.clinicId, 'visit.clinicId');
        final now = nowUtc(at);
        final after = before.copyWith(endedAt: now, updatedAt: now);
        return audited(
          ctx: ctx,
          table: _v,
          entityType: 'Visit',
          entityId: visitId,
          before: before,
          after: after,
          insertable: after.toInsertable(),
          toJson: (v) => v.toJson(),
          action: AuditAction.statusChange,
        );
      });

  @override
  Future<Visit?> getVisit(String id) =>
      (select(_v)..where((t) => t.id.equals(id))).getSingleOrNull();

  @override
  Future<Visit?> openVisit(String patientId) =>
      (select(_v)
            ..where((t) => t.patientId.equals(patientId) & t.endedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
            ..limit(1))
          .getSingleOrNull();

  @override
  Stream<List<Visit>> watchVisits(String patientId) =>
      (select(_v)
            ..where((t) => t.patientId.equals(patientId))
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
          .watch();
}
