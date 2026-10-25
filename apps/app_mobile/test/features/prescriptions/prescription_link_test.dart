import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_mobile/features/prescriptions/prescription_issuer.dart';
import 'package:ampdent_mobile/features/prescriptions/rx_model.dart';
import 'package:ampdent_mobile/features/recall/patient_messenger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../recall/feature_harness.dart';

/// The Rx link leaves the phone only through [PatientMessenger]: opt-in
/// policy, guardian routing for minors, and a message-log row that ends up
/// `sent` or `cancelled`, never stuck at `queued`.
void main() {
  late FeatureHarness h;
  late Prescription rx;

  Future<void> open(
    WidgetTester tester, {
    bool launchSucceeds = true,
    Patient Function(Patient)? patch,
  }) async {
    h = await FeatureHarness.open(
      launchSucceeds: launchSucceeds,
      initialLocation: '/patients/$testPatientId',
    );
    addTearDown(h.close);
    if (patch != null) {
      final patient = (await h.env.repos.patients.getById(testPatientId))!;
      await h.env.repos.patients.upsert(testCtx, patch(patient));
    }
    await h.env.repos.prescriptions.seedDrugMasterIfEmpty();
    final amox = (await h.env.repos.prescriptions.getDrug(
      seedId('drug', 'AMOX-500'),
    ))!;
    rx =
        await PrescriptionIssuer(
          prescriptions: h.env.repos.prescriptions,
          audit: h.env.repos.audit,
          ctx: testCtx,
          codeGenerator: () => 'ABC234',
        ).issue(
          draft: RxDraft(lines: [RxLineDraft.fromDrug(amox)]),
          patientId: testPatientId,
          prescriber: testDentist(),
          now: h.now.toUtc(),
        );
    await h.pumpApp(tester);
    await h.go(tester, '/patients/$testPatientId/prescriptions/${rx.id}');
    await settle(tester, frames: 10);
    expect(find.byKey(const ValueKey('rx-whatsapp')), findsOneWidget);
  }

  Future<void> grant(DataPurpose purpose) =>
      h.env.repos.consents.recordDataConsent(
        testCtx,
        DataConsent(
          id: 'dc-${purpose.name}',
          clinicId: testClinicId,
          patientId: testPatientId,
          purpose: purpose,
          granted: true,
          noticeVersion: '1',
          languageCode: 'en',
          channel: 'inClinic',
          grantedAt: h.now.toUtc(),
          createdAt: h.now.toUtc(),
        ),
      );

  Future<void> tapSend(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const ValueKey('rx-whatsapp')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rx-whatsapp')));
    await settle(tester, frames: 10);
  }

  testWidgets('without messaging consent nothing is sent or logged', (
    tester,
  ) async {
    await open(tester);
    await tapSend(tester);
    expect(h.launched, isEmpty);
    expect(await h.env.repos.messages.forPatient(testPatientId), isEmpty);
    expect(
      find.text(sendDenialText('transactional_consent_missing')),
      findsOneWidget,
    );
  });

  testWidgets('recall-reminder consent alone does not cover a document link', (
    tester,
  ) async {
    await open(tester);
    await grant(DataPurpose.recallReminders);
    await tapSend(tester);
    expect(h.launched, isEmpty);
    expect(await h.env.repos.messages.forPatient(testPatientId), isEmpty);
  });

  testWidgets('with treatment-records consent the link opens and the log row '
      'is marked sent', (tester) async {
    await open(tester);
    await grant(DataPurpose.treatmentRecords);
    await tapSend(tester);

    expect(h.launched, hasLength(1));
    final uri = h.launched.single;
    expect(uri.host, 'wa.me');
    expect(uri.path, '/919876543210');
    final body = uri.queryParameters['text']!;
    expect(body, contains('ampdent:rx:${rx.id}:ABC234'));
    expect(body, contains('Dr. A. Rao'));
    expect(body.toUpperCase(), isNot(contains('AMOXICILLIN')));

    final logs = await h.env.repos.messages.forPatient(testPatientId);
    expect(logs, hasLength(1));
    expect(logs.single.templateCode, 'PRESCRIPTION_LINK');
    expect(logs.single.status, MessageStatus.sent);
    expect(logs.single.toPhone, '+919876543210');
  });

  testWidgets('a failed launch leaves the log row cancelled, not queued', (
    tester,
  ) async {
    await open(tester, launchSucceeds: false);
    await grant(DataPurpose.treatmentRecords);
    await tapSend(tester);
    expect(h.launched, hasLength(1));
    final logs = await h.env.repos.messages.forPatient(testPatientId);
    expect(logs.single.status, MessageStatus.cancelled);
    expect(
      find.text('WhatsApp is not available on this phone'),
      findsOneWidget,
    );
  });

  testWidgets('a minor with no guardian phone is never messaged', (
    tester,
  ) async {
    await open(
      tester,
      patch: (p) => p.copyWith(dateOfBirth: DateTime.utc(2015, 6, 1)),
    );
    await grant(DataPurpose.treatmentRecords);
    await tapSend(tester);
    expect(h.launched, isEmpty);
    expect(await h.env.repos.messages.forPatient(testPatientId), isEmpty);
    expect(
      find.text(sendDenialText('minor_not_routed_to_guardian')),
      findsOneWidget,
    );
  });

  testWidgets('a minor with a guardian is messaged on the guardian phone', (
    tester,
  ) async {
    await open(
      tester,
      patch: (p) => p.copyWith(
        dateOfBirth: DateTime.utc(2015, 6, 1),
        guardianName: 'Lakshmi',
        guardianPhone: '+919123456789',
      ),
    );
    await grant(DataPurpose.treatmentRecords);
    await tapSend(tester);
    expect(h.launched.single.path, '/919123456789');
    final logs = await h.env.repos.messages.forPatient(testPatientId);
    expect(logs.single.toPhone, '+919123456789');
    expect(logs.single.status, MessageStatus.sent);
  });
}
