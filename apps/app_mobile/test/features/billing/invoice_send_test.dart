import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/features/billing/billing_strings.dart';
import 'package:ampdent_mobile/features/recall/patient_messenger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'billing_fixtures.dart';
import 'billing_test_env.dart';

/// The invoice link leaves the phone only through [PatientMessenger]: the
/// opt-in policy applies and the message-log row ends `sent` or `cancelled`,
/// never stuck at `queued`.
void main() {
  late BillingTestEnv env;
  late Invoice invoice;

  Future<void> open(WidgetTester tester, {bool launchSucceeds = true}) async {
    env = await BillingTestEnv.open(launchSucceeds: launchSucceeds);
    addTearDown(env.close);
    invoice = await issueFixtureInvoice(env, await seedTwoProcedures(env));
    await env.pump(
      tester,
      '/patients/$testPatientId/billing/invoice/${invoice.id}',
    );
    await settle(tester, frames: 10);
  }

  Future<void> grantReminders() => env.repos.consents.recordDataConsent(
    testCtx,
    DataConsent(
      id: 'dc-appt',
      clinicId: testClinicId,
      patientId: testPatientId,
      purpose: DataPurpose.appointmentReminders,
      granted: true,
      noticeVersion: '1',
      languageCode: 'en',
      channel: 'inClinic',
      grantedAt: billingNow.toUtc(),
      createdAt: billingNow.toUtc(),
    ),
  );

  Future<void> tapSend(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('invoice-send')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester, frames: 2);
    await tester.tap(find.byKey(const ValueKey('invoice-send')));
    await settle(tester, frames: 10);
  }

  testWidgets('without messaging consent nothing is sent or logged', (
    tester,
  ) async {
    await open(tester);
    await tapSend(tester);
    expect(env.launched, isEmpty);
    expect(await env.repos.messages.forPatient(testPatientId), isEmpty);
    expect(
      find.text(sendDenialText('transactional_consent_missing')),
      findsOneWidget,
    );
  });

  testWidgets('with consent the log row is closed as sent', (tester) async {
    await open(tester);
    await grantReminders();
    await tapSend(tester);
    expect(env.launched, hasLength(1));
    expect(env.launched.single.host, 'wa.me');
    final logs = await env.repos.messages.forPatient(testPatientId);
    expect(logs.single.templateCode, 'INVOICE_LINK');
    expect(logs.single.status, MessageStatus.sent);
    expect(logs.single.renderedPreview, contains(invoice.number));
    expect(logs.single.renderedPreview, isNot(contains('Root canal')));
    expect(find.text(BillingStrings.linkSent), findsOneWidget);
  });

  testWidgets('when WhatsApp does not open the row is cancelled', (
    tester,
  ) async {
    await open(tester, launchSucceeds: false);
    await grantReminders();
    await tapSend(tester);
    final logs = await env.repos.messages.forPatient(testPatientId);
    expect(logs.single.status, MessageStatus.cancelled);
    expect(logs.single.error, 'launch_failed');
    expect(find.text(BillingStrings.couldNotOpenApp), findsOneWidget);
  });
}
