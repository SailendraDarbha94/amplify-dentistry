import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sync_helpers.dart';

void main() {
  late SyncTestEnv s;

  setUp(() async => s = await SyncTestEnv.open());
  tearDown(() => s.close());

  Future<List<OutboxEntry>> heldFor(String table) async =>
      (await s.repos.outbox.held(clinicId))
          .where((e) => e.targetTable == table)
          .toList();

  group('quarantine', () {
    test(
      'a 409 poison row is isolated, its children blocked, the rest synced',
      () async {
        await s.repos.appointments.upsert(ctx, appointment());
        await s.repos.patients.upsert(
          ctx,
          patient(id: 'patient-2', number: 'P-00002', phone: '9000000009'),
        );
        s.fake.rejectRows[patientId] = 409;
        final engine = s.engine();
        await engine.pushPending();

        expect(engine.current.status, SyncStatus.idle);
        expect(engine.current.error, isNull);
        expect(s.sleeps, isEmpty, reason: 'permanent errors never back off');
        final report = engine.lastPushReport!;
        expect(report.rowsQuarantined, 1);
        expect(report.entriesBlocked, greaterThan(0));
        // The two-row batch failed, then each row went alone.
        expect(s.fake.upserts['patients'], 3);
        expect(s.fake.row('patients', 'patient-2'), isNotNull);
        expect(s.fake.row('patients', patientId), isNull);
        expect(s.fake.rows('clinics'), hasLength(1));
        expect(s.fake.rows('appointments'), isEmpty);

        expect(await s.pendingCount(), 0);
        final quarantined = await heldFor('patients');
        expect(quarantined, hasLength(1));
        expect(quarantined.single.status, OutboxStatus.quarantined);
        expect(quarantined.single.serverStatusCode, 409);
        expect(quarantined.single.lastError, contains('23503'));
        expect(quarantined.single.lastError, contains('foreign key'));
        expect(quarantined.single.attempts, 1);
        final blocked = await heldFor('appointments');
        expect(blocked, hasLength(1));
        expect(blocked.single.status, OutboxStatus.blockedBy);
        expect(blocked.single.blockedBy, quarantined.single.id);
        expect(await s.repos.outbox.heldCount(clinicId), 2);
        await engine.state.firstWhere((st) => st.quarantinedCount == 2);
        expect(engine.current.quarantinedCount, 2);

        // The held rows are described for the repair screen.
        final problems = await engine.repair.listProblems();
        expect(problems, hasLength(2));
        final p = problems.firstWhere((p) => p.table == 'patients');
        expect(p.isQuarantined, isTrue);
        expect(p.entityType, 'Patient');
        expect(p.entityLabel, 'Anil Kumar');
        expect(p.statusCode, 409);
        expect(p.description, contains('Patient "Anil Kumar" (patients)'));
        expect(p.description, contains('rejected by the server (409)'));
        expect(p.description, contains('23503'));
        expect(p.description, contains('changed 2026-'));
        final a = problems.firstWhere((p) => p.table == 'appointments');
        expect(a.isQuarantined, isFalse);
        expect(a.blockedBy, p.id);
        expect(a.entityType, 'Appointment');
        expect(a.description, contains('waiting on a rejected row'));

        // A second push sends nothing: held rows are not retried forever.
        final n = s.fake.requests.length;
        await engine.pushPending();
        expect(s.fake.requests.length, n);
        expect(await s.repos.outbox.heldCount(clinicId), 2);
        await engine.dispose();
      },
    );

    test('a 403 (RLS) quarantines with status 403', () async {
      s.fake.rejectRows[patientId] = 403;
      final engine = s.engine();
      await engine.pushPending();
      expect(engine.current.status, SyncStatus.idle);
      final q = (await heldFor('patients')).single;
      expect(q.status, OutboxStatus.quarantined);
      expect(q.serverStatusCode, 403);
      expect(q.lastError, contains('42501'));
      expect(q.lastError, contains('row-level security'));
      expect(s.fake.rows('clinic_members'), hasLength(1));
    });

    test('retry re-queues the chain and succeeds once accepted', () async {
      await s.repos.appointments.upsert(ctx, appointment());
      s.fake.rejectRows[patientId] = 409;
      final engine = s.engine();
      await engine.pushPending();
      expect(await s.repos.outbox.heldCount(clinicId), 2);

      // Still rejected: retry puts it back where it was.
      final problem = (await engine.repair.listProblems()).firstWhere(
        (p) => p.isQuarantined,
      );
      expect(await engine.repair.retry(problem.id), 2);
      expect(await s.pendingCount(), 2);
      expect(await s.repos.outbox.heldCount(clinicId), 0);
      await engine.pushPending();
      expect(await s.repos.outbox.heldCount(clinicId), 2);
      expect((await heldFor('patients')).single.attempts, 2);

      // The server accepts it now.
      s.fake.rejectRows.clear();
      await engine.repair.retry(problem.id);
      await engine.pushPending();
      expect(engine.current.status, SyncStatus.idle);
      expect(await s.pendingCount(), 0);
      expect(await s.repos.outbox.heldCount(clinicId), 0);
      expect(s.fake.row('patients', patientId), isNotNull);
      expect(s.fake.row('appointments', 'appt-1'), isNotNull);
      expect(await engine.repair.listProblems(), isEmpty);
    });

    test('a new local write to a quarantined row re-pushes it', () async {
      await s.repos.appointments.upsert(ctx, appointment());
      s.fake.rejectRows[patientId] = 409;
      final engine = s.engine();
      await engine.pushPending();
      expect(await s.repos.outbox.heldCount(clinicId), 2);

      s.fake.rejectRows.clear();
      await s.repos.patients.upsert(ctx, patient(firstName: 'Fixed'));
      expect(await s.pendingCount(), 1);
      await engine.pushPending();
      expect(s.fake.row('patients', patientId)!['first_name'], 'Fixed');
      // The older rejected state is obsolete and the child was released
      // and pushed in the same run.
      expect(await s.repos.outbox.heldCount(clinicId), 0);
      expect(await s.pendingCount(), 0);
      expect(s.fake.row('appointments', 'appt-1'), isNotNull);
    });

    test(
      'discard restores the server copy of a last-writer-wins row',
      () async {
        final engine = s.engine();
        await engine.pushPending();
        expect(s.fake.row('patients', patientId), isNotNull);
        // Another device changed the row on the server meanwhile.
        s.fake.row('patients', patientId)!['first_name'] = 'Server';
        s.fake.row('patients', patientId)!['updated_at'] = s.fake
            .nextTimestamp();

        await s.repos.patients.upsert(ctx, patient(firstName: 'Local'));
        s.fake.rejectRows[patientId] = 409;
        await engine.pushPending();
        final problem = (await engine.repair.listProblems()).single;
        expect(problem.rowId, patientId);

        final outcome = await engine.repair.discardLocalChange(problem.id, ctx);
        expect(outcome.entriesDiscarded, 1);
        expect(outcome.rowsRestored, 1);
        expect(outcome.rowsRejected, 0);
        expect(
          (await s.repos.patients.getById(patientId))!.firstName,
          'Server',
        );
        expect(await s.pendingCount(), 0);
        expect(await s.repos.outbox.heldCount(clinicId), 0);
        final entry = await s.repos.outbox.byId(problem.id);
        expect(entry!.status, OutboxStatus.discarded);
        expect(entry.ackedAt, isNotNull);
        expect(await engine.repair.rejectedRows(), isEmpty);
        // Nothing is sent for it afterwards.
        final n = s.fake.upserts['patients'];
        await engine.pushPending();
        expect(s.fake.upserts['patients'], n);
      },
    );

    test('discard of a row the server never took marks it rejected', () async {
      await s.repos.appointments.upsert(ctx, appointment());
      s.fake.rejectRows[patientId] = 409;
      final engine = s.engine();
      await engine.pushPending();
      final problem = (await engine.repair.listProblems()).firstWhere(
        (p) => p.isQuarantined,
      );
      final outcome = await engine.repair.discardLocalChange(problem.id, ctx);
      // The patient and its blocked appointment were both dropped.
      expect(outcome.entriesDiscarded, 2);
      expect(outcome.rowsRestored, 0);
      expect(outcome.rowsRejected, 2);
      expect(await s.repos.outbox.heldCount(clinicId), 0);
      // The local rows stay (nothing is ever deleted) and are flagged.
      expect(await s.repos.patients.getById(patientId), isNotNull);
      final notes = await engine.repair.rejectedRows();
      expect(
        notes.keys,
        containsAll([
          SyncStateKeys.rejected('patients', patientId),
          SyncStateKeys.rejected('appointments', 'appt-1'),
        ]),
      );
      final note = notes[SyncStateKeys.rejected('patients', patientId)]!;
      expect(note['statusCode'], 409);
      expect(note['outboxId'], problem.id);
      expect(note['error'], contains('23503'));
      // ... and the audit log says so.
      final events = await s.repos.audit.forEntity(
        clinicId,
        'Patient',
        patientId,
      );
      final rejected = events.where(
        (e) => e.reason?.contains('rejected by the server') ?? false,
      );
      expect(rejected, hasLength(1));
      expect(rejected.single.action, AuditAction.statusChange);
      expect(rejected.single.after?['syncRejected'], isA<Map>());
      await engine.repair.clearRejected('patients', patientId);
      expect(
        (await engine.repair.rejectedRows()).keys,
        isNot(contains(SyncStateKeys.rejected('patients', patientId))),
      );
    });

    test('a pulled row never overwrites a held local change', () async {
      final engine = s.engine();
      await engine.pushPending();
      await s.repos.patients.upsert(ctx, patient(firstName: 'Local'));
      s.fake.rejectRows[patientId] = 409;
      await engine.pushPending();
      s.fake.row('patients', patientId)!['first_name'] = 'Server';
      s.fake.row('patients', patientId)!['updated_at'] = s.fake.nextTimestamp();
      await engine.pullSince(null);
      expect((await s.repos.patients.getById(patientId))!.firstName, 'Local');
    });
  });
}
