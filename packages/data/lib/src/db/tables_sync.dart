/// Sync bookkeeping that never leaves the device: per-table pull watermarks,
/// the device id, the clinic this device is linked to and the last sync
/// times. Keyed rows rather than typed columns so a new piece of state is a
/// new key, not a schema migration.
library;

import 'package:drift/drift.dart';

import 'converters.dart';

/// Key/value sync state (`sync_state`). Well-known keys are the constants on
/// `SyncStateKeys` in `sync/sync_state_repository.dart`.
@DataClassName('SyncStateRow')
class SyncStates extends Table {
  @override
  String get tableName => 'sync_state';

  /// State key (`watermark.<table>`, `device_id`, ...).
  TextColumn get stateKey => text()();

  /// Value; JSON text for structured entries, plain text otherwise.
  TextColumn get value => text().nullable()();

  /// Last write time.
  TextColumn get updatedAt => text().map(const IsoUtcDateTimeConverter())();

  @override
  Set<Column> get primaryKey => {stateKey};
}
