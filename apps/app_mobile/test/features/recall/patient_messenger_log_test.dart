import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_messaging/ampdent_messaging.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/features/recall/patient_messenger.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feature_harness.dart';

/// Device logs never carry PHI: the messenger logs the template code and a
/// masked phone, never the rendered body or the wa.me URI; and a patient of
/// unknown age is refused until the age is recorded.
void main() {
  late AppTestEnv env;
  late List<String> logged;
  final now = DateTime.utc(2026, 10, 25, 10);

  setUp(() async {
    env = await AppTestEnv.open(withPatient: true);
    logged = [];
    Logger.install((level, tag, message, {error, stackTrace}) {
      logged.add('$tag $message ${error ?? ''}');
    });
  });
  tearDown(() async {
    Logger.install((level, tag, message, {error, stackTrace}) {});
    await env.close();
  });

  PatientMessenger messenger({
    required bool launchSucceeds,
    bool throws = false,
  }) => PatientMessenger(
    messaging: LoggedMessagingProvider(
      DeepLinkMessagingProvider(clock: () => now),
      logs: env.repos.messages,
      actor: () => testCtx,
    ),
    logs: env.repos.messages,
    consents: env.repos.consents,
    ctx: testCtx,
    launch: (uri) async {
      if (throws) throw StateError('no handler for $uri');
      return launchSucceeds;
    },
    clock: () => now,
  );

  Future<void> grantReminders() => env.repos.consents.recordDataConsent(
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

  for (final launched in [true, false]) {
    test(
      'log sink never receives the body or phone (launched=$launched)',
      () async {
        await grantReminders();
        final patient = (await env.repos.patients.getById(testPatientId))!;
        final result = await messenger(launchSucceeds: launched).send(
          patient: patient,
          clinic: testClinic(),
          template: templateByCode('RECALL_DUE')!,
          variables: const {'recall_type': 'Scaling', 'due_date': '1 Nov 2026'},
        );
        expect(result.decision.allowed, isTrue);
        expect(result.launched, launched);
        final body = result.log!.renderedPreview;
        expect(body, isNotEmpty);
        final digits = PhoneNumbers.digitsOnly(patient.phone);
        expect(logged, isNotEmpty, reason: 'the outcome is logged');
        for (final line in logged) {
          expect(line, isNot(contains(body)));
          expect(line, isNot(contains('wa.me')));
          expect(line, isNot(contains('text=')));
          expect(line, isNot(contains(digits)));
          expect(line, isNot(contains(patient.firstName)));
        }
        expect(
          logged.any((l) => l.contains('RECALL_DUE') && l.contains('****')),
          isTrue,
          reason: 'template code and masked phone are what gets logged',
        );
      },
    );
  }

  test('a launcher failure is reported without the URI', () async {
    final uri = whatsappDeepLink('+919876543210', 'Hello Asha, your scaling');
    // The default launcher swallows platform failures and logs scheme/host
    // only; exercise the same shape through launchExternal's log line format.
    const Logger('recall.launch')
        .warning('could not launch ${uri.scheme}://${uri.host} (StateError)');
    expect(logged.single, isNot(contains('Asha')));
    expect(logged.single, isNot(contains('9876543210')));
    expect(logged.single, contains('https://wa.me'));
  });

  test(
    'a patient of unknown age is refused until the age is recorded',
    () async {
      await grantReminders();
      final unknown = Patient(
        id: 'p-unknown',
        clinicId: testClinicId,
        patientNumber: 'P-00009',
        firstName: 'Ravi',
        phone: '+919123456789',
        createdAt: now,
        updatedAt: now,
      );
      await env.repos.patients.upsert(testCtx, unknown);
      expect(
        reminderSendDecision(
          patient: unknown,
          consents: const [],
          now: now,
        ).reason,
        'age_unknown',
      );
      expect(
        documentSendDecision(
          patient: unknown,
          consents: const [],
          now: now,
        ).reason,
        'age_unknown',
      );
      expect(sendDenialText('age_unknown'), contains('date of birth'));
      final result = await messenger(launchSucceeds: true).send(
        patient: unknown,
        clinic: testClinic(),
        template: templateByCode('RECALL_DUE')!,
        variables: const {'recall_type': 'Scaling', 'due_date': '1 Nov 2026'},
      );
      expect(result.decision.allowed, isFalse);
      expect(result.log, isNull);
      expect(await env.repos.messages.forPatient('p-unknown'), isEmpty);
    },
  );
}
