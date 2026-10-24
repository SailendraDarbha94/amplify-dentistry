import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/features/appointments/appointment_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'appointments_test_env.dart';

Appointment _fixture(DateTime start, {String id = 'appt-1'}) => Appointment(
  id: id,
  clinicId: testClinicId,
  patientId: testPatientId,
  providerId: testDentistId,
  chairId: 'chair-1',
  startsAt: start.toUtc(),
  endsAt: start.add(const Duration(minutes: 30)).toUtc(),
  reason: 'Review',
  createdAt: DateTime.utc(2026, 10, 25),
  updatedAt: DateTime.utc(2026, 10, 25),
);

void main() {
  group('status flow', () {
    test('terminal states offer no transitions', () {
      expect(nextAppointmentStatuses(AppointmentStatus.completed), isEmpty);
      expect(nextAppointmentStatuses(AppointmentStatus.cancelled), isEmpty);
      expect(nextAppointmentStatuses(AppointmentStatus.noShow), isEmpty);
    });

    test('scheduled can be confirmed, arrived, no-show or cancelled', () {
      expect(
        nextAppointmentStatuses(AppointmentStatus.scheduled),
        containsAll([
          AppointmentStatus.confirmed,
          AppointmentStatus.arrived,
          AppointmentStatus.noShow,
          AppointmentStatus.cancelled,
        ]),
      );
      expect(nextAppointmentStatuses(AppointmentStatus.inChair), [
        AppointmentStatus.completed,
      ]);
    });

    test('only cancellation needs a reason', () {
      expect(appointmentStatusNeedsReason(AppointmentStatus.cancelled), isTrue);
      expect(appointmentStatusNeedsReason(AppointmentStatus.noShow), isFalse);
    });
  });

  group('Appointment detail page', () {
    late ApptTestEnv env;

    setUp(() async => env = await ApptTestEnv.open());
    tearDown(() => env.close());

    Future<Appointment> current(String id) async =>
        (await env.repos.appointments.getById(id))!;

    testWidgets('status buttons persist each transition', (tester) async {
      final start = DateTime.now().add(const Duration(days: 2));
      await env.repos.appointments.upsert(testCtx, _fixture(start));
      await env.pumpApp(tester);
      await env.go(tester, '/schedule/appt-1');
      await settle(tester, frames: 8);
      expect(find.text('Asha Rao'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('appt-status-confirmed')),
        findsOneWidget,
      );

      await tapKey(tester, 'appt-status-confirmed');
      await settle(tester, frames: 8);
      var a = await current('appt-1');
      expect(a.status, AppointmentStatus.confirmed);
      expect(a.confirmedAt, isNotNull);
      expect(find.byKey(const ValueKey('appt-status-confirmed')), findsNothing);

      await tapKey(tester, 'appt-status-arrived');
      await settle(tester, frames: 8);
      a = await current('appt-1');
      expect(a.status, AppointmentStatus.arrived);
      expect(a.arrivedAt, isNotNull);

      await tapKey(tester, 'appt-status-inChair');
      await settle(tester, frames: 8);
      expect((await current('appt-1')).status, AppointmentStatus.inChair);

      await tapKey(tester, 'appt-status-completed');
      await settle(tester, frames: 8);
      expect((await current('appt-1')).status, AppointmentStatus.completed);
      expect(find.byKey(const ValueKey('appt-status-completed')), findsNothing);

      final audit = await env.repos.audit.forEntity(
        testClinicId,
        'Appointment',
        'appt-1',
      );
      expect(
        audit.where((e) => e.action == AuditAction.statusChange),
        hasLength(4),
      );
    });

    testWidgets('cancelling asks for a reason and stores it', (tester) async {
      final start = DateTime.now().add(const Duration(days: 3));
      await env.repos.appointments.upsert(
        testCtx,
        _fixture(start, id: 'appt-2'),
      );
      await env.pumpApp(tester);
      await env.go(tester, '/schedule/appt-2');
      await settle(tester, frames: 8);

      await tapKey(tester, 'appt-status-cancelled');
      await settle(tester, frames: 4);
      await tester.enterText(
        find.byKey(const ValueKey('appt-cancel-reason')),
        'Patient travelling',
      );
      await tapKey(tester, 'appt-cancel-confirm');
      await settle(tester, frames: 8);

      final a = await current('appt-2');
      expect(a.status, AppointmentStatus.cancelled);
      expect(a.cancelledReason, 'Patient travelling');
      // Cancelled slots can no longer be moved or messaged.
      expect(
        tester
            .widget<ButtonStyleButton>(find.byKey(const ValueKey('appt-move')))
            .enabled,
        isFalse,
      );
    });

    testWidgets('start visit opens a Visit linked to the appointment', (
      tester,
    ) async {
      final start = DateTime.now().add(const Duration(hours: 1));
      await env.repos.appointments.upsert(
        testCtx,
        _fixture(start, id: 'appt-3'),
      );
      await env.pumpApp(tester);
      await env.go(tester, '/schedule/appt-3');
      await settle(tester, frames: 8);

      await tapKey(tester, 'appt-start-visit');
      await settle(tester, frames: 10);

      final visit = await env.repos.appointments.openVisit(testPatientId);
      expect(visit, isNotNull);
      expect(visit!.appointmentId, 'appt-3');
      expect(visit.chiefComplaint, 'Review');
      expect((await current('appt-3')).status, AppointmentStatus.inChair);
      expect(env.location, '/patients/$testPatientId');
    });
  });
}
