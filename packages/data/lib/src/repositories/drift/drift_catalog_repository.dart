import 'package:ampdent_core/ampdent_core.dart';
import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../../seed/seeder.dart';
import '../actor_context.dart';
import '../catalog_repository.dart';
import 'audited_writer.dart';

/// Drift implementation of [CatalogRepository].
class DriftCatalogRepository extends DatabaseAccessor<AppDatabase>
    with AuditedWriter
    implements CatalogRepository {
  /// Creates the repository over [db].
  DriftCatalogRepository(super.db);

  $CatalogItemsTable get _t => attachedDatabase.catalogItems;

  @override
  Future<int> seedGlobalIfEmpty() async =>
      (await Seeder(attachedDatabase).seedGlobal()).catalogItemsInserted;

  @override
  Future<List<CatalogItem>> globalItems() =>
      (select(_t)
            ..where((t) => t.clinicId.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  SimpleSelectStatement<$CatalogItemsTable, CatalogItem> _scopeQuery(
    String clinicId,
  ) =>
      select(_t)
        ..where((t) => t.clinicId.isNull() | t.clinicId.equals(clinicId));

  /// Merges clinic rows over global rows by code, filters and sorts.
  List<CatalogItem> _merge(
    List<CatalogItem> rows,
    String clinicId, {
    bool includeInactive = false,
  }) {
    final byCode = <String, CatalogItem>{};
    for (final r in rows.where((r) => r.clinicId == null)) {
      byCode[r.code] = r;
    }
    for (final r in rows.where((r) => r.clinicId == clinicId)) {
      byCode[r.code] = r;
    }
    final out = byCode.values
        .where((i) => includeInactive || i.isActive)
        .toList();
    out.sort((a, b) {
      final c = a.category.index.compareTo(b.category.index);
      if (c != 0) return c;
      final s = a.sortOrder.compareTo(b.sortOrder);
      return s != 0 ? s : a.code.compareTo(b.code);
    });
    return out;
  }

  @override
  Future<List<CatalogItem>> itemsForClinic(
    String clinicId, {
    bool includeInactive = false,
  }) async => _merge(
    await _scopeQuery(clinicId).get(),
    clinicId,
    includeInactive: includeInactive,
  );

  @override
  Stream<List<CatalogItem>> watchForClinic(String clinicId) =>
      _scopeQuery(clinicId).watch().map((rows) => _merge(rows, clinicId));

  @override
  Future<CatalogItem?> getById(String id) =>
      (select(_t)..where((t) => t.id.equals(id))).getSingleOrNull();

  @override
  Future<CatalogItem?> byCode(String clinicId, String code) async {
    final rows =
        await (select(_t)..where(
              (t) =>
                  t.code.equals(code) &
                  (t.clinicId.isNull() | t.clinicId.equals(clinicId)),
            ))
            .get();
    if (rows.isEmpty) return null;
    for (final r in rows) {
      if (r.clinicId == clinicId) return r;
    }
    return rows.first;
  }

  @override
  Future<CatalogItem> saveClinicItem(ActorContext ctx, CatalogItem item) {
    if (item.clinicId == null) {
      throw ArgumentError.value(
        item.clinicId,
        'item.clinicId',
        'clinic items must carry the clinic id; global rows are seed-only',
      );
    }
    checkTenant(ctx, item.clinicId, 'item.clinicId');
    return writeTransaction(
      () async => audited(
        ctx: ctx,
        table: _t,
        entityType: 'CatalogItem',
        entityId: item.id,
        before: await getById(item.id),
        after: item,
        insertable: item.toInsertable(),
        toJson: (i) => i.toJson(),
      ),
    );
  }

  @override
  Future<CatalogItem> deactivate(ActorContext ctx, String id) =>
      writeTransaction(() async {
        final before = await getById(id);
        if (before == null) throw StateError('Catalog item $id not found');
        if (before.clinicId == null) {
          // Hide a global item for this clinic by writing an inactive override.
          final override = before.copyWith(
            clinicId: ctx.clinicId,
            isActive: false,
          );
          final row = CatalogItem(
            id: newId(),
            clinicId: ctx.clinicId,
            code: override.code,
            name: override.name,
            laymanName: override.laymanName,
            category: override.category,
            treatmentArea: override.treatmentArea,
            defaultFee: override.defaultFee,
            feeMin: override.feeMin,
            feeMax: override.feeMax,
            gstClass: override.gstClass,
            sacHsnCode: override.sacHsnCode,
            durationMinutes: override.durationMinutes,
            stages: override.stages,
            recallInterval: override.recallInterval,
            consentTemplateCode: override.consentTemplateCode,
            requiresPreOpRadiograph: override.requiresPreOpRadiograph,
            externalCodes: override.externalCodes,
            isActive: false,
            sortOrder: override.sortOrder,
          );
          return audited<CatalogItem>(
            ctx: ctx,
            table: _t,
            entityType: 'CatalogItem',
            entityId: row.id,
            before: null,
            after: row,
            insertable: row.toInsertable(),
            toJson: (i) => i.toJson(),
            action: AuditAction.softDelete,
            reason: 'hide global item ${before.code}',
          );
        }
        checkTenant(ctx, before.clinicId, 'item.clinicId');
        final after = before.copyWith(isActive: false);
        return audited(
          ctx: ctx,
          table: _t,
          entityType: 'CatalogItem',
          entityId: id,
          before: before,
          after: after,
          insertable: after.toInsertable(),
          toJson: (i) => i.toJson(),
          action: AuditAction.softDelete,
        );
      });

  @override
  Future<List<CatalogItem>> search(
    String clinicId,
    String query, {
    ProcedureCategory? category,
    int limit = 50,
  }) async {
    final q = query.trim().toLowerCase();
    final items = await itemsForClinic(clinicId);
    return items
        .where((i) => category == null || i.category == category)
        .where(
          (i) =>
              q.isEmpty ||
              i.code.toLowerCase().contains(q) ||
              i.name.toLowerCase().contains(q) ||
              i.laymanName.toLowerCase().contains(q),
        )
        .take(limit)
        .toList();
  }
}
