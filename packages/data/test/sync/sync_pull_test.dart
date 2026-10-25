import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
// ignore: implementation_imports
import 'package:ampdent_data/src/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sync_helpers.dart';

void main() {
  late SyncTestEnv s;

  setUp(() async => s = await SyncTestEnv.open(withPatient: false));
  tearDown(() => s.close());

  /// Seeds a server patient row (local entity shape, server columns).
  Map<String, Object?> seedPatient(Patient p, {String? updatedAt}) =>
      s.fake.seed(
        'patients',
        s.serverRow('patients', p.toInsertable()),
        updatedAt: updatedAt,
      );

  group('pull', () {
    test('first pull is full, inserts rows and sets watermarks', () async {
      seedPatient(patient(id: 'p-1', number: 'P-1'));
      seedPatient(patient(id: 'p-2', number: 'P-2', phone: '9000000009'));
      s.fake.seed('chairs', {
        'id': 'chair-9',
        'clinic_id': clinicId,
        'name': 'Chair 9',
        'sort_order': 1,
        'is_active': true,
      });
      expect(await s.state.hasNoWatermarks, isTrue);
      final pendingBefore = await s.pendingCount();
      final engine = s.engine();
      await engine.pullSince(null);
      expect(engine.current.status, SyncStatus.idle);
      expect(engine.lastPullReport!.wasFull, isTrue);
      expect(engine.lastPullReport!.applied, 3);
      expect(await s.repos.patients.getById('p-1'), isNotNull);
      expect((await s.repos.clinics.chairs(clinicId)).single.name, 'Chair 9');
      // No updated_at filter on a full pull; one GET per synced table.
      final first = s.fake.requestsFor('patients', method: 'GET').single;
      expect(first.query.containsKey('or'), isFalse);
      expect(first.query['updated_at'], isNull);
      expect(first.query['clinic_id'], 'eq.$clinicId');
      expect(first.query['order'], startsWith('updated_at.asc'));
      expect(first.query['limit'], '1000');
      expect(
        s.fake.requests.where((r) => r.method == 'GET').length,
        syncTables.length,
      );
      final wm = await s.state.watermark('patients');
      expect(wm!.updatedAt, s.fake.row('patients', 'p-2')!['updated_at']);
      expect(wm.lastKey, 'p-2');
      expect(await s.state.hasNoWatermarks, isFalse);
      expect(
        await s.state.readInstant(SyncStateKeys.lastFullSyncAt),
        isNotNull,
      );
      expect(
        await s.pendingCount(),
        pendingBefore,
        reason: 'pulled rows never re-enter the outbox',
      );
    });

    test('pages with keyset filters and advances the watermark', () async {
      for (var i = 0; i < 5; i++) {
        seedPatient(patient(id: 'p-$i', number: 'P-$i', phone: '900000000$i'));
      }
      final engine = s.engine(pageSize: 2);
      await engine.pullSince(null);
      final gets = s.fake.requestsFor('patients', method: 'GET');
      expect(gets, hasLength(3));
      expect(gets[0].query.containsKey('or'), isFalse);
      final p1 = s.fake.row('patients', 'p-1')!;
      expect(
        gets[1].query['or'],
        '(updated_at.gt."${p1['updated_at']}",'
        'and(updated_at.eq."${p1['updated_at']}",id.gt."p-1"))',
      );
      expect(engine.lastPullReport!.applied, 5);
      expect((await s.state.watermark('patients'))!.lastKey, 'p-4');
    });

    test('incremental pull fetches only rows above the watermark', () async {
      seedPatient(patient(id: 'p-1', number: 'P-1'));
      final engine = s.engine();
      await engine.pullSince(null);
      seedPatient(patient(id: 'p-2', number: 'P-2', phone: '9000000009'));
      await engine.pullSince(null);
      expect(engine.lastPullReport!.wasFull, isFalse);
      final second = s.fake.requestsFor('patients', method: 'GET').last;
      expect(second.query['or'], contains('updated_at.gt.'));
      expect(engine.lastPullReport!.fetched, 1);
      expect(engine.lastPullReport!.applied, 1);
      expect(await s.repos.patients.getById('p-2'), isNotNull);
    });

    test('append-only rows are inserted once and never overwritten', () async {
      await s.repos.patients.upsert(ctx, patient());
      await s.repos.billing.recordPayment(
        ctx,
        payment(invoiceId: null),
        allowAdvance: true,
      );
      final engine = s.engine();
      await engine.pushPending();
      // The server copy diverges (should never happen, but must not win).
      s.fake.row('payments', 'pay-1')!['amount_paise'] = 1;
      s.fake.row('payments', 'pay-1')!['updated_at'] = s.fake.nextTimestamp();
      s.fake.seed('payments', {
        ...s.serverRow(
          'payments',
          payment(id: 'pay-2', invoiceId: null).toInsertable(),
        ),
      });
      await engine.pullSince(null);
      final local = await s.repos.billing.paymentsForPatient(patientId);
      expect(local.map((p) => p.id).toSet(), {'pay-1', 'pay-2'});
      expect(
        local.firstWhere((p) => p.id == 'pay-1').amount,
        const Money.rupees(6800),
      );
      final report = engine.lastPullReport!.tables.firstWhere(
        (t) => t.table == 'payments',
      );
      expect(report.keptAppendOnly, 1);
      expect(report.inserted, 1);
    });

    test('last writer wins by server updated_at', () async {
      await s.repos.patients.upsert(ctx, patient(firstName: 'Local'));
      final engine = s.engine();
      await engine.pushPending();
      // Older server copy: kept local.
      s.fake.row('patients', patientId)!
        ..['first_name'] = 'Stale'
        ..['updated_at'] = FakePostgrest.ts(DateTime.utc(2020));
      await engine.pullSince(DateTime.utc(2019));
      expect((await s.repos.patients.getById(patientId))!.firstName, 'Local');
      // Newer server copy: overwrites.
      s.fake.row('patients', patientId)!
        ..['first_name'] = 'Fresh'
        ..['updated_at'] = s.fake.nextTimestamp();
      await engine.pullSince(null);
      final after = (await s.repos.patients.getById(patientId))!;
      expect(after.firstName, 'Fresh');
      expect(after.lastName, 'Kumar');
      final report = engine.lastPullReport!.tables.firstWhere(
        (t) => t.table == 'patients',
      );
      expect(report.updated, 1);
      expect(await s.pendingCount(), 0);
    });

    test('a locally pending row is not overwritten until pushed', () async {
      await s.repos.patients.upsert(ctx, patient(firstName: 'Local'));
      final engine = s.engine();
      await engine.pushPending();
      await s.repos.patients.upsert(ctx, patient(firstName: 'Edited offline'));
      s.fake.row('patients', patientId)!
        ..['first_name'] = 'Other device'
        ..['updated_at'] = s.fake.nextTimestamp();
      await engine.pullSince(null);
      expect(
        (await s.repos.patients.getById(patientId))!.firstName,
        'Edited offline',
      );
      expect(
        engine.lastPullReport!.tables
            .firstWhere((t) => t.table == 'patients')
            .keptPending,
        1,
      );
      // Once pushed, the local edit is the server's newest and comes back.
      await engine.pushPending();
      expect(
        s.fake.row('patients', patientId)!['first_name'],
        'Edited offline',
      );
      await engine.pullSince(null);
      expect(
        (await s.repos.patients.getById(patientId))!.firstName,
        'Edited offline',
      );
    });

    test('server-minted invoice number replaces the DRAFT- number', () async {
      await s.repos.patients.upsert(ctx, patient());
      final draft = await s.repos.billing.saveDraft(ctx, draftInvoice());
      final issued = await s.repos.billing.issueInvoice(ctx, draft.id, at: t0);
      expect(issued.number, startsWith('DRAFT-'));
      final engine = s.engine();
      await engine.pushPending();
      expect(s.fake.row('invoices', 'inv-1')!['number'], 'INV/2026-27/0001');
      await engine.pullSince(null);
      final local = (await s.repos.billing.getInvoice('inv-1'))!;
      expect(local.number, 'INV/2026-27/0001');
      expect(local.status, InvoiceStatus.issued);
      expect(local.grandTotal, issued.grandTotal);
      // A later local write replays the minted number; the server keeps it.
      await s.repos.billing.recordPayment(
        ctx,
        payment(amount: const Money.rupees(100)),
      );
      await engine.pushPending();
      expect(s.fake.row('invoices', 'inv-1')!['number'], 'INV/2026-27/0001');
      expect(s.fake.invoiceCounter, 1);
    });

    test(
      'normalises server timestamps and dates to the local format',
      () async {
        final row = s.serverRow(
          'patients',
          patient(id: 'p-1', number: 'P-1').toInsertable(),
        );
        row['date_of_birth'] = '1990-05-20';
        row['age_recorded_at'] = '2026-10-18T09:00:00.123456+00:00';
        s.fake.seed('patients', row, updatedAt: '2026-10-18T10:00:00.5+00:00');
        await s.engine().pullSince(null);
        final local = (await s.localRow('patients', 'p-1'))!;
        expect(local['date_of_birth'], '1990-05-20T00:00:00.000Z');
        expect(local['age_recorded_at'], '2026-10-18T09:00:00.123Z');
        expect(local['updated_at'], '2026-10-18T10:00:00.500Z');
        expect(local['is_active'], 1);
        expect(local['tags'], '["vip"]');
        final entity = (await s.repos.patients.getById('p-1'))!;
        expect(entity.dateOfBirth, DateTime.utc(1990, 5, 20));
      },
    );

    test('ignores server-only columns and keeps local defaults', () async {
      final engine = s.engine();
      await engine.pushPending();
      // Server-only columns come back; the server copy is newer.
      s.fake.row('clinics', clinicId)!
        ..['name'] = 'Renamed'
        ..['region'] = 'in'
        ..['created_by'] = 'user-1'
        ..['updated_at'] = s.fake.nextTimestamp();
      await engine.pullSince(null);
      expect((await s.repos.clinics.getClinic(clinicId))!.name, 'Renamed');
    });

    test('pullSince lowers the watermark to the given instant', () async {
      seedPatient(
        patient(id: 'p-1', number: 'P-1'),
        updatedAt: FakePostgrest.ts(DateTime.utc(2026, 1, 1)),
      );
      seedPatient(
        patient(id: 'p-2', number: 'P-2', phone: '9000000009'),
        updatedAt: FakePostgrest.ts(DateTime.utc(2026, 6, 1)),
      );
      await s.state.setWatermark(
        'patients',
        SyncWatermark(FakePostgrest.ts(DateTime.utc(2027)), lastKey: 'zz'),
      );
      final engine = s.engine();
      await engine.pullSince(null);
      expect(await s.repos.patients.getById('p-1'), isNull);
      await engine.pullSince(DateTime.utc(2026, 3, 1));
      expect(await s.repos.patients.getById('p-1'), isNull);
      expect(await s.repos.patients.getById('p-2'), isNotNull);
      final gets = s.fake.requestsFor('patients', method: 'GET');
      expect(gets.last.query['updated_at'], 'gt.2026-03-01T00:00:00.000Z');
    });

    test('resetWatermarks forces a full pull that is idempotent', () async {
      seedPatient(patient(id: 'p-1', number: 'P-1'));
      final engine = s.engine();
      await engine.pullSince(null);
      await engine.resetWatermarks();
      expect(await s.state.hasNoWatermarks, isTrue);
      await engine.pullSince(null);
      expect(engine.lastPullReport!.wasFull, isTrue);
      expect(engine.lastPullReport!.fetched, 1);
      expect(
        engine.lastPullReport!.applied,
        0,
        reason: 'same updated_at: kept',
      );
      expect(await s.repos.patients.getById('p-1'), isNotNull);
    });

    test('a pulled perio exam rebuilds the site readings index', () async {
      await s.repos.patients.upsert(ctx, patient());
      s.fake.seed(
        'perio_exams',
        s.serverRow('perio_exams', perioExam(id: 'perio-9').toInsertable()),
      );
      final engine = s.engine();
      await engine.pullSince(null);
      expect(await s.repos.perio.getExam('perio-9'), isNotNull);
      final history = await s.repos.perio.siteHistory(
        patientId,
        ToothId.parse('16'),
        PerioSite.mesioBuccal,
      );
      expect(history.map((p) => p.examId), ['perio-9']);
      expect(history.single.reading.probingDepth, 4);
      // Pulling the same exam again is a no-op for the exam and the index.
      await engine.pullSince(DateTime.utc(2000));
      expect(
        (await s.repos.perio.siteHistory(
          patientId,
          ToothId.parse('16'),
          PerioSite.mesioBuccal,
        )).length,
        1,
      );
    });

    test('a procedure completed on another device propagates', () async {
      await s.repos.patients.upsert(ctx, patient());
      await s.repos.chart.createProcedure(ctx, procedure());
      final engine = s.engine();
      await engine.pushPending();
      expect(await s.pendingCount(), 0);
      // Another phone completes it; the server copy is newer.
      s.fake.row('procedures', 'proc-1')!
        ..['status'] = ProcedureStatus.completed.name
        ..['completed_at'] = '2026-10-20T10:00:00+00:00'
        ..['updated_at'] = s.fake.nextTimestamp();
      await engine.pullSince(null);
      final local = (await s.repos.chart.getProcedure('proc-1'))!;
      expect(local.status, ProcedureStatus.completed);
      expect(local.completedAt, DateTime.utc(2026, 10, 20, 10));
      final report = engine.lastPullReport!.tables.firstWhere(
        (t) => t.table == 'procedures',
      );
      expect(report.updated, 1);
      expect(report.keptAppendOnly, 0);
    });

    test(
      'a 5xx during pull leaves the watermark and reports offline',
      () async {
        seedPatient(patient(id: 'p-1', number: 'P-1'));
        s.fake.failNext.add(502);
        final engine = s.engine();
        await engine.pullSince(null);
        expect(engine.current.status, SyncStatus.offline);
        expect(engine.current.error, contains('clinics'));
        expect(await s.state.hasNoWatermarks, isTrue);
        await engine.pullSince(null);
        expect(engine.current.status, SyncStatus.idle);
        expect(await s.repos.patients.getById('p-1'), isNotNull);
      },
    );
  });
}
