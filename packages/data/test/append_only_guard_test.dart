import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late TestEnv env;

  setUp(() async => env = await TestEnv.open());
  tearDown(() => env.close());

  group('append-only guard', () {
    test('ensureAbsent throws only when the id already exists', () async {
      final chart = env.repos.chart as DriftChartRepository;
      await chart.ensureAbsent(env.db.toothStateRecords, 'ts-1');
      await chart.recordToothState(
        ctx,
        toothState('ts-1', '36', ToothState.present, t0),
      );
      await expectLater(
        chart.ensureAbsent(env.db.toothStateRecords, 'ts-1'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('tooth_state_records is append-only'),
          ),
        ),
      );
    });

    test('audited() refuses to overwrite rows of append-only tables', () async {
      final r = env.repos;
      await r.chart.recordToothState(
        ctx,
        toothState('ts-1', '36', ToothState.present, t0),
      );
      final auditBefore = await r.audit.count(clinicId);
      await expectLater(
        r.chart.recordToothState(
          ctx,
          toothState('ts-1', '36', ToothState.extracted, t1),
        ),
        throwsStateError,
      );
      expect(
        (await r.chart.toothStateHistory(patientId)).single.state,
        ToothState.present,
      );
      expect(await r.audit.count(clinicId), auditBefore);

      await r.consents.recordConsent(ctx, consent());
      await expectLater(
        r.consents.recordConsent(ctx, consent()),
        throwsStateError,
      );
      await r.consents.recordDataConsent(ctx, dataConsent());
      await expectLater(
        r.consents.recordDataConsent(ctx, dataConsent(granted: false)),
        throwsStateError,
      );
      await r.perio.saveExam(ctx, perioExam());
      await expectLater(r.perio.saveExam(ctx, perioExam()), throwsStateError);
      for (final table in [
        'consent_records',
        'data_consents',
        'payments',
        'ledger_entries',
        'prescriptions',
        'tooth_state_records',
        'audit_events',
      ]) {
        expect(appendOnlyTables, contains(table));
      }
    });

    test('mutable tables still update in place', () async {
      final p = patient();
      await env.repos.patients.upsert(ctx, p.copyWith(notes: 'changed'));
      expect((await env.repos.patients.getById(p.id))!.notes, 'changed');
    });
  });

  group('RepositoryException', () {
    test('a unique violation surfaces without the bound row values', () async {
      // Same patient number as the seeded patient, different id.
      final clash = patient(
        id: 'patient-2',
        firstName: 'Sita',
        lastName: 'Devi',
        phone: '9888877777',
      );
      Object? caught;
      try {
        await env.repos.patients.upsert(ctx, clash);
      } catch (e) {
        caught = e;
      }
      expect(caught, isA<RepositoryException>());
      final ex = caught! as RepositoryException;
      expect(ex.kind, RepositoryErrorKind.constraint);
      expect(ex.extendedResultCode, 2067);
      expect(ex.codeName, 'SQLITE_CONSTRAINT_UNIQUE');
      expect(ex.table, 'patients');
      expect(ex.constraint, 'patients.clinic_id, patients.patient_number');
      final text = ex.toString();
      expect(text, contains('patients'));
      expect(text, contains('SQLITE_CONSTRAINT_UNIQUE'));
      for (final phi in ['Sita', 'Devi', '9888877777', 'P-00001', 'anil@']) {
        expect(text, isNot(contains(phi)));
      }
      // The failed transaction left no trace.
      expect(await env.repos.patients.getById('patient-2'), isNull);
      expect(await env.repos.patients.count(clinicId), 1);
    });

    test('a foreign key violation names the table, not the row', () async {
      Object? caught;
      try {
        await env.repos.appointments.upsert(
          ctx,
          appointment(id: 'appt-x').copyWith(
            patientId: 'no-such-patient',
            notes: 'Sensitive note about Mr Rao',
          ),
        );
      } catch (e) {
        caught = e;
      }
      expect(caught, isA<RepositoryException>());
      final ex = caught! as RepositoryException;
      expect(ex.extendedResultCode, 787);
      expect(ex.table, 'appointments');
      expect(ex.toString(), isNot(contains('Rao')));
      expect(ex.toString(), isNot(contains('no-such-patient')));
    });

    test('application errors pass through unchanged', () async {
      await expectLater(
        env.repos.patients.deactivate(ctx, 'missing'),
        throwsStateError,
      );
      expect(RepositoryException.sanitise(StateError('x')), isNull);
    });
  });
}
