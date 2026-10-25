import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/cloud_auth.dart' show readContinueOffline;
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/core/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'cloud_test_support.dart';

/// The sign-in gate: only when the cloud is configured, only on a fresh
/// install, and always skippable.
void main() {
  group('sessionRedirect', () {
    test('gates a fresh install only while the gate is up', () {
      expect(
        sessionRedirect(hasClinic: false, location: '/today', signInGate: true),
        '/sign-in',
      );
      expect(
        sessionRedirect(
          hasClinic: false,
          location: '/onboarding',
          signInGate: true,
        ),
        '/sign-in',
      );
      expect(
        sessionRedirect(
          hasClinic: false,
          location: '/sign-in',
          signInGate: true,
        ),
        isNull,
      );
      expect(
        sessionRedirect(hasClinic: false, location: '/today'),
        '/onboarding',
      );
      // Signing in later from settings is always reachable.
      expect(sessionRedirect(hasClinic: true, location: '/sign-in'), isNull);
      expect(
        sessionRedirect(hasClinic: true, location: '/today', signInGate: true),
        isNull,
      );
    });
  });

  group('cloud not configured', () {
    late AppTestEnv env;
    setUp(() async => env = await AppTestEnv.open(withClinic: false));
    tearDown(() => env.close());

    testWidgets('fresh install goes straight to onboarding', (tester) async {
      await env.pumpApp(tester);
      expect(env.location, '/onboarding');
      expect(env.container.read(signInGateProvider), isFalse);
    });

    testWidgets('account page says the cloud is not configured', (
      tester,
    ) async {
      await env.repos.clinics.createClinic(testCtx, testClinic());
      await env.repos.clinics.upsertMember(testCtx, testDentist());
      await env.container
          .read(appSessionProvider.notifier)
          .activate(
            clinics: env.repos.clinics,
            clinicId: testClinicId,
            memberId: testDentistId,
          );
      await env.pumpApp(tester);
      await env.go(tester, '/settings/account');
      expect(find.byKey(const ValueKey('account-not-configured')), findsOne);
      expect(find.text(MobileStrings.cloudNotConfigured), findsWidgets);
      expect(find.byKey(const ValueKey('account-sign-in')), findsNothing);
    });
  });

  group('cloud configured', () {
    late FakeSupabase fake;
    late AppTestEnv env;

    setUp(() async {
      fake = FakeSupabase();
      env = await openCloudEnv(fake, withClinic: false);
    });
    tearDown(() => env.close());

    testWidgets('fresh install is gated; continue offline reaches onboarding', (
      tester,
    ) async {
      await env.pumpApp(tester);
      expect(env.location, '/sign-in');
      expect(find.text(MobileStrings.signInOrContinueOffline), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('sign-in-continue-offline')));
      await settle(tester, frames: 10);
      expect(env.location, '/onboarding');
      expect(env.container.read(continueOfflineProvider), isTrue);
      // The choice is persisted for the next launch.
      expect(await readContinueOfflineFor(env), isTrue);
    });

    testWidgets('wrong password shows the server message and stays', (
      tester,
    ) async {
      await env.pumpApp(tester);
      await tester.enterText(
        find.byKey(const ValueKey('sign-in-email')),
        fake.email,
      );
      await tester.enterText(
        find.byKey(const ValueKey('sign-in-password')),
        'nope',
      );
      await tester.tap(find.byKey(const ValueKey('sign-in-submit')));
      await settle(tester, frames: 10);
      expect(env.location, '/sign-in');
      expect(find.byKey(const ValueKey('sign-in-error')), findsOneWidget);
      expect(find.text('Invalid login credentials'), findsOneWidget);
      expect(env.container.read(cloudAuthProvider).isSignedIn, isFalse);
    });

    testWidgets('sign-in with no clinic anywhere continues to onboarding', (
      tester,
    ) async {
      await env.pumpApp(tester);
      await tester.enterText(
        find.byKey(const ValueKey('sign-in-email')),
        fake.email,
      );
      await tester.enterText(
        find.byKey(const ValueKey('sign-in-password')),
        fake.password,
      );
      await tester.tap(find.byKey(const ValueKey('sign-in-submit')));
      await settle(tester, frames: 20);
      expect(env.container.read(cloudAuthProvider).isSignedIn, isTrue);
      expect(env.location, '/onboarding');
      expect(find.text(MobileStrings.setUpYourClinic), findsOneWidget);
    });

    testWidgets('phone OTP: send code, verify, signed in', (tester) async {
      await env.pumpApp(tester);
      await tester.tap(find.text('Phone'));
      await settle(tester);
      await tester.enterText(
        find.byKey(const ValueKey('sign-in-phone')),
        '9000000002',
      );
      await tester.tap(find.byKey(const ValueKey('sign-in-send-code')));
      await settle(tester, frames: 10);
      expect(find.byKey(const ValueKey('sign-in-code')), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('sign-in-code')),
        fake.otp,
      );
      await tester.tap(find.byKey(const ValueKey('sign-in-verify')));
      await settle(tester, frames: 20);
      expect(env.container.read(cloudAuthProvider).isSignedIn, isTrue);
      expect(env.location, '/onboarding');
    });
  });
}

/// Reads the persisted "continue offline" choice from the test database.
Future<bool> readContinueOfflineFor(AppTestEnv env) =>
    readContinueOffline(env.db);
