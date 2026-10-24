import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_messaging/ampdent_messaging.dart';
import 'package:test/test.dart';

final DateTime _now = DateTime.utc(2026, 10, 18, 9, 30);

MessageRequest _request({
  String code = 'APPT_CONFIRM',
  String phone = '98765 43210',
  Map<String, String>? variables,
}) => MessageRequest(
  clinicId: 'clinic-1',
  patientId: 'patient-1',
  toPhone: phone,
  template: templateByCode(code)!,
  variables:
      variables ??
      const {
        'patient_name': 'Ravi',
        'clinic_name': 'Oasis Dental',
        'appointment_date': 'Mon 20 Oct',
        'appointment_time': '10:30 AM',
        'doctor_name': 'Asha Rao',
        'clinic_phone': '+91 98765 43210',
      },
);

void main() {
  group('MessageRequest', () {
    test('category defaults to the template and can be overridden', () {
      expect(_request().category, MessageCategory.utility);
      final overridden = MessageRequest(
        clinicId: 'c',
        toPhone: '9876543210',
        template: templateByCode('RECALL_DUE')!,
        category: MessageCategory.marketing,
      );
      expect(overridden.category, MessageCategory.marketing);
      expect(overridden.channel, MessageChannel.whatsapp);
    });

    test('toLog normalises the phone, renders and estimates cost', () {
      final log = _request().toLog(id: 'log-1', now: _now);
      expect(log.id, 'log-1');
      expect(log.toPhone, '+919876543210');
      expect(log.status, MessageStatus.queued);
      expect(log.templateCode, 'APPT_CONFIRM');
      expect(log.renderedPreview, contains('Ravi'));
      expect(log.renderedPreview, isNot(contains('{')));
      expect(log.costPaise, estimateCostPaise(MessageCategory.utility));
      expect(log.createdAt, _now);
      expect(log.sentAt, isNull);
    });

    test('toLog rejects an invalid phone and missing variables', () {
      expect(
        () => _request(phone: '12345').toLog(id: 'x', now: _now),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => _request(variables: const {}).toLog(id: 'x', now: _now),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('OutboxMessagingProvider', () {
    test(
      'queues through the sink with no network and reports status',
      () async {
        final sunk = <MessageLog>[];
        var counter = 0;
        final provider = OutboxMessagingProvider(
          (log) async => sunk.add(log),
          idGenerator: () => 'id-${++counter}',
          clock: () => _now,
        );

        final log = await provider.send(_request());
        expect(sunk, hasLength(1));
        expect(sunk.single.id, 'id-1');
        expect(log.status, MessageStatus.queued);
        expect(log.providerMessageId, isNull);
        expect(await provider.status('id-1'), MessageStatus.queued);

        provider.recordStatus('id-1', MessageStatus.delivered);
        expect(await provider.status('id-1'), MessageStatus.delivered);
        expect(await provider.status('unknown'), MessageStatus.queued);
      },
    );

    test(
      'propagates sink failures and writes nothing on render errors',
      () async {
        var sinkCalls = 0;
        final provider = OutboxMessagingProvider((log) async {
          sinkCalls++;
          throw StateError('disk full');
        });
        await expectLater(
          provider.send(_request()),
          throwsA(isA<StateError>()),
        );
        expect(sinkCalls, 1);
        await expectLater(
          provider.send(_request(variables: const {})),
          throwsA(isA<ArgumentError>()),
        );
        expect(sinkCalls, 1);
      },
    );

    test('default id generator yields UUID v4 ids', () async {
      final provider = OutboxMessagingProvider((log) async {});
      final log = await provider.send(_request());
      expect(isValidId(log.id), isTrue);
    });
  });

  group('deep links', () {
    test('whatsappDeepLink encodes digits-only number and the text', () {
      final uri = whatsappDeepLink(
        '+919876543210',
        'Hi Ravi, see you & Dr. Rao',
      );
      expect(uri.scheme, 'https');
      expect(uri.host, 'wa.me');
      expect(uri.path, '/919876543210');
      expect(uri.queryParameters['text'], 'Hi Ravi, see you & Dr. Rao');
      expect(
        uri.toString(),
        'https://wa.me/919876543210?text=Hi%20Ravi%2C%20see%20you%20%26%20Dr.%20Rao',
      );
      expect(uri.toString(), isNot(contains('+')));
    });

    test('whatsappDeepLink percent-encodes newlines and unicode', () {
      final uri = whatsappDeepLink('+919876543210', 'Line 1\nLine 2 ₹500');
      expect(uri.toString(), contains('%0A'));
      expect(uri.toString(), contains('%E2%82%B9500'));
      expect(uri.queryParameters['text'], 'Line 1\nLine 2 ₹500');
    });

    test('smsDeepLink keeps the plus and prefills the body', () {
      final uri = smsDeepLink('+919876543210', 'Your code is 1234');
      expect(uri.scheme, 'sms');
      expect(uri.toString(), 'sms:+919876543210?body=Your%20code%20is%201234');
    });
  });

  group('DeepLinkMessagingProvider', () {
    test('prepare renders and builds both URIs; send stays queued', () async {
      var counter = 0;
      final provider = DeepLinkMessagingProvider(
        idGenerator: () => 'dl-${++counter}',
        clock: () => _now,
      );
      final prepared = provider.prepare(_request());
      expect(prepared.log.status, MessageStatus.queued);
      expect(prepared.whatsappUri.host, 'wa.me');
      expect(prepared.whatsappUri.path, '/919876543210');
      expect(
        prepared.whatsappUri.queryParameters['text'],
        prepared.log.renderedPreview,
      );
      expect(prepared.smsUri.scheme, 'sms');
      expect(prepared.preferredUri, prepared.whatsappUri);

      final log = await provider.send(_request());
      expect(log.status, MessageStatus.queued);
      expect(log.sentAt, isNull);
      expect(await provider.status(log.id), MessageStatus.queued);
    });

    test('markLaunched flips to sent with a timestamp', () async {
      final provider = DeepLinkMessagingProvider(clock: () => _now);
      final log = await provider.send(_request());
      final sent = await provider.markLaunched(log);
      expect(sent.id, log.id);
      expect(sent.status, MessageStatus.sent);
      expect(sent.sentAt, _now);
      expect(await provider.status(log.id), MessageStatus.sent);
    });

    test('markLaunchFailed records cancellation', () async {
      final provider = DeepLinkMessagingProvider();
      final log = await provider.send(_request());
      final failed = await provider.markLaunchFailed(log, error: 'no app');
      expect(failed.status, MessageStatus.cancelled);
      expect(failed.error, 'no app');
      expect(await provider.status(log.id), MessageStatus.cancelled);
    });

    test('an SMS template prefers the sms: URI', () {
      final provider = DeepLinkMessagingProvider();
      final prepared = provider.prepare(
        MessageRequest(
          clinicId: 'c',
          toPhone: '9876543210',
          template: templateByCode('OTP_AUTH_SMS')!,
          variables: const {
            'otp': '482913',
            'clinic_name': 'Oasis Dental',
            'expiry_minutes': '10',
          },
        ),
      );
      expect(prepared.log.channel, MessageChannel.sms);
      expect(prepared.preferredUri, prepared.smsUri);
      expect(prepared.log.category, MessageCategory.authentication);
    });
  });
}
