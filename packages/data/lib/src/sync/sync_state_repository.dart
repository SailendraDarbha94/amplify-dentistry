/// Device-local sync bookkeeping in the `sync_state` table.
library;

import 'dart:convert';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// Keys of the `sync_state` table.
abstract final class SyncStateKeys {
  /// This device's id (UUID v4, minted on first use).
  static const String deviceId = 'device_id';

  /// Clinic id this device replicates (set by `RemoteClinicLinker`).
  static const String linkedClinicId = 'linked_clinic_id';

  /// Member id of the signed-in user in the linked clinic.
  static const String linkedMemberId = 'linked_member_id';

  /// How the link was made (`pushedLocal` or `adoptedRemote`).
  static const String linkMode = 'link_mode';

  /// When the link was made.
  static const String linkedAt = 'linked_at';

  /// Completion time of the last pull that started with no watermarks.
  static const String lastFullSyncAt = 'last_full_sync_at';

  /// Completion time of the last successful push.
  static const String lastPushAt = 'last_push_at';

  /// Completion time of the last successful pull.
  static const String lastPullAt = 'last_pull_at';

  /// Watermark key for [table].
  static String watermark(String table) => 'watermark.$table';

  /// Prefix shared by every watermark key.
  static const String watermarkPrefix = 'watermark.';
}

/// Keyset position of a table pull: the server `updated_at` text exactly as
/// returned (microsecond precision) and the order key of the last row.
class SyncWatermark {
  /// Creates a watermark.
  const SyncWatermark(this.updatedAt, {this.lastKey});

  /// Server `updated_at` of the last applied row, verbatim.
  final String updatedAt;

  /// Order key (`id` or `setting_key`) of the last applied row.
  final String? lastKey;

  /// JSON form.
  Map<String, Object?> toJson() => {'updatedAt': updatedAt, 'lastKey': lastKey};

  /// Parses [toJson].
  factory SyncWatermark.fromJson(Map<String, Object?> json) => SyncWatermark(
    json['updatedAt'] as String,
    lastKey: json['lastKey'] as String?,
  );

  @override
  String toString() => 'SyncWatermark($updatedAt, $lastKey)';
}

/// Reads and writes `sync_state`.
abstract class SyncStateRepository {
  /// Raw value under [key], or null.
  Future<String?> read(String key);

  /// Writes [value] under [key] (null clears it; the row stays).
  Future<void> write(String key, String? value);

  /// Pull watermark of [table], or null before the first full pull.
  Future<SyncWatermark?> watermark(String table);

  /// Stores (or clears) the watermark of [table].
  Future<void> setWatermark(String table, SyncWatermark? watermark);

  /// Clears every watermark so the next pull is a full one.
  Future<void> resetWatermarks();

  /// Whether no table has a watermark yet.
  Future<bool> get hasNoWatermarks;

  /// This device's id, minted and stored on first call.
  Future<String> ensureDeviceId();

  /// Clinic id this device is linked to, or null.
  Future<String?> linkedClinicId();

  /// Instant stored under [key], or null.
  Future<DateTime?> readInstant(String key);

  /// Stores an instant under [key].
  Future<void> writeInstant(String key, DateTime at);
}

/// Drift implementation of [SyncStateRepository].
class DriftSyncStateRepository extends DatabaseAccessor<AppDatabase>
    implements SyncStateRepository {
  /// Creates the repository over [db].
  DriftSyncStateRepository(super.db);

  $SyncStatesTable get _t => attachedDatabase.syncStates;

  @override
  Future<String?> read(String key) async {
    final row = await (select(
      _t,
    )..where((t) => t.stateKey.equals(key))).getSingleOrNull();
    return row?.value;
  }

  @override
  Future<void> write(String key, String? value) =>
      into(_t).insertOnConflictUpdate(
        SyncStatesCompanion.insert(
          stateKey: key,
          value: Value(value),
          updatedAt: DateTime.now().toUtc(),
        ),
      );

  @override
  Future<SyncWatermark?> watermark(String table) async {
    final raw = await read(SyncStateKeys.watermark(table));
    if (raw == null) return null;
    return SyncWatermark.fromJson(
      (jsonDecode(raw) as Map).cast<String, Object?>(),
    );
  }

  @override
  Future<void> setWatermark(String table, SyncWatermark? watermark) => write(
    SyncStateKeys.watermark(table),
    watermark == null ? null : jsonEncode(watermark.toJson()),
  );

  Future<List<SyncStateRow>> _watermarkRows() =>
      (select(_t)..where(
            (t) =>
                t.stateKey.like('${SyncStateKeys.watermarkPrefix}%') &
                t.value.isNotNull(),
          ))
          .get();

  @override
  Future<void> resetWatermarks() => transaction(() async {
    for (final row in await _watermarkRows()) {
      await write(row.stateKey, null);
    }
  });

  @override
  Future<bool> get hasNoWatermarks async => (await _watermarkRows()).isEmpty;

  @override
  Future<String> ensureDeviceId() => transaction(() async {
    final existing = await read(SyncStateKeys.deviceId);
    if (existing != null) return existing;
    final id = newId();
    await write(SyncStateKeys.deviceId, id);
    return id;
  });

  @override
  Future<String?> linkedClinicId() => read(SyncStateKeys.linkedClinicId);

  @override
  Future<DateTime?> readInstant(String key) async {
    final raw = await read(key);
    return raw == null ? null : DateTime.parse(raw).toUtc();
  }

  @override
  Future<void> writeInstant(String key, DateTime at) =>
      write(key, at.toUtc().toIso8601String());
}
