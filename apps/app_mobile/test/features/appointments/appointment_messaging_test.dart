import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/features/appointments/appointment_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'appointments_test_env.dart';

void main() {
  final now = DateTime(2026, 10, 25, 9);
  setUpAll(() => initializeDateFormatting('en_IN'));

  group('AppointmentMessenger.decide', () {
    test('denies without consent, allows with reminder consent', () {
      final adult = testPatient();
      expect(
        AppointmentMessenger.decide(
          patient: adult,
          consents: const [],
          now: now,
        ).allowed,
        isFalse,
      );
      expect(
        AppointmentMessenger.decide(
          patient: adult,
          consents: [reminderConsent(adult.id)],
          now: now,
        ).reason,
        'appointment_reminders_consent',
      );
    });

    test('routes a minor to the guardian phone and refuses one without', () {
      final minor = testPatient(
        id: 'kid',
        firstName: 'Kiran',
        dateOfBirth: DateTime.utc(2016, 1, 1),
      );
      expect(
        AppointmentMessenger.decide(
          patient: minor,
          consents: [reminderConsent(minor.id)],
          now: now,
        ).reason,
        'minor_not_routed_to_guardian',
      );
      final withGuardian = minor.copyWith(
        guardianName: 'Lakshmi',
        guardianPhone: '+919123456789',
      );
      expect(
        AppointmentMessenger.decide(
          patient: withGuardian,
          consents: [reminderConsent(minor.id)],
          now: now,
        ).allowed,
        isTrue,
      );
      final request = AppointmentMessenger.buildRequest(
        kind: AppointmentMessageKind.reminder24h,
        appointment: testAppointment(
          DateTime(2026, 10, 26, 10),
          patientId: 'kid',
        ),
        patient: withGuardian,
        clinic: testClinic(),
        provider: testDentist(),
        now: now,
      );
      expect(request.toPhone, '+919123456789');
      expect(request.template.code, 'APPT_REMINDER_24H');
      final body = request.render();
      expect(body, contains('Kiran Rao'));
      expect(body, contains('Dr. A. Rao'));
      expect(body, isNot(contains('Dr. Dr.')));
      expect(body, contains('26 Oct 2026'));
      // Utility template: no clinical content, no "AI" wording.
      expect(body.toLowerCase(), isNot(contains('ai detects')));
    });
  });

  group('Appointment messaging buttons', () {
    late ApptTestEnv env;

    setUp(() async => env = await ApptTestEnv.open());
    tearDown(() => env.close());

    testWidgets('reminder is disabled without consent, enabled after', (
      tester,
    ) async {
      final start = DateTime.now().add(const Duration(days: 1));
      await env.repos.appointments.upsert(
        testCtx,
        testAppointment(start, id: 'appt-msg', reason: 'Scaling'),
      );
      await env.pumpApp(tester);
      await env.go(tester, '/schedule/appt-msg');
      await settle(tester, frames: 8);

      final reminder = find.byKey(const ValueKey('appt-send-reminder'));
      expect(reminder, findsOneWidget);
      expect(tester.widget<ButtonStyleButton>(reminder).enabled, isFalse);
      expect(
        tester
            .widget<ButtonStyleButton>(
              find.byKey(const ValueKey('appt-send-confirmation')),
            )
            .enabled,
        isFalse,
      );
      expect(
        find.byKey(const ValueKey('appt-messaging-blocked')),
        findsOneWidget,
      );

      await env.repos.consents.recordDataConsent(
        testCtx,
        reminderConsent(testPatientId),
      );
      await settle(tester, frames: 8);
      expect(tester.widget<ButtonStyleButton>(reminder).enabled, isTrue);
      expect(
        find.byKey(const ValueKey('appt-messaging-blocked')),
        findsNothing,
      );

      await tapKey(tester, 'appt-send-reminder');
      await settle(tester, frames: 10);

      expect(env.launched, hasLength(1));
      expect(env.launched.single.host, 'wa.me');
      expect(env.launched.single.path, '/919876543210');
      expect(env.launched.single.queryParameters['text'], contains('Asha Rao'));

      final a = await env.repos.appointments.getById('appt-msg');
      expect(a!.reminder24hSentAt, isNotNull);
      final logs = await env.repos.messages.forPatient(testPatientId);
      expect(logs, hasLength(1));
      expect(logs.single.templateCode, 'APPT_REMINDER_24H');
      expect(logs.single.status, MessageStatus.sent);
      expect(logs.single.toPhone, '+919876543210');
      expect(logs.single.channel, MessageChannel.whatsapp);
      expect(find.text('Resend reminder'), findsOneWidget);
    });

    testWidgets('confirmation logs APPT_CONFIRM without stamping a reminder', (
      tester,
    ) async {
      final start = DateTime.now().add(const Duration(days: 1));
      await env.repos.appointments.upsert(
        testCtx,
        testAppointment(start, id: 'appt-msg'),
      );
      await env.repos.consents.recordDataConsent(
        testCtx,
        reminderConsent(testPatientId),
      );
      await env.pumpApp(tester);
      await env.go(tester, '/schedule/appt-msg');
      await settle(tester, frames: 8);

      await tapKey(tester, 'appt-send-confirmation');
      await settle(tester, frames: 10);

      expect(env.launched, hasLength(1));
      final logs = await env.repos.messages.forPatient(testPatientId);
      expect(logs.single.templateCode, 'APPT_CONFIRM');
      final a = await env.repos.appointments.getById('appt-msg');
      expect(a!.reminder24hSentAt, isNull);
    });

    testWidgets('minor is messaged on the guardian phone', (tester) async {
      final kid = await env.addPatient(
        testPatient(
          id: 'kid',
          firstName: 'Kiran',
          phone: '+919000000011',
          dateOfBirth: DateTime.utc(2016, 1, 1),
        ).copyWith(guardianName: 'Lakshmi', guardianPhone: '+919123456789'),
      );
      await env.repos.consents.recordDataConsent(
        testCtx,
        reminderConsent(kid.id),
      );
      await env.repos.appointments.upsert(
        testCtx,
        testAppointment(
          DateTime.now().add(const Duration(days: 1)),
          id: 'appt-kid',
          patientId: kid.id,
        ),
      );
      await env.pumpApp(tester);
      await env.go(tester, '/schedule/appt-kid');
      await settle(tester, frames: 8);
      expect(
        find.textContaining('Minor: messages go to the guardian'),
        findsOneWidget,
      );

      await tapKey(tester, 'appt-send-reminder');
      await settle(tester, frames: 10);
      expect(env.launched.single.path, '/919123456789');
    });
  });
}
