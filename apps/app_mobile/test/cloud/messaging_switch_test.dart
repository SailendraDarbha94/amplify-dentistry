import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_messaging/ampdent_messaging.dart';
import 'package:ampdent_mobile/core/clinic_link.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/core/whatsapp_cloud.dart';
import 'package:ampdent_mobile/features/recall/patient_messenger.dart';
import 'package:flutter_test/flutter_test.dart';

import 'cloud_test_support.dart';

/// The messaging provider follows the clinic's WhatsApp status: Cloud API
/// queue when enabled (no deep link opened, row stays queued for the
/// server), deep link otherwise.
void main() {
  late FakeSupabase fake;
  late AppTestEnv env;
  late List<Uri> launched;
  final now = DateTime.utc(2026, 10, 25, 10);

  setUp(() async {
    fake = FakeSupabase();
    launched = [];
    env = await openCloudEnv(fake, withPatient: true, launched: launched);
    await env.repos.consents.recordDataConsent(
      testCtx,
      DataConsent(
        id: 'dc-1',
        clinicId: testClinicId,
        patientId: testPatientId,
        purpose: DataPurpose.recallReminders,
        granted: true,
        noticeVersion: '1',
        languageCode: 'en',
        channel: 'inClinic',
        grantedAt: now,
        createdAt: now,
      ),
    );
  });
  tearDown(() => env.close());

  Future<PatientMessageResult> sendRecall() async {
    final patient = (await env.repos.patients.getById(testPatientId))!;
    return env.container
        .read(patientMessengerProvider)
        .send(
          patient: patient,
          clinic: testClinic(),
          template: templateByCode('RECALL_DUE')!,
          variables: const {'recall_type': 'scaling', 'due_date': '1 Nov 2026'},
        );
  }

  test('signed out or unlinked: deep link, status null', () async {
    expect(await env.container.read(whatsappStatusProvider.future), isNull);
    expect(env.container.read(messagingModeProvider), MessagingMode.deepLink);
    expect(
      env.container.read(messagingProvider),
      isA<LoggedMessagingProvider>(),
    );
  });

  test(
    'enabled on the server: cloud queue, no link opened, row queued',
    () async {
      fake.whatsappStatus = {
        ...fake.whatsappStatus,
        'configured': true,
        'enabled': true,
        'phoneNumberId': '123456789012345',
      };
      await signIn(env.container, fake);
      expect((await runLink(env.container)).phase, LinkPhase.linked);
      final status = await env.container.read(whatsappStatusProvider.future);
      expect(status?.isActive, isTrue);
      expect(env.container.read(messagingModeProvider), MessagingMode.cloudApi);
      expect(
        env.container.read(messagingProvider),
        isA<CloudQueueMessagingProvider>(),
      );

      final result = await sendRecall();
      expect(result.decision.allowed, isTrue);
      expect(result.queued, isTrue);
      expect(result.sent, isTrue);
      expect(result.launched, isFalse);
      expect(result.launchFailed, isFalse);
      expect(launched, isEmpty, reason: 'the server sends it');
      final stored = (await env.repos.messages.getById(result.log!.id))!;
      expect(stored.status, MessageStatus.queued);
      expect(
        MessageLogKeys.providerOf(stored),
        MessageLogKeys.cloudApiProvider,
      );
      expect(MessageLogKeys.optInReasonOf(stored), 'recall_reminders_consent');
      expect(stored.renderedPreview, isNot(contains('_provider')));

      // Paused on the server: back to the deep link.
      fake.whatsappStatus = {...fake.whatsappStatus, 'enabled': false};
      env.container.invalidate(whatsappStatusProvider);
      await env.container.read(whatsappStatusProvider.future);
      expect(env.container.read(messagingModeProvider), MessagingMode.deepLink);
      final again = await sendRecall();
      expect(again.queued, isFalse);
      expect(again.launched, isTrue);
      expect(launched, hasLength(1));
      expect(
        MessageLogKeys.providerOf(
          (await env.repos.messages.getById(again.log!.id))!,
        ),
        MessageLogKeys.deepLinkProvider,
      );
    },
  );

  test('cloud decider refuses a minor without a guardian phone', () async {
    fake.whatsappStatus = {
      ...fake.whatsappStatus,
      'configured': true,
      'enabled': true,
    };
    await signIn(env.container, fake);
    await runLink(env.container);
    await env.container.read(whatsappStatusProvider.future);
    final minor = await env.addPatient(
      testPatient(
        id: 'kid',
        firstName: 'Kiran',
        dateOfBirth: DateTime.utc(2016, 1, 1),
      ),
    );
    final provider = env.container.read(messagingProvider);
    await expectLater(
      provider.send(
        MessageRequest(
          clinicId: testClinicId,
          patientId: minor.id,
          toPhone: minor.phone,
          template: templateByCode('RECALL_DUE')!,
          variables: const {
            'patient_name': 'Kiran',
            'clinic_name': 'Smile',
            'recall_type': 'scaling',
            'due_date': '1 Nov',
            'clinic_phone': '040',
            'link': 'https://wa.me/1',
          },
        ),
      ),
      throwsA(isA<OptInRefusedException>()),
    );
    expect(await env.repos.messages.forPatient(minor.id), isEmpty);
  });
}
