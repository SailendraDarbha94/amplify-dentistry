import 'package:ampdent_data/ampdent_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sync_helpers.dart';

void main() {
  late SyncTestEnv s;

  setUp(() async => s = await SyncTestEnv.open());
  tearDown(() => s.close());

  group('push', () {
    test('drains the outbox in foreign-key order and acks on 2xx', () async {
      await s.repos.appointments.upsert(ctx, appointment());
      expect(await s.pendingCount(), greaterThan(0));
      final engine = s.engine();
      await engine.pushPending();
      expect(engine.current.status, SyncStatus.idle);
      expect(engine.current.error, isNull);
      expect(await s.pendingCount(), 0);
      final order = s.fake.requests.map((r) => r.table).toList();
      expect(
        order,
        containsAllInOrder([
          'clinics',
          'clinic_members',
          'patients',
          'appointments',
        ]),
      );
      // Every request's table sits at a non-decreasing plan position.
      final positions = order.map(syncTableOrder.indexOf).toList();
      for (var i = 1; i < positions.length; i++) {
        expect(positions[i], greaterThanOrEqualTo(positions[i - 1]));
      }
      expect(s.fake.rows('patients'), hasLength(1));
      expect(s.fake.rows('appointments'), hasLength(1));
      expect(engine.lastPushReport!.entriesAcked, greaterThan(0));
    });

    test('maps rows to the server schema', () async {
      final engine = s.engine();
      await engine.pushPending();
      final req = s.fake.requestsFor('patients').single;
      expect(req.query['on_conflict'], 'id');
      expect(req.prefer, contains('merge-duplicates'));
      expect(req.prefer, contains('missing=default'));
      final row = req.rows.single;
      expect(row['id'], patientId);
      expect(row['first_name'], 'Anil');
      expect(row['address_lines'], ['4 Park Lane']);
      expect(row['tags'], ['vip']);
      expect(row['is_active'], isTrue);
      expect(row['date_of_birth'], '1990-05-20T00:00:00.000Z');
      expect(row.containsKey('updated_at'), isFalse);
      expect(row['created_at'], '2026-10-18T09:00:00.000Z');
      // Server assigns updated_at.
      expect(s.fake.row('patients', patientId)!['updated_at'], isNotNull);
    });

    test('money columns carry the _paise suffix', () async {
      await s.repos.billing.saveDraft(ctx, draftInvoice());
      await s.engine().pushPending();
      final row = s.fake.requestsFor('invoices').single.rows.single;
      expect(row['subtotal_paise'], 1500000);
      expect(row['grand_total_paise'], isA<int>());
      expect(row.containsKey('subtotal'), isFalse);
      expect(row['lines'], isA<List>());
      expect(row['number'], startsWith('DRAFT-'));
    });

    test('batches 200 rows per request', () async {
      for (var i = 0; i < 450; i++) {
        await s.repos.patients.upsert(
          ctx,
          patient(
            id: 'p-$i',
            number: 'P-${i + 10}',
            phone: '9${i.toString().padLeft(9, '0')}',
          ),
        );
      }
      await s.engine().pushPending();
      final sizes = s.fake.requestsFor('patients').map((r) => r.rows.length);
      expect(sizes, [200, 200, 51]);
      expect(s.fake.rows('patients'), hasLength(451));
      expect(await s.pendingCount(), 0);
    });

    test('repeated writes of one row send its latest state once', () async {
      final p = patient();
      await s.repos.patients.upsert(ctx, p.copyWith(firstName: 'Second'));
      await s.repos.patients.upsert(ctx, p.copyWith(firstName: 'Third'));
      await s.engine().pushPending();
      final rows = s.fake.requestsFor('patients').single.rows;
      expect(rows, hasLength(1));
      expect(rows.single['first_name'], 'Third');
      expect(await s.pendingCount(), 0);
    });

    test('settings use the composite key and jsonb value', () async {
      await s.repos.clinics.setSetting(ctx, SettingKeys.notation, '"palmer"');
      await s.engine().pushPending();
      final req = s.fake.requestsFor('settings').single;
      expect(req.query['on_conflict'], 'clinic_id,setting_key');
      final row = req.rows.firstWhere(
        (r) => r['setting_key'] == SettingKeys.notation,
      );
      expect(row['clinic_id'], clinicId);
      expect(row['value_json'], 'palmer');
      expect(await s.pendingCount(), 0);
    });

    test('immutable tables are pushed with ignore-duplicates', () async {
      await s.repos.billing.recordPayment(
        ctx,
        payment(invoiceId: null),
        allowAdvance: true,
      );
      await s.engine().pushPending();
      expect(
        s.fake.requestsFor('payments').single.prefer,
        contains('ignore-duplicates'),
      );
      expect(
        s.fake.requestsFor('ledger_entries').single.prefer,
        contains('ignore-duplicates'),
      );
      expect(
        s.fake.requestsFor('patients').single.prefer,
        contains('merge-duplicates'),
      );
      // A second push of the same payment (replayed outbox row) is accepted
      // by the server even though it has no UPDATE policy.
      await s.db
          .into(s.db.syncOutbox)
          .insert(
            SyncOutboxCompanion.insert(
              id: 'ob-replay',
              clinicId: clinicId,
              targetTable: 'payments',
              rowId: 'pay-1',
              operation: OutboxOperation.update,
              payload: const {},
              createdAt: t2,
            ),
          );
      final engine = s.engine();
      await engine.pushPending();
      expect(engine.current.status, SyncStatus.idle);
      expect(await s.pendingCount(), 0);
    });

    test('keeps entries pending and counts attempts on a 500', () async {
      s.fake.failNext.addAll([500, 500, 500]);
      final engine = s.engine(backoff: const BackoffPolicy(maxAttempts: 3));
      final before = await s.pendingCount();
      await engine.pushPending();
      expect(engine.current.status, SyncStatus.offline);
      expect(engine.current.error, contains('PostgrestException 500'));
      expect(engine.current.error, contains('clinics'));
      expect(await s.pendingCount(), before);
      final clinicEntry = (await s.repos.outbox.pending(clinicId))
          .firstWhere((e) => e.targetTable == 'clinics');
      expect(clinicEntry.attempts, 3);
      expect(clinicEntry.lastError, contains('500'));
      // Exponential backoff between the three attempts.
      expect(s.sleeps, [
        const Duration(seconds: 1),
        const Duration(seconds: 2),
      ]);
      // Nothing after clinics was attempted.
      expect(s.fake.requests.map((r) => r.table).toSet(), {'clinics'});
      expect(s.fake.rows('clinics'), isEmpty);
    });

    test('retries with backoff and succeeds', () async {
      s.fake.failNext.addAll([503, 503]);
      final engine = s.engine(
        backoff: const BackoffPolicy(
          maxAttempts: 4,
          initial: Duration(milliseconds: 500),
        ),
      );
      await engine.pushPending();
      expect(engine.current.status, SyncStatus.idle);
      expect(s.fake.requestsFor('clinics'), hasLength(3));
      expect(s.sleeps, [
        const Duration(milliseconds: 500),
        const Duration(seconds: 1),
      ]);
      expect(await s.pendingCount(), 0);
      // The counter kept the failed attempts even though the row was acked.
      final rows = await s.db.select(s.db.syncOutbox).get();
      expect(rows.where((r) => r.targetTable == 'clinics').single.attempts, 2);
    });

    test('a 4xx rejection stops the push without retrying', () async {
      s.fake.failNext.add(409);
      final engine = s.engine();
      await engine.pushPending();
      expect(engine.current.status, SyncStatus.error);
      expect(engine.current.error, contains('23503'));
      expect(s.fake.requestsFor('clinics'), hasLength(1));
      expect(s.sleeps, isEmpty);
      expect(await s.pendingCount(), greaterThan(0));
    });

    test('defers cyclic foreign keys to a fix-up step', () async {
      await s.repos.chart.createProcedure(ctx, procedure());
      await s.repos.labs.upsertLab(ctx, lab());
      await s.repos.labs.createCase(ctx, labCase());
      await s.repos.chart.updateProcedure(
        ctx,
        procedure().copyWith(labCaseId: 'case-1'),
      );
      await s.engine().pushPending();
      final tables = s.fake.requests.map((r) => r.table).toList();
      final first = tables.indexOf('procedures');
      final labs = tables.indexOf('lab_cases');
      final fixup = tables.lastIndexOf('procedures');
      expect(first, lessThan(labs));
      expect(labs, lessThan(fixup));
      final procReqs = s.fake.requestsFor('procedures');
      expect(procReqs, hasLength(2));
      expect(procReqs.first.rows.single.containsKey('lab_case_id'), isFalse);
      expect(procReqs.first.rows.single['fee_paise'], 600000);
      expect(procReqs.last.rows.single.keys.toSet(), {'id', 'lab_case_id'});
      expect(s.fake.row('procedures', 'proc-1')!['lab_case_id'], 'case-1');
      expect(await s.pendingCount(), 0);
    });

    test('is idempotent: a second push sends nothing', () async {
      final engine = s.engine();
      await engine.pushPending();
      final n = s.fake.requests.length;
      await engine.pushPending();
      expect(s.fake.requests.length, n);
      expect(engine.lastPushReport!.rowsSent, 0);
      expect(engine.current.status, SyncStatus.idle);
    });
  });
}
