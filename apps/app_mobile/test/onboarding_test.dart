import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/session.dart';
import 'package:ampdent_mobile/features/onboarding/onboarding_controller.dart';
import 'package:ampdent_mobile/features/onboarding/onboarding_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_env.dart';

void main() {
  group('OnboardingValidators', () {
    test('registration number is mandatory', () {
      expect(
        OnboardingValidators.registrationNumber(''),
        MobileStrings.registrationNumberRequired,
      );
      expect(
        OnboardingValidators.registrationNumber('   '),
        MobileStrings.registrationNumberRequired,
      );
      expect(OnboardingValidators.registrationNumber('A-12345'), isNull);
    });

    test('indian mobile accepts 10 digits with or without +91', () {
      expect(OnboardingValidators.indianMobile('9876543210'), isNull);
      expect(OnboardingValidators.indianMobile('+91 98765 43210'), isNull);
      expect(OnboardingValidators.indianMobile('12345'), isNotNull);
      expect(OnboardingValidators.indianMobile('', optional: true), isNull);
      expect(OnboardingValidators.indianMobile(''), isNotNull);
    });

    test('pincode, upi and gstin are optional but checked when present', () {
      expect(OnboardingValidators.pincode(''), isNull);
      expect(OnboardingValidators.pincode('500034'), isNull);
      expect(OnboardingValidators.pincode('12'), isNotNull);
      expect(OnboardingValidators.upiVpa('smile@upi'), isNull);
      expect(OnboardingValidators.upiVpa('nope'), isNotNull);
      expect(OnboardingValidators.gstin('36ABCDE1234F1Z5'), isNull);
      expect(OnboardingValidators.gstin('36abc'), isNotNull);
    });
  });

  group('OnboardingService', () {
    late AppTestEnv env;

    setUp(() async => env = await AppTestEnv.open(withClinic: false));
    tearDown(() => env.close());

    test('creates clinic, owner dentist, chairs and defaults', () async {
      final service = OnboardingService(env.repos, deviceId: testDeviceId);
      final result = await service.submit(
        const OnboardingDraft(
          clinicName: 'Smile Dental',
          city: 'Hyderabad',
          stateCode: '36',
          phone: '040 1234 5678',
          whatsappPhone: '9000000001',
          dentistName: 'Dr. A. Rao',
          qualifications: 'BDS, MDS',
          registrationNumber: 'A-12345',
          chairCount: 3,
        ),
      );
      final clinic = await env.repos.clinics.getClinic(result.clinicId);
      expect(clinic?.name, 'Smile Dental');
      expect(clinic?.whatsappPhone, '+919000000001');
      final member = await env.repos.clinics.getMember(result.memberId);
      expect(member?.role, ClinicRole.ownerDentist);
      expect(member?.registrationNumber, 'A-12345');
      expect(member?.registrationCouncil, 'Telangana State Dental Council');
      expect(member?.qualifications, ['BDS', 'MDS']);
      expect(await env.repos.clinics.chairs(result.clinicId), hasLength(3));
      expect(await env.repos.clinics.loadGstRates(result.clinicId), isNotEmpty);
      expect(
        await env.repos.clinics.nextPatientNumber(
          ActorContext(
            clinicId: result.clinicId,
            actorId: result.memberId,
            deviceId: testDeviceId,
          ),
        ),
        'P-00001',
      );
    });
  });

  group('Onboarding flow', () {
    late AppTestEnv env;

    setUp(() async => env = await AppTestEnv.open(withClinic: false));
    tearDown(() => env.close());

    Future<void> fillClinicStep(WidgetTester tester) async {
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-clinic-name')),
        'Smile Dental',
      );
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-city')),
        'Hyderabad',
      );
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-phone')),
        '9000000001',
      );
      await tester.tap(find.byKey(const ValueKey('onboarding-state')));
      await settle(tester);
      // The dropdown menu lays its items out lazily; scroll to Telangana.
      await tester.scrollUntilVisible(
        find.text('Telangana (36)'),
        120,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Telangana (36)').last);
      await settle(tester);
    }

    testWidgets('fresh install lands on onboarding', (tester) async {
      await env.pumpApp(tester);
      expect(find.text(MobileStrings.setUpYourClinic), findsOneWidget);
      expect(find.byKey(const ValueKey('onboarding-clinic-name')), findsOne);
    });

    testWidgets('clinic step blocks until required fields are filled', (
      tester,
    ) async {
      await env.pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await settle(tester);
      expect(find.text('Clinic name is required'), findsOneWidget);
      expect(find.text('Step 1 of 3: Clinic'), findsOneWidget);
    });

    testWidgets('registration number is required on the dentist step', (
      tester,
    ) async {
      await env.pumpApp(tester);
      await fillClinicStep(tester);
      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await settle(tester);
      expect(find.text('Step 2 of 3: Dentist'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('onboarding-dentist-name')),
        'Dr. A. Rao',
      );
      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await settle(tester);
      expect(
        find.text(MobileStrings.registrationNumberRequired),
        findsOneWidget,
      );
      expect(find.text('Step 2 of 3: Dentist'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('onboarding-registration')),
        'A-12345',
      );
      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await settle(tester);
      expect(find.text('Step 3 of 3: Chairs'), findsOneWidget);
    });

    testWidgets('completing the flow creates the clinic and goes home', (
      tester,
    ) async {
      await env.pumpApp(tester);
      await fillClinicStep(tester);
      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await settle(tester);
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-dentist-name')),
        'Dr. A. Rao',
      );
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-registration')),
        'A-12345',
      );
      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('onboarding-chairs-plus')));
      await settle(tester);
      expect(find.text('2'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await settle(tester, frames: 12);

      final clinics = await listLocalClinics(env.db);
      expect(clinics, hasLength(1));
      expect(await env.repos.clinics.chairs(clinics.first.id), hasLength(2));
      final session = env.container.read(appSessionProvider);
      expect(session.clinicId, clinics.first.id);
      expect(env.location, '/today');
      final deviceId = decodeStringSetting(
        await env.repos.clinics.getSetting(
          clinics.first.id,
          AppSettingKeys.deviceId,
        ),
      );
      expect(deviceId, testDeviceId);
    });
  });
}
