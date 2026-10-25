import 'dart:io';

import 'package:ampdent_data/ampdent_data.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

/// Tables that exist on one side only, each with the reason. Nothing else
/// may differ: the sync outbox targets Drift table names, so every table it
/// can name must exist on the server.
const Set<String> localOnlyTables = {
  // Per-device upload queue; it is the transport, never replicated.
  'sync_outbox',
  // Query index flattened from perio_exams.sites (the JSON column is the
  // source of truth); rebuilt locally, never written to the outbox.
  'perio_site_readings',
  // Per-device pull watermarks, device id and clinic link.
  'sync_state',
};
const Set<String> serverOnlyTables = {
  // One row per auth user (display data), not a tenant table.
  'profiles',
  // Server-side GST rate history for reporting; the device keeps the same
  // rows in the `gst.rates` setting and the server mirrors it on sync.
  'gst_rates',
  // Device registry (0008): one row per install, written by the app through
  // its own RPC, not replicated into the local store.
  'devices',
  // Per-clinic WhatsApp credentials (0008): server-side only, token in Vault.
  'clinic_whatsapp_configs',
};

void main() {
  final migrations = Directory('../../supabase/migrations');

  /// `create table public.<name>` across every migration (schema `app`
  /// tables are internal counters and are excluded on purpose).
  Set<String> sqlTables() {
    final pattern = RegExp(
      r'create\s+table\s+(?:if\s+not\s+exists\s+)?public\.(\w+)',
      caseSensitive: false,
    );
    final files =
        migrations
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.sql'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    expect(files, isNotEmpty, reason: 'no migrations found at $migrations');
    return {
      for (final f in files)
        for (final m in pattern.allMatches(f.readAsStringSync())) m.group(1)!,
    };
  }

  test('every Drift table exists in the SQL migrations and vice versa', () {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = AppDatabase.inMemory(seedOnOpen: false);
    addTearDown(db.close);
    final drift = db.allTables.map((t) => t.actualTableName).toSet();
    final sql = sqlTables();

    final missingOnServer = drift.difference(sql).difference(localOnlyTables);
    expect(
      missingOnServer,
      isEmpty,
      reason:
          'Drift tables with no server table (outbox rows would have no '
          'target): $missingOnServer',
    );
    final missingLocally = sql.difference(drift).difference(serverOnlyTables);
    expect(
      missingLocally,
      isEmpty,
      reason: 'server tables with no Drift table: $missingLocally',
    );
    // The exception lists must stay honest.
    expect(localOnlyTables.difference(drift), isEmpty);
    expect(serverOnlyTables.difference(sql), isEmpty);
    expect(drift.intersection(sql), contains('settings'));
  });

  test('renamed and added columns are present server-side', () {
    final all = migrations
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))
        .map((f) => f.readAsStringSync())
        .join('\n');
    // Dart is the contract: drift names reminder24hSentAt
    // `reminder24h_sent_at`, not `reminder_24h_sent_at`.
    expect(all, contains('reminder24h_sent_at'));
    expect(all, contains('rename column reminder_24h_sent_at'));
    expect(all, contains('removed_at'));
    expect(all, contains('bpe_furcation'));
    // Drift schema v4.
    expect(all, contains('plan_version'));
    expect(all, contains('plan_snapshot_hash'));
    expect(all, contains('estimate_declined_reason'));
    expect(all, contains('patient_snapshot'));
    expect(all, contains('drugs_clinic_id_idx'));
  });
}
