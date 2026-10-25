import 'package:ampdent_core/ampdent_core.dart';
import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../../db/settings_codec.dart';
import '../../seed/seeder.dart';
import '../actor_context.dart';
import '../clinic_repository.dart';
import 'audited_writer.dart';
import 'settings_access.dart';

/// Drift implementation of [ClinicRepository].
class DriftClinicRepository extends DatabaseAccessor<AppDatabase>
    with AuditedWriter, SettingsAccess
    implements ClinicRepository {
  /// Creates the repository over [db].
  DriftClinicRepository(super.db);

  $ClinicsTable get _clinics => attachedDatabase.clinics;
  $ChairsTable get _chairs => attachedDatabase.chairs;
  $ClinicMembersTable get _members => attachedDatabase.clinicMembers;

  @override
  Future<Clinic?> getClinic(String clinicId) =>
      (select(_clinics)..where((t) => t.id.equals(clinicId))).getSingleOrNull();

  @override
  Stream<Clinic?> watchClinic(String clinicId) => (select(
    _clinics,
  )..where((t) => t.id.equals(clinicId))).watchSingleOrNull();

  @override
  Future<Clinic> createClinic(ActorContext ctx, Clinic clinic) {
    if (ctx.clinicId != clinic.id) {
      throw ArgumentError.value(
        clinic.id,
        'clinic.id',
        'must equal the actor clinic id',
      );
    }
    return writeTransaction(() async {
      final before = await getClinic(clinic.id);
      if (before != null) {
        throw StateError('Clinic ${clinic.id} already exists');
      }
      await into(_clinics).insert(clinic.toInsertable());
      await Seeder(attachedDatabase).seedClinicDefaults(ctx, clinic);
      await recordWrite(
        ctx: ctx,
        action: AuditAction.create,
        entityType: 'Clinic',
        entityId: clinic.id,
        table: _clinics,
        after: clinic.toJson(),
      );
      return clinic;
    });
  }

  @override
  Future<Clinic> updateClinic(ActorContext ctx, Clinic clinic) {
    checkTenant(ctx, clinic.id, 'clinic.id');
    return writeTransaction(() async {
      final before = await getClinic(clinic.id);
      if (before == null) throw StateError('Clinic ${clinic.id} not found');
      return audited(
        ctx: ctx,
        table: _clinics,
        entityType: 'Clinic',
        entityId: clinic.id,
        before: before,
        after: clinic,
        insertable: clinic.toInsertable(),
        toJson: (c) => c.toJson(),
      );
    });
  }

  SimpleSelectStatement<$ChairsTable, Chair> _chairQuery(
    String clinicId,
    bool includeInactive,
  ) => select(_chairs)
    ..where(
      (t) =>
          t.clinicId.equals(clinicId) &
          (includeInactive ? const Constant(true) : t.isActive.equals(true)),
    )
    ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);

  @override
  Future<List<Chair>> chairs(String clinicId, {bool includeInactive = false}) =>
      _chairQuery(clinicId, includeInactive).get();

  @override
  Stream<List<Chair>> watchChairs(
    String clinicId, {
    bool includeInactive = false,
  }) => _chairQuery(clinicId, includeInactive).watch();

  Future<Chair?> _chair(String id) =>
      (select(_chairs)..where((t) => t.id.equals(id))).getSingleOrNull();

  @override
  Future<Chair> upsertChair(ActorContext ctx, Chair chair) {
    checkTenant(ctx, chair.clinicId, 'chair.clinicId');
    return writeTransaction(
      () async => audited(
        ctx: ctx,
        table: _chairs,
        entityType: 'Chair',
        entityId: chair.id,
        before: await _chair(chair.id),
        after: chair,
        insertable: chair.toInsertable(),
        toJson: (c) => c.toJson(),
      ),
    );
  }

  @override
  Future<Chair> deactivateChair(ActorContext ctx, String chairId) =>
      writeTransaction(() async {
        final before = await _chair(chairId);
        if (before == null) throw StateError('Chair $chairId not found');
        checkTenant(ctx, before.clinicId, 'chair.clinicId');
        final after = before.copyWith(isActive: false);
        return audited(
          ctx: ctx,
          table: _chairs,
          entityType: 'Chair',
          entityId: chairId,
          before: before,
          after: after,
          insertable: after.toInsertable(),
          toJson: (c) => c.toJson(),
          action: AuditAction.softDelete,
        );
      });

  SimpleSelectStatement<$ClinicMembersTable, ClinicMember> _memberQuery(
    String clinicId,
    bool includeInactive,
  ) => select(_members)
    ..where(
      (t) =>
          t.clinicId.equals(clinicId) &
          (includeInactive ? const Constant(true) : t.isActive.equals(true)),
    )
    ..orderBy([(t) => OrderingTerm.asc(t.displayName)]);

  @override
  Future<List<ClinicMember>> members(
    String clinicId, {
    bool includeInactive = false,
  }) => _memberQuery(clinicId, includeInactive).get();

  @override
  Stream<List<ClinicMember>> watchMembers(
    String clinicId, {
    bool includeInactive = false,
  }) => _memberQuery(clinicId, includeInactive).watch();

  @override
  Future<ClinicMember?> getMember(String memberId) =>
      (select(_members)..where((t) => t.id.equals(memberId))).getSingleOrNull();

  @override
  Future<ClinicMember> upsertMember(ActorContext ctx, ClinicMember member) {
    checkTenant(ctx, member.clinicId, 'member.clinicId');
    return writeTransaction(
      () async => audited(
        ctx: ctx,
        table: _members,
        entityType: 'ClinicMember',
        entityId: member.id,
        before: await getMember(member.id),
        after: member,
        insertable: member.toInsertable(),
        toJson: (m) => m.toJson(),
      ),
    );
  }

  @override
  Future<ClinicMember> deactivateMember(
    ActorContext ctx,
    String memberId, {
    String? reason,
  }) => writeTransaction(() async {
    final before = await getMember(memberId);
    if (before == null) throw StateError('Member $memberId not found');
    checkTenant(ctx, before.clinicId, 'member.clinicId');
    final after = before.copyWith(isActive: false, updatedAt: nowUtc());
    return audited(
      ctx: ctx,
      table: _members,
      entityType: 'ClinicMember',
      entityId: memberId,
      before: before,
      after: after,
      insertable: after.toInsertable(),
      toJson: (m) => m.toJson(),
      action: AuditAction.softDelete,
      reason: reason,
    );
  });

  @override
  Future<String?> getSetting(String clinicId, String key) =>
      readSetting(clinicId, key);

  @override
  Future<void> setSetting(ActorContext ctx, String key, String valueJson) =>
      writeSetting(ctx, key, valueJson);

  @override
  Future<List<GstRate>> loadGstRates(String clinicId) async {
    final json = await readSetting(clinicId, SettingKeys.gstRates);
    return json == null ? const [] : gstRatesFromJson(json);
  }

  @override
  Future<void> saveGstRates(ActorContext ctx, List<GstRate> rates) =>
      writeSetting(ctx, SettingKeys.gstRates, gstRatesToJson(rates));

  @override
  Future<ToothNotation> loadNotation(String clinicId) async =>
      enumSettingFromJson(
        ToothNotation.values,
        await readSetting(clinicId, SettingKeys.notation),
        ToothNotation.fdi,
      );

  @override
  Future<void> saveNotation(ActorContext ctx, ToothNotation notation) =>
      writeSetting(ctx, SettingKeys.notation, enumSettingToJson(notation));

  @override
  Future<String> nextPatientNumber(ActorContext ctx) => mintPatientNumber(ctx);

  @override
  Future<String> nextDraftInvoiceNumber(ActorContext ctx, {DateTime? now}) =>
      mintLocalDraftNumber(ctx, 'INV', now: now);

  @override
  Future<String> nextDraftEstimateNumber(ActorContext ctx, {DateTime? now}) =>
      mintLocalDraftNumber(ctx, 'EST', now: now);
}
