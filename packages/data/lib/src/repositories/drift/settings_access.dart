/// Per-clinic settings and numbering counters shared by several Drift
/// repositories.
library;

import 'package:ampdent_core/ampdent_core.dart';
import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../../db/settings_codec.dart';
import '../actor_context.dart';
import 'audited_writer.dart';

/// Reads and audits writes of `settings` rows and mints counter values.
mixin SettingsAccess on DatabaseAccessor<AppDatabase>, AuditedWriter {
  /// Raw JSON value of a setting, or null when unset.
  Future<String?> readSetting(String clinicId, String key) async {
    final row =
        await (select(attachedDatabase.settings)..where(
              (t) => t.clinicId.equals(clinicId) & t.settingKey.equals(key),
            ))
            .getSingleOrNull();
    return row?.valueJson;
  }

  /// Stream of a setting's raw JSON value.
  Stream<String?> watchSetting(String clinicId, String key) =>
      (select(attachedDatabase.settings)..where(
            (t) => t.clinicId.equals(clinicId) & t.settingKey.equals(key),
          ))
          .watchSingleOrNull()
          .map((r) => r?.valueJson);

  /// Writes a setting and audits it as a settings change.
  Future<void> writeSetting(
    ActorContext ctx,
    String key,
    String valueJson, {
    DateTime? at,
  }) => writeTransaction(() async {
    final before = await readSetting(ctx.clinicId, key);
    final now = nowUtc(at);
    await into(attachedDatabase.settings).insertOnConflictUpdate(
      SettingsCompanion.insert(
        clinicId: ctx.clinicId,
        settingKey: key,
        valueJson: valueJson,
        updatedAt: now,
      ),
    );
    await recordWrite(
      ctx: ctx,
      action: AuditAction.settingsChange,
      entityType: 'Setting',
      entityId: '${ctx.clinicId}:$key',
      table: attachedDatabase.settings,
      before: before == null ? null : {'key': key, 'value': before},
      after: {'key': key, 'value': valueJson},
    );
  });

  /// Increments the counter stored under [key] and returns the new value.
  /// Counters are not audited individually (the document that consumed the
  /// number is), but the settings row is updated in the same transaction.
  Future<int> nextCounter(ActorContext ctx, String key) =>
      writeTransaction(() async {
        final next = counterFromJson(await readSetting(ctx.clinicId, key)) + 1;
        await into(attachedDatabase.settings).insertOnConflictUpdate(
          SettingsCompanion.insert(
            clinicId: ctx.clinicId,
            settingKey: key,
            valueJson: counterToJson(next),
            updatedAt: nowUtc(),
          ),
        );
        return next;
      });

  /// Loads the clinic's GST rate history as a [GstRateTable], falling back to
  /// India defaults when the clinic has none configured.
  Future<GstRateTable> loadGstRateTable(String clinicId) async {
    final json = await readSetting(clinicId, SettingKeys.gstRates);
    if (json == null) return GstRateTable.indiaDefaults();
    return GstRateTable(gstRatesFromJson(json));
  }
}
