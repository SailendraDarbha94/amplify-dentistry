import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/features/appointments/appointment_form_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'appointments_test_env.dart';

void main() {
  group('slot maths', () {
    test('roundToSlot drops to the 10-minute grid', () {
      expect(
        roundToSlot(DateTime(2026, 10, 26, 10, 17, 42)),
        DateTime(2026, 10, 26, 10, 10),
      );
      expect(
        roundToSlot(DateTime(2026, 10, 26, 10, 0, 59)),
        DateTime(2026, 10, 26, 10),
      );
    });

    test('weekStart is Monday', () {
      expect(weekStart(DateTime(2026, 10, 25)), DateTime(2026, 10, 19));
      expect(weekStart(DateTime(2026, 10, 19, 9)), DateTime(2026, 10, 19));
    });

    test('defaultDurationFor sums procedures and rounds up to the grid', () {
      expect(defaultDurationFor(const []), defaultAppointmentMinutes);
      expect(
        defaultDurationFor(const [
          PlannedWork(code: 'A', name: 'A', durationMinutes: 25),
          PlannedWork(code: 'B', name: 'B', durationMinutes: 20),
        ]),
        50,
      );
    });
  });

  group('AppointmentDraft', () {
    final start = DateTime(2026, 11, 2, 10);
    final patient = testPatient();

    test('validate requires patient and provider', () {
      expect(AppointmentDraft(startsAt: start).validate(), 'Choose a patient');
      expect(
        AppointmentDraft(startsAt: start, patient: patient).validate(),
        'Choose a dentist',
      );
      expect(
        AppointmentDraft(
          startsAt: start,
          patient: patient,
          providerId: testDentistId,
        ).validate(),
        isNull,
      );
    });

    test('toAppointment stores UTC, procedure ids and a fallback reason', () {
      final draft = AppointmentDraft(
        startsAt: start,
        patient: patient,
        providerId: testDentistId,
        chairId: 'chair-1',
        durationMinutes: 40,
        work: const [
          PlannedWork(
            procedureId: 'proc-1',
            code: 'RCT-MOL',
            name: 'RCT molar',
            durationMinutes: 40,
            teethLabel: '16',
          ),
          PlannedWork(code: 'XR-IOPA', name: 'IOPA', durationMinutes: 10),
        ],
      );
      final a = draft.toAppointment(
        clinicId: testClinicId,
        now: DateTime(2026, 10, 25),
      );
      expect(a.startsAt.isUtc, isTrue);
      expect(a.endsAt.difference(a.startsAt), const Duration(minutes: 40));
      expect(a.plannedProcedureIds, ['proc-1']);
      expect(a.reason, 'RCT molar (16), IOPA');
      expect(a.status, AppointmentStatus.scheduled);
    });

    test('moving a confirmed appointment resets it to scheduled', () {
      final now = DateTime.utc(2026, 10, 25);
      final existing = Appointment(
        id: 'a1',
        clinicId: testClinicId,
        patientId: patient.id,
        providerId: testDentistId,
        startsAt: start.toUtc(),
        endsAt: start.add(const Duration(minutes: 30)).toUtc(),
        status: AppointmentStatus.confirmed,
        confirmedAt: now,
        reminder24hSentAt: now,
        createdAt: now,
        updatedAt: now,
      );
      final moved = AppointmentDraft.fromAppointment(
        existing,
        patient: patient,
      ).copyWith(startsAt: start.add(const Duration(hours: 1)));
      final a = moved.toAppointment(
        clinicId: testClinicId,
        now: now,
        existing: existing,
      );
      expect(a.id, 'a1');
      expect(a.status, AppointmentStatus.scheduled);
      expect(a.reminder24hSentAt, isNull);
      expect(a.createdAt, now);
    });
  });

  group('quickAddPatient', () {
    test('splits the name and normalises the phone', () {
      final p = quickAddPatient(
        clinicId: testClinicId,
        name: 'Ravi Kumar Reddy',
        phone: '98765 43210',
        now: DateTime(2026, 10, 25),
      );
      expect(p.firstName, 'Ravi');
      expect(p.lastName, 'Kumar Reddy');
      expect(p.phone, '+919876543210');
      expect(p.patientNumber, isEmpty);
    });
  });

  group('AppointmentBooker', () {
    late ApptTestEnv env;

    setUp(() async => env = await ApptTestEnv.open());
    tearDown(() => env.close());

    test('finds a clash on the same chair and none on a free chair', () async {
      final booker = AppointmentBooker(
        appointments: env.repos.appointments,
        ctx: testCtx,
      );
      final patient = (await env.repos.patients.getById(testPatientId))!;
      final start = DateTime(2026, 11, 2, 10);
      final first = AppointmentDraft(
        startsAt: start,
        patient: patient,
        providerId: testDentistId,
        chairId: 'chair-1',
      );
      await booker.save(first, now: DateTime(2026, 10, 25));

      final overlapping = first.copyWith(
        startsAt: start.add(const Duration(minutes: 20)),
      );
      expect(await booker.conflictsFor(overlapping), hasLength(1));

      final other = await env.addPatient(
        testPatient(id: 'p2', firstName: 'Ravi', phone: '+919000000009'),
      );
      await env.repos.clinics.upsertChair(
        testCtx,
        const Chair(id: 'chair-2', clinicId: testClinicId, name: 'Chair 2'),
      );
      // Same chair, later slot: free.
      expect(
        await booker.conflictsFor(
          first.copyWith(
            patient: other,
            startsAt: start.add(const Duration(minutes: 30)),
          ),
        ),
        isEmpty,
      );
      // Other chair, same provider: still a clash (provider double booked).
      expect(
        await booker.conflictsFor(
          first.copyWith(patient: other, chairId: 'chair-2'),
        ),
        hasLength(1),
      );
    });
  });

  group('New appointment page', () {
    late ApptTestEnv env;

    setUp(() async => env = await ApptTestEnv.open());
    tearDown(() => env.close());

    const newUrl = '/schedule/new?patientId=$testPatientId&at=2026-11-02T10:00';

    testWidgets('books a slot and warns when the same chair is taken', (
      tester,
    ) async {
      await env.pumpApp(tester);
      await env.go(tester, newUrl);
      await settle(tester, frames: 8);
      expect(find.byKey(const ValueKey('appointment-patient')), findsOneWidget);
      expect(find.text('Asha Rao'), findsOneWidget);
      expect(find.byKey(const ValueKey('appointment-conflict')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('appointment-save')));
      await settle(tester, frames: 12);

      final booked = await env.repos.appointments.range(
        testClinicId,
        DateTime(2026, 11, 2).toUtc(),
        DateTime(2026, 11, 3).toUtc(),
      );
      expect(booked, hasLength(1));
      expect(booked.single.chairId, 'chair-1');
      expect(booked.single.providerId, testDentistId);
      expect(booked.single.duration, const Duration(minutes: 30));
      expect(env.location, '/schedule/${booked.single.id}');

      // Second booking at the same time on the same chair.
      await env.go(tester, newUrl);
      await settle(tester, frames: 10);
      expect(
        find.byKey(const ValueKey('appointment-conflict')),
        findsOneWidget,
      );
      expect(find.textContaining('Clashes with 1'), findsOneWidget);
      expect(find.text('Book anyway'), findsOneWidget);

      // Picking a later duration-free slot clears the warning.
      await tester.tap(find.byKey(const ValueKey('appointment-duration-10')));
      await settle(tester, frames: 8);
      expect(
        find.byKey(const ValueKey('appointment-conflict')),
        findsOneWidget,
        reason: 'shorter but still overlapping',
      );
    });

    testWidgets('schedule day view shows the booked block', (tester) async {
      final start = DateTime(2026, 11, 2, 10);
      final a = await env.repos.appointments.upsert(
        testCtx,
        Appointment(
          id: 'appt-day',
          clinicId: testClinicId,
          patientId: testPatientId,
          providerId: testDentistId,
          chairId: 'chair-1',
          startsAt: start.toUtc(),
          endsAt: start.add(const Duration(minutes: 30)).toUtc(),
          reason: 'Scaling',
          createdAt: DateTime.utc(2026, 10, 25),
          updatedAt: DateTime.utc(2026, 10, 25),
        ),
      );
      await env.pumpApp(tester);
      await env.go(tester, '/schedule');
      // Jump to the booked day through the week strip.
      final target = ValueKey('schedule-day-${dayKey(start)}');
      while (find.byKey(target).evaluate().isEmpty) {
        await tester.tap(find.byKey(const ValueKey('schedule-next-week')));
        await settle(tester, frames: 2);
      }
      await tester.tap(find.byKey(target));
      await settle(tester, frames: 8);
      expect(find.byKey(ValueKey('schedule-block-${a.id}')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('schedule-column-chair-1')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(ValueKey('schedule-block-${a.id}')));
      await settle(tester, frames: 8);
      expect(env.location, '/schedule/${a.id}');
    });
  });
}
