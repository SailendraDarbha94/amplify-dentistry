import 'package:ampdent_core/ampdent_core.dart';

import 'actor_context.dart';

/// Procedure catalogue: global seed rows (`clinicId == null`) plus per-clinic
/// overrides keyed by `code`. A clinic override replaces the global row with
/// the same code in every clinic-scoped query.
abstract class CatalogRepository {
  /// Seeds the global catalogue from `indianProcedureCatalogue` when the
  /// global scope is empty; returns the number of rows inserted.
  Future<int> seedGlobalIfEmpty();

  /// Global seed items, in catalogue order.
  Future<List<CatalogItem>> globalItems();

  /// Effective catalogue for a clinic: overrides merged over the global
  /// seed, inactive items excluded unless asked, ordered by category then
  /// sort order.
  Future<List<CatalogItem>> itemsForClinic(
    String clinicId, {
    bool includeInactive = false,
  });

  /// Stream of the effective catalogue for a clinic.
  Stream<List<CatalogItem>> watchForClinic(String clinicId);

  /// Item by id (global or clinic).
  Future<CatalogItem?> getById(String id);

  /// Effective item for a code in a clinic (override first, then global).
  Future<CatalogItem?> byCode(String clinicId, String code);

  /// Saves a clinic-scoped item (override or clinic-only custom item).
  /// `item.clinicId` must equal the actor's clinic.
  Future<CatalogItem> saveClinicItem(ActorContext ctx, CatalogItem item);

  /// Marks a clinic item inactive (soft delete).
  Future<CatalogItem> deactivate(ActorContext ctx, String id);

  /// Case-insensitive search over code, name and layman name in the
  /// effective clinic catalogue.
  Future<List<CatalogItem>> search(
    String clinicId,
    String query, {
    ProcedureCategory? category,
    int limit = 50,
  });
}
