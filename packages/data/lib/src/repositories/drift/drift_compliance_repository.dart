import 'package:ampdent_core/ampdent_core.dart';
import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../../db/converters.dart';
import '../../db/settings_codec.dart';
import '../actor_context.dart';
import '../compliance_repository.dart';
import 'audited_writer.dart';
import 'settings_access.dart';

/// Drift implementation of [ComplianceRepository].
class DriftComplianceRepository extends DatabaseAccessor<AppDatabase>
    with AuditedWriter, SettingsAccess
    implements ComplianceRepository {
  /// Creates the repository over [db].
  DriftComplianceRepository(super.db);

  $SterilisationCyclesTable get _cycles => attachedDatabase.sterilisationCycles;
  $LicencesTable get _licences => attachedDatabase.licences;

  @override
  Future<SterilisationCycle> recordCycle(
    ActorContext ctx,
    SterilisationCycle cycle,
  ) {
    checkTenant(ctx, cycle.clinicId, 'cycle.clinicId');
    return writeTransaction(() async {
      final existing = await (select(
        _cycles,
      )..where((t) => t.id.equals(cycle.id))).getSingleOrNull();
      if (existing != null) {
        throw StateError('Sterilisation cycle ${cycle.id} is append-only');
      }
      var row = cycle;
      if (cycle.cycleNumber.isEmpty) {
        final n = await nextCounter(ctx, SettingKeys.sterilisationCycleCounter);
        row = SterilisationCycle(
          id: cycle.id,
          clinicId: cycle.clinicId,
          cycleNumber: 'SC-${n.toString().padLeft(5, '0')}',
          autoclaveName: cycle.autoclaveName,
          cycledAt: cycle.cycledAt,
          cycleType: cycle.cycleType,
          temperatureC: cycle.temperatureC,
          pressureKpa: cycle.pressureKpa,
          durationMinutes: cycle.durationMinutes,
          chemicalIndicatorPassed: cycle.chemicalIndicatorPassed,
          biologicalIndicatorResult: cycle.biologicalIndicatorResult,
          loadContents: cycle.loadContents,
          operatorId: cycle.operatorId,
          note: cycle.note,
          createdAt: cycle.createdAt,
        );
      }
      return audited<SterilisationCycle>(
        ctx: ctx,
        table: _cycles,
        entityType: 'SterilisationCycle',
        entityId: row.id,
        before: null,
        after: row,
        insertable: row.toInsertable(),
        toJson: (c) => c.toJson(),
      );
    });
  }

  @override
  Future<List<SterilisationCycle>> cycles(
    String clinicId, {
    DateTime? from,
    DateTime? to,
  }) =>
      (select(_cycles)
            ..where((t) {
              var where = t.clinicId.equals(clinicId);
              if (from != null) {
                where =
                    where & t.cycledAt.isBiggerOrEqualValue(encodeIsoUtc(from));
              }
              if (to != null) {
                where = where & t.cycledAt.isSmallerThanValue(encodeIsoUtc(to));
              }
              return where;
            })
            ..orderBy([(t) => OrderingTerm.desc(t.cycledAt)]))
          .get();

  @override
  Stream<List<SterilisationCycle>> watchRecentCycles(
    String clinicId, {
    int limit = 50,
  }) =>
      (select(_cycles)
            ..where((t) => t.clinicId.equals(clinicId))
            ..orderBy([(t) => OrderingTerm.desc(t.cycledAt)])
            ..limit(limit))
          .watch();

  @override
  Future<Licence> upsertLicence(ActorContext ctx, Licence licence) {
    checkTenant(ctx, licence.clinicId, 'licence.clinicId');
    return writeTransaction(
      () async => audited(
        ctx: ctx,
        table: _licences,
        entityType: 'Licence',
        entityId: licence.id,
        before: await (select(
          _licences,
        )..where((t) => t.id.equals(licence.id))).getSingleOrNull(),
        after: licence,
        insertable: licence.toInsertable(),
        toJson: (l) => l.toJson(),
      ),
    );
  }

  SimpleSelectStatement<$LicencesTable, Licence> _licenceQuery(
    String clinicId,
  ) => select(_licences)
    ..where((t) => t.clinicId.equals(clinicId))
    ..orderBy([(t) => OrderingTerm.asc(t.expiresAt)]);

  @override
  Future<List<Licence>> licences(String clinicId) =>
      _licenceQuery(clinicId).get();

  @override
  Stream<List<Licence>> watchLicences(String clinicId) =>
      _licenceQuery(clinicId).watch();

  @override
  Future<List<Licence>> expiringSoon(
    String clinicId, {
    DateTime? asOf,
    int withinDays = 60,
  }) async {
    final now = nowUtc(asOf);
    final horizon = now.add(Duration(days: withinDays));
    DateTime? nextDue(Licence l) {
      final dates = [l.expiresAt, l.qaDueAt].whereType<DateTime>().toList();
      if (dates.isEmpty) return null;
      dates.sort();
      return dates.first;
    }

    final soon = (await licences(clinicId)).where((l) {
      final due = nextDue(l);
      return due != null && !due.isAfter(horizon);
    }).toList();
    soon.sort((a, b) => nextDue(a)!.compareTo(nextDue(b)!));
    return soon;
  }
}
