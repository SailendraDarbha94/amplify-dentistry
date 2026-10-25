import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/features/patients/patient_form_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_env.dart';

void main() {
  final now = DateTime(2026, 10, 25);

  group('patientIsMinor', () {
    test('DOB ten years ago is a minor', () {
      expect(
        patientIsMinor(dateOfBirth: DateTime(2016, 10, 25), now: now),
        isTrue,
      );
    });

    test('DOB thirty years ago is an adult', () {
      expect(
        patientIsMinor(dateOfBirth: DateTime(1996, 1, 1), now: now),
        isFalse,
      );
    });

    test('DOB or an approximate age is required', () {
      expect(
        PatientValidators.approxAge('', required: true),
        PatientStrings.ageRequired,
      );
      expect(PatientValidators.approxAge('', required: false), isNull);
      expect(PatientValidators.approxAge('42', required: true), isNull);
      expect(PatientValidators.approxAge('abc', required: true), isNotNull);
    });

    test('approximate age is used when DOB is unknown', () {
      expect(patientIsMinor(approxAgeYears: 10, now: now), isTrue);
      expect(patientIsMinor(approxAgeYears: 18, now: now), isFalse);
      expect(patientIsMinor(now: now), isFalse);
    });
  });

  group('PatientValidators', () {
    test('guardian fields required only for minors', () {
      expect(
        PatientValidators.guardianName('', required: true),
        MobileStrings.guardianRequiredForMinor,
      );
      expect(PatientValidators.guardianName('', required: false), isNull);
      expect(
        PatientValidators.guardianPhone('', required: true),
        MobileStrings.guardianRequiredForMinor,
      );
      expect(PatientValidators.guardianPhone('12', required: false), isNotNull);
      expect(
        PatientValidators.guardianPhone('9876543210', required: true),
        isNull,
      );
    });

    test('phone must be an Indian mobile', () {
      expect(PatientValidators.phone('98765 43210'), isNull);
      expect(PatientValidators.phone('040 2345 6789'), isNotNull);
      expect(PatientValidators.phone(''), isNotNull);
    });
  });

  group('PatientSaver', () {
    late AppTestEnv env;

    setUp(() async => env = await AppTestEnv.open());
    tearDown(() => env.close());

    test(
      'refuses a minor without guardian and mints a patient number',
      () async {
        final saver = PatientSaver(
          patients: env.repos.patients,
          consents: env.repos.consents,
          clinics: env.repos.clinics,
          ctx: testCtx,
        );
        final minor = PatientFormData(
          firstName: 'Kiran',
          phone: '9876543210',
          dateOfBirth: DateTime(2016, 10, 25),
        );
        await expectLater(saver.save(minor, now: now), throwsStateError);
        // Unknown age is never saved as an adult: it must be resolved first.
        await expectLater(
          saver.save(
            const PatientFormData(firstName: 'Ravi', phone: '9876543211'),
            now: now,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              PatientStrings.ageRequired,
            ),
          ),
        );
        expect(await env.repos.patients.count(testClinicId), 0);

        final saved = await saver.save(
          PatientFormData(
            firstName: 'Kiran',
            phone: '9876543210',
            dateOfBirth: DateTime(2016, 10, 25),
            guardianName: 'Lakshmi',
            guardianRelation: 'Mother',
            guardianPhone: '9123456789',
            consents: const {
              DataPurpose.appointmentReminders: true,
              DataPurpose.marketing: false,
            },
          ),
          now: now,
        );
        expect(saved.patientNumber, 'P-00001');
        expect(saved.phone, '+919876543210');
        expect(saved.guardianPhone, '+919123456789');
        expect(saved.messagingPhone(now), '+919123456789');
        final consents = await env.repos.consents.latestDataConsents(saved.id);
        expect(consents[DataPurpose.appointmentReminders]?.isActive, isTrue);
        expect(consents.containsKey(DataPurpose.marketing), isFalse);
      },
    );
  });

  group('Patient form', () {
    late AppTestEnv env;

    setUp(() async => env = await AppTestEnv.open());
    tearDown(() => env.close());

    /// Scrolls the form until [finder] is built and visible.
    Future<void> reveal(WidgetTester tester, Finder finder) async {
      await tester.scrollUntilVisible(
        finder,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await settle(tester, frames: 2);
    }

    Future<void> scrollToTop(WidgetTester tester) async {
      await tester.fling(find.byType(ListView), const Offset(0, 1200), 2000);
      await settle(tester);
    }

    testWidgets('guardian becomes mandatory for a ten-year-old', (
      tester,
    ) async {
      await env.pumpApp(tester);
      await env.go(tester, '/patients/new');
      expect(find.byKey(const ValueKey('patient-first-name')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('patient-guardian-required')),
        findsNothing,
      );

      await tester.enterText(
        find.byKey(const ValueKey('patient-first-name')),
        'Kiran',
      );
      await tester.enterText(
        find.byKey(const ValueKey('patient-phone')),
        '9876543210',
      );
      await tester.enterText(
        find.byKey(const ValueKey('patient-approx-age')),
        '10',
      );
      await settle(tester);
      await reveal(
        tester,
        find.byKey(const ValueKey('patient-guardian-section')),
      );
      expect(
        find.byKey(const ValueKey('patient-guardian-required')),
        findsOneWidget,
      );

      // The save button is pinned at the bottom, outside the scroll view.
      await tester.tap(find.byKey(const ValueKey('patient-save')));
      await settle(tester);
      expect(find.text(MobileStrings.guardianRequiredForMinor), findsWidgets);
      expect(await env.repos.patients.count(testClinicId), 0);

      await reveal(tester, find.byKey(const ValueKey('patient-guardian-name')));
      await tester.enterText(
        find.byKey(const ValueKey('patient-guardian-name')),
        'Lakshmi',
      );
      await tester.enterText(
        find.byKey(const ValueKey('patient-guardian-phone')),
        '9123456789',
      );
      await tester.tap(find.byKey(const ValueKey('patient-save')));
      await settle(tester, frames: 12);

      final saved = await env.repos.patients.search(testClinicId, 'Kiran');
      expect(saved, hasLength(1));
      expect(saved.first.guardianName, 'Lakshmi');
      expect(saved.first.approxAgeYears, 10);
      expect(env.location, '/patients/${saved.first.id}');
    });

    testWidgets('neither DOB nor age blocks the save', (tester) async {
      await env.pumpApp(tester);
      await env.go(tester, '/patients/new');
      await tester.enterText(
        find.byKey(const ValueKey('patient-first-name')),
        'Ravi',
      );
      await tester.enterText(
        find.byKey(const ValueKey('patient-phone')),
        '9123456789',
      );
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('patient-save')));
      await settle(tester);
      expect(find.text(PatientStrings.ageRequired), findsOneWidget);
      expect(await env.repos.patients.count(testClinicId), 0);
    });

    testWidgets('adult saves without guardian', (tester) async {
      await env.pumpApp(tester);
      await env.go(tester, '/patients/new');
      await tester.enterText(
        find.byKey(const ValueKey('patient-first-name')),
        'Ravi',
      );
      await tester.enterText(
        find.byKey(const ValueKey('patient-phone')),
        '9123456789',
      );
      await tester.enterText(
        find.byKey(const ValueKey('patient-approx-age')),
        '42',
      );
      await settle(tester);
      await reveal(
        tester,
        find.byKey(const ValueKey('patient-guardian-section')),
      );
      expect(
        find.byKey(const ValueKey('patient-guardian-required')),
        findsNothing,
      );
      await scrollToTop(tester);
      await tester.tap(find.byKey(const ValueKey('patient-save')));
      await settle(tester, frames: 12);
      expect(await env.repos.patients.count(testClinicId), 1);
    });
  });
}
