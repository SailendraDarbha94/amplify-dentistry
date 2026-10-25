import 'dart:io';

import 'package:ampdent_data/ampdent_data.dart';
// ignore: implementation_imports
import 'package:ampdent_data/src/db/app_database.dart';
import 'package:drift/drift.dart' show GeneratedColumn, driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart' show PostgrestException;

import 'sync_helpers.dart';

/// Columns of every `public.*` table in the migrations: `create table`
/// bodies, then `add column` / `rename column` in later files.
Map<String, Set<String>> sqlColumns() {
  final files =
      Directory('../../supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.sql'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final out = <String, Set<String>>{};
  final ident = RegExp(r'^[a-z_][a-z0-9_]*$');
  const skip = {'check', 'unique', 'primary', 'constraint', 'foreign'};
  for (final f in files) {
    final text = f.readAsStringSync();
    final create = RegExp(
      r'create\s+table\s+public\.(\w+)\s*\(([\s\S]*?)\n\);',
      caseSensitive: false,
    );
    for (final m in create.allMatches(text)) {
      final cols = out.putIfAbsent(m.group(1)!, () => {});
      for (final line in m.group(2)!.split('\n')) {
        final t = line.trim();
        if (t.isEmpty || t.startsWith('--')) continue;
        final first = t.split(RegExp(r'\s+')).first.replaceAll(',', '');
        if (skip.contains(first) || !ident.hasMatch(first)) continue;
        // Continuation lines of a check list start with a quote or paren.
        if (line.startsWith(RegExp(r'\s{20,}'))) continue;
        cols.add(first);
      }
    }
    final alter = RegExp(
      r'alter\s+table\s+public\.(\w+)\s+([\s\S]*?);',
      caseSensitive: false,
    );
    for (final m in alter.allMatches(text)) {
      final cols = out.putIfAbsent(m.group(1)!, () => {});
      final body = m.group(2)!;
      for (final a in RegExp(r'add\s+column\s+(\w+)').allMatches(body)) {
        cols.add(a.group(1)!);
      }
      for (final r in RegExp(
        r'rename\s+column\s+(\w+)\s+to\s+(\w+)',
      ).allMatches(body)) {
        cols.remove(r.group(1)!);
        cols.add(r.group(2)!);
      }
    }
  }
  return out;
}

void main() {
  group('push plan', () {
    test('covers every synced table once, parents first', () {
      final plan = buildPushPlan();
      final mains = plan.where((s) => !s.isFixup).map((s) => s.table.name);
      expect(mains.toList(), syncTableOrder);
      int pos(String t) => syncTableOrder.indexOf(t);
      expect(pos('clinics'), 0);
      expect(pos('clinic_members'), lessThan(pos('patients')));
      expect(pos('patients'), lessThan(pos('appointments')));
      expect(pos('appointments'), lessThan(pos('visits')));
      expect(pos('treatment_plans'), lessThan(pos('treatment_plan_lines')));
      expect(pos('treatment_plan_lines'), lessThan(pos('procedures')));
      expect(pos('procedures'), lessThan(pos('lab_cases')));
      expect(pos('procedures'), lessThan(pos('tooth_state_records')));
      expect(pos('invoices'), lessThan(pos('payments')));
      expect(pos('labs'), lessThan(pos('lab_cases')));
      expect(pos('catalog_items'), lessThan(pos('treatment_plan_lines')));
    });

    test('fix-up steps follow their dependency and own the ack', () {
      final plan = buildPushPlan();
      final names = plan.map((s) => s.table.name).toList();
      final fixLines = plan.indexWhere(
        (s) => s.isFixup && s.table.name == 'treatment_plan_lines',
      );
      final fixProc = plan.indexWhere(
        (s) => s.isFixup && s.table.name == 'procedures',
      );
      expect(fixLines, greaterThan(names.indexOf('procedures')));
      expect(fixProc, greaterThan(names.indexOf('lab_cases')));
      expect(plan[fixLines].onlyColumns, {'procedure_id'});
      expect(plan[fixProc].onlyColumns, {'lab_case_id'});
      expect(plan[fixLines].isFinal, isTrue);
      expect(plan[fixProc].isFinal, isTrue);
      final mainProc = plan.indexWhere(
        (s) => !s.isFixup && s.table.name == 'procedures',
      );
      expect(plan[mainProc].isFinal, isFalse);
      expect(plan[mainProc].excludeColumns, {'lab_case_id'});
      expect(plan.where((s) => s.isFinal).length, syncTables.length);
    });

    test('policies match the architecture conflict table', () {
      const append = SyncConflictPolicy.appendOnly;
      const lww = SyncConflictPolicy.lastWriterWins;
      // Immutable on the server (no UPDATE policy, 0006) or a snapshot
      // (perio exams): the local copy is final.
      for (final t in [
        'tooth_state_records',
        'medical_histories',
        'perio_exams',
        'prescriptions',
        'consent_records',
        'payments',
        'ledger_entries',
        'sterilisation_cycles',
        'audit_events',
      ]) {
        expect(syncTablesByName[t]!.policy, append, reason: t);
      }
      // Every append-only table except the perio snapshot is pushed with
      // ignore-duplicates, since the server would refuse an UPDATE anyway.
      for (final t in syncTables.where((t) => t.policy == append)) {
        expect(
          t.ignoreDuplicatesOnPush,
          t.name != 'perio_exams' && t.name != 'audit_events',
          reason: t.name,
        );
      }
      // Rows that change through status transitions must propagate between
      // devices (a procedure completed on one phone, a withdrawn DPDP
      // consent, a signed note); the server still refuses row deletes.
      for (final t in [
        'procedures',
        'findings',
        'clinical_notes',
        'data_consents',
        'image_records',
        'implant_records',
        'adjustments',
      ]) {
        expect(syncTablesByName[t]!.policy, lww, reason: t);
      }
      // Delivery state is server-owned (0008), so message_logs is LWW.
      expect(syncTablesByName['message_logs']!.policy, lww);
      for (final t in [
        'patients',
        'appointments',
        'visits',
        'treatment_plans',
        'treatment_plan_lines',
        'estimates',
        'invoices',
        'recalls',
        'lab_cases',
        'licences',
        'clinics',
        'clinic_members',
        'chairs',
        'settings',
      ]) {
        expect(syncTablesByName[t]!.policy, lww, reason: t);
      }
      for (final t in fakeNoUpdateTables) {
        expect(syncTablesByName[t]!.ignoreDuplicatesOnPush, isTrue, reason: t);
      }
      expect(
        syncTablesByName['settings']!.rowIdOf({
          'clinic_id': 'c',
          'setting_key': 'k',
        }),
        'c:k',
      );
      expect(syncTablesByName['settings']!.splitRowId('c:gst.rates'), [
        'c',
        'gst.rates',
      ]);
    });
  });

  group('row codec', () {
    test('every local column exists on the server under its mapped name', () {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final db = AppDatabase.inMemory(seedOnOpen: false);
      addTearDown(db.close);
      final sql = sqlColumns();
      final missing = <String>[];
      for (final table in syncTables) {
        final info = db.allTables.firstWhere(
          (t) => t.actualTableName == table.name,
        );
        final serverCols = sql[table.name];
        expect(serverCols, isNotNull, reason: table.name);
        for (final c in info.$columns) {
          final name = SyncRowCodec.serverColumnName(c);
          if (!serverCols!.contains(name)) missing.add('${table.name}.$name');
        }
      }
      expect(missing, isEmpty, reason: 'local columns the server lacks');
      // 0008 adds updated_at to every public table dynamically (audit_events
      // had none), so the pull cursor exists everywhere.
      final all = Directory('../../supabase/migrations')
          .listSync()
          .whereType<File>()
          .map((f) => f.readAsStringSync())
          .join('\n');
      expect(
        all,
        contains('add column updated_at timestamptz not null default now()'),
      );
    });

    test('classifies columns from Drift metadata', () {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final db = AppDatabase.inMemory(seedOnOpen: false);
      addTearDown(db.close);
      final codec = SyncRowCodec(db.patients);
      GeneratedColumn<Object> col(String n) =>
          codec.columns.firstWhere((c) => c.$name == n);
      expect(codec.isJsonColumn(col('tags')), isTrue);
      expect(codec.isJsonColumn(col('address_lines')), isTrue);
      expect(codec.isJsonColumn(col('sex')), isFalse, reason: 'enum name');
      expect(codec.isJsonColumn(col('first_name')), isFalse);
      expect(SyncRowCodec.isDateColumn(col('date_of_birth')), isTrue);
      expect(SyncRowCodec.isDateColumn(col('first_name')), isFalse);
      expect(codec.hasUpdatedAt, isTrue);
      final inv = SyncRowCodec(db.invoices);
      expect(
        SyncRowCodec.serverColumnName(
          inv.columns.firstWhere((c) => c.$name == 'subtotal'),
        ),
        'subtotal_paise',
      );
      expect(
        inv.isJsonColumn(inv.columns.firstWhere((c) => c.$name == 'lines')),
        isTrue,
      );
      final proc = SyncRowCodec(db.procedures);
      expect(
        proc.isJsonColumn(proc.columns.firstWhere((c) => c.$name == 'teeth')),
        isTrue,
      );
      expect(
        proc.isJsonColumn(proc.columns.firstWhere((c) => c.$name == 'tooth')),
        isFalse,
      );
      expect(
        proc.isJsonColumn(
          proc.columns.firstWhere((c) => c.$name == 'surfaces'),
        ),
        isFalse,
      );
      final settings = SyncRowCodec(
        db.settings,
        jsonTextColumns: {'value_json'},
      );
      expect(
        settings.isJsonColumn(
          settings.columns.firstWhere((c) => c.$name == 'value_json'),
        ),
        isTrue,
      );
      expect(SyncRowCodec(db.chairs).hasUpdatedAt, isFalse);
    });

    test('round-trips a row through the server shape', () async {
      final s = await SyncTestEnv.open(withPatient: false);
      addTearDown(s.close);
      final codec = SyncRowCodec(s.db.patients);
      final local = s.sqlRow(patient().toInsertable());
      final server = codec.toServer(local);
      expect(server['is_active'], isTrue);
      expect(server['tags'], ['vip']);
      expect(server.containsKey('updated_at'), isFalse);
      server['updated_at'] = '2026-10-18T09:00:00.000000+00:00';
      server['approx_age_years'] = 36;
      final back = codec.fromServer(server);
      expect(back['is_active'], 1);
      expect(back['tags'], '["vip"]');
      expect(back['approx_age_years'], 36.0);
      expect(back['updated_at'], '2026-10-18T09:00:00.000Z');
      final expected = {...local}..remove('updated_at');
      final actual = {...back}..remove('updated_at');
      expect(actual, expected);
    });

    test('jsonb settings values come back as JSON text, strings included', () {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final db = AppDatabase.inMemory(seedOnOpen: false);
      addTearDown(db.close);
      final codec = SyncRowCodec(db.settings, jsonTextColumns: {'value_json'});
      // PostgREST hands a jsonb string back as a Dart String; locally the
      // column holds JSON text, so `"palmer"` must not land as `palmer`.
      expect(
        codec.fromServer({'value_json': 'palmer'})['value_json'],
        '"palmer"',
      );
      expect(codec.fromServer({'value_json': 5})['value_json'], '5');
      expect(codec.fromServer({'value_json': true})['value_json'], 'true');
      expect(
        codec.fromServer({
          'value_json': {'a': 1},
        })['value_json'],
        '{"a":1}',
      );
      expect(codec.fromServer({'value_json': null})['value_json'], isNull);
      // And the inverse: local JSON text is sent as the JSON value itself.
      expect(
        codec.toServer({'value_json': '"palmer"'})['value_json'],
        'palmer',
      );
      expect(codec.toServer({'value_json': '{"a":1}'})['value_json'], {'a': 1});
    });

    test('timestamp normalisation', () {
      expect(
        normaliseServerTimestamp('2026-10-18T09:30:00.123456+00:00'),
        '2026-10-18T09:30:00.123Z',
      );
      expect(
        normaliseServerTimestamp('2026-10-18T15:00:00+05:30'),
        '2026-10-18T09:30:00.000Z',
      );
      expect(
        normaliseServerTimestamp('1990-05-20'),
        '1990-05-20T00:00:00.000Z',
      );
      expect(parseInstant('2026-10-18T09:30:00.123456+00:00').microsecond, 456);
    });
  });

  group('sync state', () {
    test('watermarks round-trip, reset and report emptiness', () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final db = AppDatabase.inMemory(seedOnOpen: false);
      addTearDown(db.close);
      final repo = DriftSyncStateRepository(db);
      expect(await repo.hasNoWatermarks, isTrue);
      await repo.setWatermark(
        'patients',
        const SyncWatermark('t1', lastKey: 'a'),
      );
      final wm = (await repo.watermark('patients'))!;
      expect(wm.updatedAt, 't1');
      expect(wm.lastKey, 'a');
      expect(await repo.hasNoWatermarks, isFalse);
      await repo.resetWatermarks();
      expect(await repo.watermark('patients'), isNull);
      expect(await repo.hasNoWatermarks, isTrue);
      // Rows are never removed, only blanked.
      expect(await db.select(db.syncStates).get(), hasLength(1));
      await repo.writeInstant(
        SyncStateKeys.lastPushAt,
        DateTime.utc(2026, 1, 2),
      );
      expect(
        await repo.readInstant(SyncStateKeys.lastPushAt),
        DateTime.utc(2026, 1, 2),
      );
    });

    test('schema v5 migration creates sync_state', () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final db = AppDatabase.inMemory(seedOnOpen: false);
      addTearDown(db.close);
      expect(db.schemaVersion, 5);
      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'sync_state'",
          )
          .get();
      expect(rows, hasLength(1));
    });
  });

  group('errors', () {
    test('classification and backoff', () {
      final f500 = classifySyncError(
        const PostgrestException(message: 'x', code: '500'),
        table: 't',
      );
      expect(f500.isTransient, isTrue);
      expect(f500.message, 'PostgrestException 500 on t');
      final f403 = classifySyncError(
        const PostgrestException(message: 'x', code: '42501'),
        table: 't',
      );
      expect(f403.kind, SyncFailureKind.rejected);
      expect(
        classifySyncError(
          const PostgrestException(message: 'x', code: '429'),
          table: 't',
        ).isTransient,
        isTrue,
      );
      expect(
        classifySyncError(StateError('boom'), table: 't').isTransient,
        isTrue,
      );
      const policy = BackoffPolicy(
        initial: Duration(seconds: 1),
        max: Duration(seconds: 5),
      );
      expect(policy.delayFor(1), const Duration(seconds: 1));
      expect(policy.delayFor(2), const Duration(seconds: 2));
      expect(policy.delayFor(3), const Duration(seconds: 4));
      expect(policy.delayFor(4), const Duration(seconds: 5));
    });
  });
}
