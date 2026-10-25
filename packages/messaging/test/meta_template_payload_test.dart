import 'dart:convert';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_messaging/ampdent_messaging.dart';
import 'package:test/test.dart';

const Map<String, String> _reminderVars = {
  'patient_name': 'Ravi',
  'clinic_name': 'Oasis Dental',
  'appointment_date': 'Mon 20 Oct',
  'appointment_time': '10:30 AM',
  'doctor_name': 'Asha Rao',
  'clinic_phone': '+91 98765 43210',
};

void main() {
  group('metaTemplateName', () {
    test('lower_snake_cases catalogue codes', () {
      expect(metaTemplateName('APPT_REMINDER_24H'), 'appt_reminder_24h');
      expect(metaTemplateName('OTP_AUTH'), 'otp_auth');
      expect(metaTemplateName('postOpRct'), 'post_op_rct');
      expect(metaTemplateName('Lab-Ready Seat'), 'lab_ready_seat');
    });

    test('every default template maps to a valid, unique Meta name', () {
      final names = defaultTemplates.map((t) => metaTemplateName(t.code));
      for (final n in names) {
        expect(n, matches(RegExp(r'^[a-z0-9_]+$')));
      }
      // OTP_AUTH and OTP_AUTH_SMS differ, so the set is as big as the list.
      expect(names.toSet(), hasLength(defaultTemplates.length));
    });
  });

  group('metaCategory', () {
    test('maps the three template categories and rejects service', () {
      expect(metaCategory(MessageCategory.utility), 'UTILITY');
      expect(metaCategory(MessageCategory.authentication), 'AUTHENTICATION');
      expect(metaCategory(MessageCategory.marketing), 'MARKETING');
      expect(
        () => metaCategory(MessageCategory.service),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('metaQuickReplyButtons', () {
    test('reminders that ask for "Reply 1" get a QUICK_REPLY 1 button', () {
      expect(metaQuickReplyButtons(templateByCode('APPT_REMINDER_24H')!), [
        {'type': 'QUICK_REPLY', 'text': '1'},
      ]);
      expect(metaQuickReplyButtons(templateByCode('APPT_REMINDER_MORNING')!), [
        {'type': 'QUICK_REPLY', 'text': '1'},
      ]);
      expect(metaQuickReplyButtons(templateByCode('INVOICE_LINK')!), isEmpty);
    });
  });

  group('metaRecipient and metaParameterText', () {
    test('strips the plus and validates E.164', () {
      expect(metaRecipient('+919876543210'), '919876543210');
      expect(metaRecipient('919876543210'), '919876543210');
      expect(metaRecipient(' +919876543210 '), '919876543210');
      expect(() => metaRecipient('98765 43210'), throwsFormatException);
      expect(() => metaRecipient('+0123'), throwsFormatException);
    });

    test('cleans whitespace Meta rejects and refuses empty values', () {
      expect(metaParameterText('Line 1\nLine 2\tend'), 'Line 1 Line 2 end');
      expect(metaParameterText('a     b'), 'a b');
      expect(metaParameterText('  ok  '), 'ok');
      expect(() => metaParameterText('  \n '), throwsA(isA<ArgumentError>()));
    });
  });

  group('buildMetaTemplatePayload golden', () {
    test('APPT_REMINDER_24H', () {
      final payload = buildMetaTemplatePayload(
        template: templateByCode('APPT_REMINDER_24H')!,
        variables: _reminderVars,
        e164Phone: '+919876543210',
      );
      expect(
        jsonEncode(payload),
        '{"messaging_product":"whatsapp","to":"919876543210",'
        '"type":"template","template":{"name":"appt_reminder_24h",'
        '"language":{"code":"en"},"components":[{"type":"body","parameters":['
        '{"type":"text","text":"Ravi"},'
        '{"type":"text","text":"Oasis Dental"},'
        '{"type":"text","text":"Mon 20 Oct"},'
        '{"type":"text","text":"10:30 AM"},'
        '{"type":"text","text":"Asha Rao"},'
        '{"type":"text","text":"+91 98765 43210"}]}]}}',
      );
    });

    test('INVOICE_LINK', () {
      final payload = buildMetaTemplatePayload(
        template: templateByCode('INVOICE_LINK')!,
        variables: const {
          'patient_name': 'Meera',
          'document_number': 'INV/2026-27/0042',
          'clinic_name': 'Oasis Dental',
          'amount': '₹4,500.00',
          'link': 'https://p.ampdent.in/d/abc123',
          'clinic_phone': '+91 98765 43210',
        },
        e164Phone: '+919000000001',
      );
      expect(
        jsonEncode(payload),
        '{"messaging_product":"whatsapp","to":"919000000001",'
        '"type":"template","template":{"name":"invoice_link",'
        '"language":{"code":"en"},"components":[{"type":"body","parameters":['
        '{"type":"text","text":"Meera"},'
        '{"type":"text","text":"INV/2026-27/0042"},'
        '{"type":"text","text":"Oasis Dental"},'
        '{"type":"text","text":"₹4,500.00"},'
        '{"type":"text","text":"https://p.ampdent.in/d/abc123"},'
        '{"type":"text","text":"+91 98765 43210"}]}]}}',
      );
    });

    test('OTP_AUTH', () {
      final payload = buildMetaTemplatePayload(
        template: templateByCode('OTP_AUTH')!,
        variables: const {
          'otp': '482913',
          'clinic_name': 'Oasis Dental',
          'expiry_minutes': '10',
        },
        e164Phone: '919876543210',
      );
      expect(
        jsonEncode(payload),
        '{"messaging_product":"whatsapp","to":"919876543210",'
        '"type":"template","template":{"name":"otp_auth",'
        '"language":{"code":"en"},"components":[{"type":"body","parameters":['
        '{"type":"text","text":"482913"},'
        '{"type":"text","text":"Oasis Dental"},'
        '{"type":"text","text":"10"}]}]}}',
      );
    });

    test('parameters follow variables order, not the map order', () {
      final shuffled = Map.fromEntries(_reminderVars.entries.toList().reversed);
      final payload = buildMetaTemplatePayload(
        template: templateByCode('APPT_REMINDER_24H')!,
        variables: shuffled,
        e164Phone: '+919876543210',
      );
      final template = payload['template'] as Map;
      final body = (template['components'] as List).single as Map;
      final texts = (body['parameters'] as List)
          .map((p) => (p as Map)['text'])
          .toList();
      expect(texts.first, 'Ravi');
      expect(texts.last, '+91 98765 43210');
    });

    test('ignores reserved keys and fails on missing variables', () {
      final payload = buildMetaTemplatePayload(
        template: templateByCode('OTP_AUTH')!,
        variables: const {
          'otp': '1',
          'clinic_name': 'C',
          'expiry_minutes': '5',
          '_provider': 'cloud_api',
          '_opt_in_reason': 'x',
        },
        e164Phone: '+919876543210',
      );
      expect(jsonEncode(payload), isNot(contains('cloud_api')));
      expect(
        () => buildMetaTemplatePayload(
          template: templateByCode('OTP_AUTH')!,
          variables: const {'otp': '1'},
          e164Phone: '+919876543210',
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.invalidValue,
            'missing',
            'clinic_name, expiry_minutes',
          ),
        ),
      );
    });

    test('every default WhatsApp template builds and renders consistently', () {
      for (final t in templatesForChannel(MessageChannel.whatsapp)) {
        final vars = {for (final v in t.variables) v: 'v_$v'};
        final payload = buildMetaTemplatePayload(
          template: t,
          variables: vars,
          e164Phone: '+919876543210',
        );
        final template = payload['template'] as Map;
        final body = (template['components'] as List).single as Map;
        expect(body['parameters'], hasLength(t.variables.length));
      }
    });
  });

  group('metaPayloadForLog', () {
    test('resolves the template by code and uses the log phone', () {
      final log = MessageLog(
        id: 'l1',
        clinicId: 'c',
        channel: MessageChannel.whatsapp,
        category: MessageCategory.authentication,
        templateCode: 'OTP_AUTH',
        toPhone: '+919876543210',
        variables: const {
          'otp': '111111',
          'clinic_name': 'C',
          'expiry_minutes': '5',
          '_provider': 'cloud_api',
        },
        renderedPreview: 'x',
        createdAt: DateTime.utc(2026),
      );
      final payload = metaPayloadForLog(log);
      expect(payload['to'], '919876543210');
      expect((payload['template'] as Map)['name'], 'otp_auth');
      expect(
        () => metaPayloadForLog(
          MessageLog(
            id: 'l2',
            clinicId: 'c',
            channel: MessageChannel.whatsapp,
            category: MessageCategory.utility,
            templateCode: 'NOPE',
            toPhone: '+919876543210',
            renderedPreview: 'x',
            createdAt: DateTime.utc(2026),
          ),
        ),
        throwsStateError,
      );
    });
  });

  group('send response parsing', () {
    test('reads the message id, wa_id and hold status', () {
      final result = parseMetaSendResponse({
        'messaging_product': 'whatsapp',
        'contacts': [
          {'input': '+919876543210', 'wa_id': '919876543210'},
        ],
        'messages': [
          {'id': 'wamid.HBgL1', 'message_status': 'accepted'},
        ],
      });
      expect(result.messageId, 'wamid.HBgL1');
      expect(result.waId, '919876543210');
      expect(result.messageStatus, 'accepted');
      expect(result.heldForQuality, isFalse);
      expect(
        MetaSendResult.fromJson({
          'messages': [
            {'id': 'w', 'message_status': 'held_for_quality_assessment'},
          ],
        }).heldForQuality,
        isTrue,
      );
      expect(() => MetaSendResult.fromJson({}), throwsFormatException);
    });

    test('throws a classified MetaApiError on an error body', () {
      final body = {
        'error': {
          'message': '(#131026) Message Undeliverable',
          'type': 'OAuthException',
          'code': 131026,
          'error_data': {
            'messaging_product': 'whatsapp',
            'details': 'Message Undeliverable.',
          },
          'fbtrace_id': 'Abc',
        },
      };
      expect(
        () => parseMetaSendResponse(body),
        throwsA(
          isA<MetaApiError>()
              .having((e) => e.code, 'code', 131026)
              .having((e) => e.isRetryable, 'retryable', isFalse)
              .having((e) => e.details, 'details', 'Message Undeliverable.')
              .having((e) => e.fbTraceId, 'trace', 'Abc'),
        ),
      );
      final throttled = MetaApiError.tryParse({
        'error': {'code': 130429, 'message': 'Rate limit hit'},
      });
      expect(throttled!.isRetryable, isTrue);
      expect(throttled.toString(), 'MetaApiError(130429: Rate limit hit)');
      expect(MetaApiError.tryParse({'messages': []}), isNull);
    });
  });
}
