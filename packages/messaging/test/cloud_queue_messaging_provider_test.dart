import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_messaging/ampdent_messaging.dart';
import 'package:test/test.dart';

final DateTime _now = DateTime.utc(2026, 10, 25, 9, 30);

MessageRequest _request({String code = 'APPT_REMINDER_24H'}) => MessageRequest(
  clinicId: 'clinic-1',
  patientId: 'patient-1',
  toPhone: '98765 43210',
  template: templateByCode(code)!,
  variables: const {
    'patient_name': 'Ravi',
    'clinic_name': 'Oasis Dental',
    'appointment_date': 'Mon 20 Oct',
    'appointment_time': '10:30 AM',
    'doctor_name': 'Asha Rao',
    'clinic_phone': '+91 98765 43210',
    'recall_type': 'scaling',
    'due_date': '1 Nov',
    'link': 'https://p.ampdent.in/r/1',
  },
);

DataConsent _consent(DataPurpose purpose, {DateTime? withdrawnAt}) =>
    DataConsent(
      id: 'dc-${purpose.name}',
      clinicId: 'clinic-1',
      patientId: 'patient-1',
      purpose: purpose,
      granted: true,
      grantedAt: _now,
      withdrawnAt: withdrawnAt,
      noticeVersion: 'v1',
      languageCode: 'en',
      channel: 'app',
      createdAt: _now,
    );

void main() {
  group('CloudQueueMessagingProvider', () {
    test(
      'queues a cloud_api row through the sink after opt-in allows',
      () async {
        final sunk = <MessageLog>[];
        var counter = 0;
        final provider = CloudQueueMessagingProvider(
          (log) async => sunk.add(log),
          decide: (request) => OptInPolicy.canSend(
            category: request.category,
            consents: [_consent(DataPurpose.appointmentReminders)],
            isMinorRoutedToGuardian: false,
          ),
          idGenerator: () => 'cq-${++counter}',
          clock: () => _now,
        );

        final log = await provider.send(_request());
        expect(sunk, hasLength(1));
        expect(identical(sunk.single, log), isTrue);
        expect(log.id, 'cq-1');
        expect(log.status, MessageStatus.queued);
        expect(log.providerMessageId, isNull);
        expect(log.toPhone, '+919876543210');
        expect(log.templateCode, 'APPT_REMINDER_24H');
        expect(log.renderedPreview, startsWith('Reminder: Ravi'));
        expect(log.renderedPreview, isNot(contains('{')));
        expect(log.createdAt, _now);
        expect(log.costPaise, estimateCostPaise(MessageCategory.utility));

        expect(MessageLogKeys.providerOf(log), MessageLogKeys.cloudApiProvider);
        expect(MessageLogKeys.isCloudApi(log), isTrue);
        expect(
          MessageLogKeys.optInReasonOf(log),
          'appointment_reminders_consent',
        );
        expect(log.variables['patient_name'], 'Ravi');
        expect(
          MessageLogKeys.templateOnly(log.variables).keys,
          isNot(anyElement(startsWith('_'))),
        );
        // The queued row can be turned into the exact Meta payload later.
        expect(metaPayloadForLog(log)['to'], '919876543210');
      },
    );

    test('refuses when opt-in denies and writes nothing', () async {
      var sinkCalls = 0;
      final provider = CloudQueueMessagingProvider(
        (log) async => sinkCalls++,
        decide: (request) => OptInPolicy.canSend(
          category: request.category,
          consents: const [],
          isMinorRoutedToGuardian: false,
        ),
      );
      await expectLater(
        provider.send(_request()),
        throwsA(
          isA<OptInRefusedException>()
              .having(
                (e) => e.reason,
                'reason',
                'transactional_consent_missing',
              )
              .having((e) => e.templateCode, 'code', 'APPT_REMINDER_24H')
              .having((e) => e.decision.allowed, 'allowed', isFalse),
        ),
      );
      expect(sinkCalls, 0);
    });

    test('marketing to a guardian-routed minor is refused', () async {
      var sinkCalls = 0;
      final provider = CloudQueueMessagingProvider(
        (log) async => sinkCalls++,
        decide: (request) async => OptInPolicy.canSend(
          category: request.category,
          consents: [_consent(DataPurpose.marketing)],
          isMinorRoutedToGuardian: true,
        ),
      );
      final marketing = _request(code: 'RECALL_DUE')
          .copyWith(category: MessageCategory.marketing);
      await expectLater(
        provider.send(marketing),
        throwsA(
          isA<OptInRefusedException>().having(
            (e) => e.reason,
            'reason',
            'marketing_to_minor_forbidden',
          ),
        ),
      );
      expect(sinkCalls, 0);
    });

    test('render and phone errors surface before the sink is called', () async {
      var sinkCalls = 0;
      final provider = CloudQueueMessagingProvider(
        (log) async => sinkCalls++,
        decide: (_) => const SendDecision.allow('test'),
      );
      await expectLater(
        provider.send(_request().copyWith(variables: const {})),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        provider.send(_request().copyWith(toPhone: '12345')),
        throwsA(isA<FormatException>()),
      );
      expect(sinkCalls, 0);
    });

    test(
      'status prefers the injected lookup, then local, then queued',
      () async {
        final statuses = <String, MessageStatus>{'wamid.1': MessageStatus.read};
        final provider = CloudQueueMessagingProvider(
          (log) async {},
          decide: (_) => const SendDecision.allow('test'),
          statusLookup: (id) async => statuses[id],
          idGenerator: () => 'cq-1',
        );
        final log = await provider.send(_request());
        expect(await provider.status('wamid.1'), MessageStatus.read);
        expect(await provider.status(log.id), MessageStatus.queued);
        statuses[log.id] = MessageStatus.delivered;
        expect(await provider.status(log.id), MessageStatus.delivered);
        expect(await provider.status('unknown'), MessageStatus.queued);
      },
    );

    test('default id generator yields UUID v4 ids', () async {
      final provider = CloudQueueMessagingProvider(
        (log) async {},
        decide: (_) => const SendDecision.allow('test'),
      );
      final log = await provider.send(_request());
      expect(isValidId(log.id), isTrue);
    });
  });

  group('MessageLogKeys', () {
    test('deep-link rows are stamped so sync skips them', () async {
      final provider = DeepLinkMessagingProvider(clock: () => _now);
      final log = await provider.send(_request());
      expect(MessageLogKeys.providerOf(log), MessageLogKeys.deepLinkProvider);
      expect(MessageLogKeys.isCloudApi(log), isFalse);
      expect(MessageLogKeys.optInReasonOf(log), isNull);
    });

    test(
      'unstamped rows count as cloud_api; stamp adds without clobbering',
      () {
        final plain = _request().toLog(id: 'x', now: _now);
        expect(MessageLogKeys.providerOf(plain), isNull);
        expect(MessageLogKeys.isCloudApi(plain), isTrue);
        final stamped = MessageLogKeys.stamp(
          plain.variables,
          providerName: 'cloud_api',
          reason: 'r',
        );
        expect(stamped['_provider'], 'cloud_api');
        expect(stamped['_opt_in_reason'], 'r');
        expect(stamped['patient_name'], 'Ravi');
        expect(MessageLogKeys.templateOnly(stamped), plain.variables);
      },
    );

    test('no default template declares a reserved (underscore) variable', () {
      for (final t in defaultTemplates) {
        expect(t.variables, isNot(anyElement(startsWith('_'))));
      }
    });
  });
}
