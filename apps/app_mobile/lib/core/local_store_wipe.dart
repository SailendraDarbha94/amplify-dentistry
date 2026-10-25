/// Discards everything in the local store so an empty device can adopt a
/// server clinic. Only the device-local `sync_state` rows survive (device
/// id, "continue offline" choice); the clinic link and watermarks there are
/// cleared so the adopt starts clean. The global catalogue and drug master
/// are re-seeded.
///
/// This is the one place the app deletes rows. It is reachable only from
/// the sign-in conflict chooser after a destructive confirmation, and it
/// concerns data that has never left the device (the linker refuses to
/// adopt while an outbox is pending, so a synced clinic is never wiped).
library;

import 'package:ampdent_data/ampdent_data.dart';

/// Deletes every row of every table except `sync_state`, clears the link
/// and watermarks, and re-seeds the global catalogue.
Future<void> wipeLocalStore(AppDatabase db) async {
  await db.customStatement('PRAGMA foreign_keys = OFF');
  try {
    await db.transaction(() async {
      for (final table in db.allTables) {
        final name = table.actualTableName;
        if (name == 'sync_state') continue;
        await db.customUpdate('DELETE FROM "$name"', updates: {table});
      }
    });
  } finally {
    await db.customStatement('PRAGMA foreign_keys = ON');
  }
  final syncState = DriftSyncStateRepository(db);
  await syncState.resetWatermarks();
  await syncState.write(SyncStateKeys.linkedClinicId, null);
  await syncState.write(SyncStateKeys.linkedMemberId, null);
  await syncState.write(SyncStateKeys.linkMode, null);
  await syncState.write(SyncStateKeys.linkedAt, null);
  await syncState.write(SyncStateKeys.lastPushAt, null);
  await syncState.write(SyncStateKeys.lastPullAt, null);
  await syncState.write(SyncStateKeys.lastFullSyncAt, null);
  await Seeder(db).seedGlobal();
}
