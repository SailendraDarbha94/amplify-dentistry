/// First-open seeding: the global procedure catalogue and drug master from
/// `ampdent_terminology`, and per-clinic defaults (GST rates, notation,
/// numbering counters) when a clinic is created. No demo data.
library;

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_terminology/ampdent_terminology.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../db/settings_codec.dart';
import '../repositories/actor_context.dart';

/// Counts of rows written by [Seeder.seedGlobal].
class SeedReport {
  /// Creates a report.
  const SeedReport({
    required this.catalogItemsInserted,
    required this.drugsInserted,
  });

  /// Global catalogue rows inserted.
  final int catalogItemsInserted;

  /// Drug master rows inserted.
  final int drugsInserted;

  /// Whether anything was written.
  bool get anyInserted => catalogItemsInserted > 0 || drugsInserted > 0;
}

/// Deterministic UUID v5 for a seed row so every device derives the same id
/// for the same catalogue code and sync merges them.
String seedId(String kind, String code) =>
    const Uuid().v5(Namespace.url.value, 'https://ampdent.in/seed/$kind/$code');

/// Maps a free-text drug-master form label onto [DrugForm].
DrugForm drugFormFromLabel(String label) {
  final l = label.trim().toLowerCase();
  for (final f in DrugForm.values) {
    if (f.name.toLowerCase() == l) return f;
  }
  if (l.contains('gargle') || l.contains('rinse')) return DrugForm.mouthwash;
  if (l.contains('suspension')) return DrugForm.suspension;
  if (l.contains('paste')) return DrugForm.paste;
  if (l.contains('gel')) return DrugForm.gel;
  if (l.contains('ointment') || l.contains('cream')) return DrugForm.ointment;
  if (l.contains('drop')) return DrugForm.drops;
  if (l.contains('syrup')) return DrugForm.syrup;
  if (l.contains('varnish')) return DrugForm.varnish;
  if (l.contains('inject')) return DrugForm.injection;
  if (l.contains('tab')) return DrugForm.tablet;
  if (l.contains('cap')) return DrugForm.capsule;
  return DrugForm.other;
}

/// Converts a terminology [ProcedureSeed] into a global [CatalogItem].
CatalogItem catalogItemFromSeed(ProcedureSeed seed, int sortOrder) =>
    CatalogItem(
      id: seedId('catalog', seed.code),
      code: seed.code,
      name: seed.name,
      laymanName: seed.laymanName,
      category: ProcedureCategory.values.byName(seed.category.name),
      treatmentArea: seed.treatmentArea,
      defaultFee: seed.defaultFee,
      feeMin: seed.feeMin,
      feeMax: seed.feeMax,
      gstClass: seed.gstClass,
      sacHsnCode: seed.sacHsnCode,
      durationMinutes: seed.durationMinutes,
      stages: seed.stages,
      recallInterval: seed.recallInterval,
      consentTemplateCode: seed.consentTemplateCode,
      requiresPreOpRadiograph: seed.requiresPreOpRadiograph,
      externalCodes: seed.snomedCode == null
          ? const {}
          : {'snomed': seed.snomedCode!},
      sortOrder: sortOrder,
    );

/// Converts a terminology [DrugSeed] into a [Drug].
Drug drugFromSeed(DrugSeed seed) => Drug(
  id: seedId('drug', seed.code),
  genericName: seed.genericName,
  brandNames: seed.brandNames,
  strength: seed.strength,
  form: drugFormFromLabel(seed.form),
  schedule: seed.schedule,
  scheduleEffectiveFrom: seed.scheduleEffectiveFrom,
  category: seed.category,
  defaultDose: seed.defaultDose,
  defaultFrequency: seed.defaultFrequency,
  defaultDurationDays: seed.defaultDurationDays,
  route: seed.route,
  allergyGroup: seed.allergyGroup,
  pregnancyCaution: seed.pregnancyCaution,
  pediatricCaution: seed.pediatricCaution,
);

