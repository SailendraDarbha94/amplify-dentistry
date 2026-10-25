import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_env.dart';

/// Every path in the route contract, with fixture ids substituted.
const List<String> contractPaths = [
  '/today',
  '/patients',
  '/patients/new',
  '/patients/$testPatientId',
  '/patients/$testPatientId/edit',
  '/patients/$testPatientId/chart',
  '/patients/$testPatientId/chart/perio',
  '/patients/$testPatientId/plan',
  '/patients/$testPatientId/plan/plan-1',
  '/patients/$testPatientId/consent/new?procedureIds=p1,p2',
  '/patients/$testPatientId/consent/consent-1',
  '/patients/$testPatientId/notes',
  '/patients/$testPatientId/notes/new',
  '/patients/$testPatientId/prescriptions',
  '/patients/$testPatientId/prescriptions/new',
  '/patients/$testPatientId/billing',
  '/patients/$testPatientId/billing/invoice/new',
  '/patients/$testPatientId/billing/invoice/inv-1',
  '/schedule',
  '/schedule/new?patientId=$testPatientId&at=2026-10-25T10:00',
  '/schedule/appt-1',
  '/recall',
  '/lab',
  '/lab/new?patientId=$testPatientId',
  '/lab/case-1',
  '/more',
  '/settings',
  '/settings/clinic',
  '/settings/members',
  '/settings/gst',
  '/settings/chairs',
  '/settings/labs',
  '/settings/notation',
  '/settings/about',
  '/compliance',
  '/export',
  '/audit',
];

void main() {
  group('sessionRedirect', () {
    test(
      'fresh install goes to onboarding, onboarding goes home once set up',
      () {
        expect(
          sessionRedirect(hasClinic: false, location: '/today'),
          '/onboarding',
        );
        expect(
          sessionRedirect(hasClinic: false, location: '/onboarding'),
          isNull,
        );
        expect(
          sessionRedirect(hasClinic: true, location: '/onboarding'),
          '/today',
        );
        expect(sessionRedirect(hasClinic: true, location: '/patients'), isNull);
      },
    );
  });

  group('Router smoke', () {
    late AppTestEnv env;

    setUp(() async => env = await AppTestEnv.open(withPatient: true));
    tearDown(() => env.close());

    testWidgets('every contract path renders a page without throwing', (
      tester,
    ) async {
      await env.pumpApp(tester);
      for (final path in contractPaths) {
        await env.go(tester, path);
        final exception = tester.takeException();
        expect(exception, isNull, reason: 'navigating to $path threw');
        expect(
          find.byType(Scaffold),
          findsWidgets,
          reason: 'no page rendered for $path',
        );
        expect(
          env.location,
          Uri.parse(path).path,
          reason: 'router did not land on $path',
        );
        expect(
          find.text(MobileStrings.comingInThisBuild),
          findsNothing,
          reason: '$path still renders a placeholder page',
        );
      }
    });

    testWidgets('shell shows the four tabs and switches branches', (
      tester,
    ) async {
      await env.pumpApp(tester);
      expect(find.byType(NavigationBar), findsOneWidget);
      Finder tab(String label) => find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      );
      await tester.tap(tab('Patients'));
      await settle(tester);
      expect(env.location, '/patients');
      await tester.tap(tab('More'));
      await settle(tester);
      expect(env.location, '/more');
      await tester.tap(tab('Schedule'));
      await settle(tester);
      expect(env.location, '/schedule');
    });
  });
}
