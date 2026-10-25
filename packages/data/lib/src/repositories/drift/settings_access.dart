/// Per-clinic settings and numbering counters shared by several Drift
/// repositories.
///
/// Locally minted identifiers must not collide across a clinic's devices,
/// because the server enforces `unique (clinic_id, patient_number)` and
/// `unique (clinic_id, number)` on first sync. Draft document numbers carry
/// a four-character device code (`DRAFT-INV-202610-A3F9-0001`), and plain
/// `P-00001` patient numbers are minted only on the clinic's primary device
/// ([SettingKeys.primaryDeviceId]); every other device mints
/// `P-<code>-00001`. See packages/data/README.md, "Numbering".
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

  /// Four upper-case alphanumerics from the start of [deviceId] (device ids
  /// are UUID v4, so these are the first four hex digits), padded when the
  /// id is shorter.
  static String deviceCode(String deviceId) {
    final cleaned = deviceId
        .replaceAll(RegExp('[^A-Za-z0-9]'), '')
        .toUpperCase();
    return cleaned.padRight(4, '0').substring(0, 4);
  }

  /// Device id recorded as the clinic's primary device, or null when unset.
  Future<String?> primaryDeviceId(String clinicId) async =>
      stringSettingFromJson(
        await readSetting(clinicId, SettingKeys.primaryDeviceId),
      );

  /// Records [deviceId] as the clinic's primary device (audited).
  Future<void> setPrimaryDevice(ActorContext ctx, String deviceId) =>
      writeSetting(
        ctx,
        SettingKeys.primaryDeviceId,
        stringSettingToJson(deviceId),
      );

  /// Whether the actor's device is the clinic's primary device. When no
  /// primary is recorded yet (clinic created before the setting existed) the
  /// calling device claims the role so the clinic always has exactly one.
  Future<bool> isPrimaryDevice(ActorContext ctx) => writeTransaction(() async {
    final primary = await primaryDeviceId(ctx.clinicId);
    if (primary == null) {
      await setPrimaryDevice(ctx, ctx.deviceId);
      return true;
    }
    return primary == ctx.deviceId;
  });

  /// Mints the next patient number: `P-00001` on the primary device,
  /// `P-<code>-00001` elsewhere, each from its own counter.
  Future<String> mintPatientNumber(ActorContext ctx) =>
      writeTransaction(() async {
        if (await isPrimaryDevice(ctx)) {
          final n = await nextCounter(ctx, SettingKeys.patientNumberCounter);
          return 'P-${n.toString().padLeft(5, '0')}';
        }
        final code = deviceCode(ctx.deviceId);
        final n = await nextCounter(
          ctx,
          '${SettingKeys.patientNumberCounter}.$code',
        );
        return 'P-$code-${n.toString().padLeft(5, '0')}';
      });

  /// Mints the next local draft number for [prefix] (`INV` or `EST`):
  /// `DRAFT-INV-yyyyMM-<code>-0001`, from a per-device counter.
  Future<String> mintLocalDraftNumber(
    ActorContext ctx,
    String prefix, {
    DateTime? now,
  }) => writeTransaction(() async {
    final code = deviceCode(ctx.deviceId);
    final counterKey = switch (prefix) {
      'INV' => SettingKeys.draftInvoiceCounter,
      'EST' => SettingKeys.draftEstimateCounter,
      _ => 'counter.draft$prefix',
    };
    final n = await nextCounter(ctx, '$counterKey.$code');
    final at = nowUtc(now);
    final month = at.month.toString().padLeft(2, '0');
    return 'DRAFT-$prefix-${at.year}$month-$code-${n.toString().padLeft(4, '0')}';
  });

  /// Loads the clinic's GST rate history as a [GstRateTable], falling back to
  /// India defaults when the clinic has none configured.
  Future<GstRateTable> loadGstRateTable(String clinicId) async {
    final json = await readSetting(clinicId, SettingKeys.gstRates);
    if (json == null) return GstRateTable.indiaDefaults();
    return GstRateTable(gstRatesFromJson(json));
  }
}