/// Default Indian GST rate history written for every new clinic. Matches
/// `GstRateTable.indiaDefaults()` in `ampdent_core`, which does not expose
/// its rows: exempt healthcare 0%, cosmetic 18% with ITC, goods 5% from
/// 22 Sep 2025, standard 18%.
List<GstRate> defaultGstRates() {
  final epoch = DateTime.utc(2017, 7, 1);
  return [
    GstRate(
      gstClass: GstClass.exemptHealthcare,
      ratePercent: 0,
      inputTaxCreditAllowed: false,
      effectiveFrom: epoch,
    ),
    GstRate(
      gstClass: GstClass.cosmeticTaxable,
      ratePercent: 18,
      inputTaxCreditAllowed: true,
      effectiveFrom: epoch,
    ),
    GstRate(
      gstClass: GstClass.goods,
      ratePercent: 5,
      inputTaxCreditAllowed: true,
      effectiveFrom: DateTime.utc(2025, 9, 22),
    ),
    GstRate(
      gstClass: GstClass.standardTaxable,
      ratePercent: 18,
      inputTaxCreditAllowed: true,
      effectiveFrom: epoch,
    ),
  ];
}

/// Writes seed data. Global seeds are system writes (no actor, no audit, no
/// outbox: every device derives identical rows). Clinic defaults are written
/// inside the clinic-creation transaction by `ClinicRepository`.
class Seeder {
  /// Creates a seeder over [db].
  Seeder(this.db);

  /// Database to seed.
  final AppDatabase db;

  /// Seeds the global catalogue and drug master when each is empty.
  Future<SeedReport> seedGlobal() async {
    var catalogue = 0;
    var drugs = 0;
    await db.transaction(() async {
      final catalogCount = await _count(
        db.catalogItems,
        db.catalogItems.clinicId.isNull(),
      );
      if (catalogCount == 0) {
        final items = <CatalogItem>[];
        for (var i = 0; i < indianProcedureCatalogue.length; i++) {
          items.add(catalogItemFromSeed(indianProcedureCatalogue[i], i));
        }
        await db.batch((b) {
          b.insertAll(
            db.catalogItems,
            items.map((i) => i.toInsertable()),
            mode: InsertMode.insertOrIgnore,
          );
        });
        catalogue = items.length;
      }
      final drugCount = await _count(db.drugs, const Constant(true));
      if (drugCount == 0) {
        final rows = dentalDrugMaster.map(drugFromSeed).toList();
        await db.batch((b) {
          b.insertAll(
            db.drugs,
            rows.map((d) => d.toInsertable()),
            mode: InsertMode.insertOrIgnore,
          );
        });
        drugs = rows.length;
      }
    });
    return SeedReport(catalogItemsInserted: catalogue, drugsInserted: drugs);
  }

  /// Writes the default settings for a freshly created clinic: GST rate
  /// history, display notation, zeroed numbering counters and the creating
  /// device as the primary device. Existing keys are left untouched.
  Future<void> seedClinicDefaults(ActorContext ctx, Clinic clinic) async {
    final now = DateTime.now().toUtc();
    final defaults = <String, String>{
      SettingKeys.gstRates: gstRatesToJson(defaultGstRates()),
      SettingKeys.notation: enumSettingToJson(clinic.defaultNotation),
      SettingKeys.patientNumberCounter: counterToJson(0),
      SettingKeys.draftInvoiceCounter: counterToJson(0),
      SettingKeys.draftEstimateCounter: counterToJson(0),
      SettingKeys.sterilisationCycleCounter: counterToJson(0),
      SettingKeys.primaryDeviceId: stringSettingToJson(ctx.deviceId),
    };
    await db.batch((b) {
      for (final e in defaults.entries) {
        b.insert(
          db.settings,
          SettingsCompanion.insert(
            clinicId: ctx.clinicId,
            settingKey: e.key,
            valueJson: e.value,
            updatedAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  Future<int> _count(TableInfo table, Expression<bool> where) async {
    final count = countAll();
    final query = db.selectOnly(table)
      ..addColumns([count])
      ..where(where);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }
}
