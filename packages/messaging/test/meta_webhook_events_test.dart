import 'dart:convert';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_messaging/ampdent_messaging.dart';
import 'package:test/test.dart';

Map<String, Object?> _webhook(
  List<Map<String, Object?>> statuses, [
  List<Map<String, Object?>> messages = const [],
]) => {
  'object': 'whatsapp_business_account',
  'entry': [
    {
      'id': 'WABA_ID',
      'changes': [
        {
          'field': 'messages',
          'value': {
            'messaging_product': 'whatsapp',
            'metadata': {
              'display_phone_number': '919876543210',
              'phone_number_id': 'PNID_1',
            },
            if (statuses.isNotEmpty) 'statuses': statuses,
            if (messages.isNotEmpty) 'messages': messages,
          },
        },
      ],
    },
  ],
};

Map<String, Object?> _status(String status, {Map<String, Object?>? error}) => {
  'id': 'wamid.OUT1',
  'status': status,
  'timestamp': '1761300000',
  'recipient_id': '919000000001',
  if (status == 'sent')
    'conversation': {
      'id': 'conv1',
      'origin': {'type': 'utility'},
    },
  if (status == 'sent')
    'pricing': {
      'billable': true,
      'pricing_model': 'PMP',
      'category': 'utility',
    },
  if (error != null) 'errors': [error],
};

final MessageLog _queued = MessageLog(
  id: 'log1',
  clinicId: 'c',
  patientId: 'p',
  channel: MessageChannel.whatsapp,
  category: MessageCategory.utility,
  templateCode: 'APPT_REMINDER_24H',
  toPhone: '+919000000001',
  renderedPreview: 'x',
  createdAt: DateTime.utc(2026, 10, 24),
);

void main() {
  group('parseMetaWebhook statuses', () {
    test('parses sent with conversation and pricing', () {
      final events = parseMetaWebhook(_webhook([_status('sent')]));
      expect(events.messages, isEmpty);
      final e = events.statuses.single;
      expect(e.providerMessageId, 'wamid.OUT1');
      expect(e.status, MessageStatus.sent);
      expect(e.rawStatus, 'sent');
      expect(e.recipientPhone, '+919000000001');
      expect(e.timestamp, DateTime.utc(2025, 10, 24, 10));
      expect(e.phoneNumberId, 'PNID_1');
      expect(e.conversationId, 'conv1');
      expect(e.pricingCategory, 'utility');
      expect(e.billable, isTrue);
      expect(e.isFailure, isFalse);
      expect(e.errorText, isNull);
    });

    test('parses delivered, read and failed with the error code/title', () {
      final events = parseMetaWebhook(
        _webhook([
          _status('delivered'),
          _status('read'),
          _status(
            'failed',
            error: {
              'code': 131026,
              'title': 'Message undeliverable',
              'message': 'Message undeliverable',
              'error_data': {'details': 'Recipient is not a WhatsApp user'},
            },
          ),
        ]),
      );
      expect(events.statuses.map((e) => e.status), [
        MessageStatus.delivered,
        MessageStatus.read,
        MessageStatus.failed,
      ]);
      final failed = events.statuses.last;
      expect(failed.isFailure, isTrue);
      expect(failed.errorCode, 131026);
      expect(failed.errorTitle, 'Message undeliverable');
      expect(failed.errorDetail, 'Recipient is not a WhatsApp user');
      expect(failed.errorText, '131026 Message undeliverable');
    });

    test('ignores deleted/warning statuses and non-message fields', () {
      final body = _webhook([_status('deleted'), _status('read')]);
      final entry = (body['entry'] as List).single as Map;
      (entry['changes'] as List).add({
        'field': 'account_update',
        'value': {'event': 'VERIFIED_ACCOUNT'},
      });
      final events = parseMetaWebhook(body);
      expect(events.statuses.map((e) => e.rawStatus), ['read']);
      expect(events.ignoredStatuses, ['deleted']);
    });

    test('empty or unrelated payloads yield no events', () {
      expect(parseMetaWebhook({}).isEmpty, isTrue);
      expect(parseMetaWebhook({'entry': []}).isEmpty, isTrue);
      expect(MetaWebhookEvents.empty.isEmpty, isTrue);
    });

    test('survives a jsonDecode round trip of a realistic body', () {
      final raw = jsonEncode(_webhook([_status('sent')]));
      final decoded = jsonDecode(raw) as Map<String, Object?>;
      expect(parseMetaWebhook(decoded).statuses, hasLength(1));
    });
  });

  group('MetaStatusEvent.applyTo', () {
    MetaStatusEvent event(MessageStatus s, {int? code, String? title}) =>
        MetaStatusEvent(
          providerMessageId: 'wamid.OUT1',
          status: s,
          rawStatus: s.name,
          recipientPhone: '+919000000001',
          timestamp: DateTime.utc(2026, 10, 25, 8),
          errorCode: code,
          errorTitle: title,
        );

    test('moves forward and stamps timestamps', () {
      final sent = event(MessageStatus.sent).applyTo(_queued);
      expect(sent.status, MessageStatus.sent);
      expect(sent.providerMessageId, 'wamid.OUT1');
      expect(sent.sentAt, DateTime.utc(2026, 10, 25, 8));
      expect(sent.deliveredAt, isNull);

      final delivered = event(MessageStatus.delivered).applyTo(sent);
      expect(delivered.status, MessageStatus.delivered);
      expect(delivered.deliveredAt, DateTime.utc(2026, 10, 25, 8));

      final read = MetaStatusEvent(
        providerMessageId: 'wamid.OUT1',
        status: MessageStatus.read,
        rawStatus: 'read',
        recipientPhone: '+919000000001',
        timestamp: DateTime.utc(2026, 10, 25, 9),
      ).applyTo(delivered);
      expect(read.status, MessageStatus.read);
      expect(read.deliveredAt, DateTime.utc(2026, 10, 25, 8));
    });

    test('never regresses on a late or duplicate webhook', () {
      final delivered = event(MessageStatus.delivered).applyTo(_queued);
      expect(
        identical(event(MessageStatus.sent).applyTo(delivered), delivered),
        isTrue,
      );
      expect(
        identical(event(MessageStatus.delivered).applyTo(delivered), delivered),
        isTrue,
      );
    });

    test('failed records the error text from any prior state', () {
      final read = event(MessageStatus.read).applyTo(_queued);
      final failed = event(
        MessageStatus.failed,
        code: 131047,
        title: 'Re-engagement message',
      ).applyTo(read);
      expect(failed.status, MessageStatus.failed);
      expect(failed.error, '131047 Re-engagement message');
    });
  });

  group('parseMetaWebhook inbound messages', () {
    test('text reply of 1 is a confirmation with its context id', () {
      final events = parseMetaWebhook(
        _webhook(const [], [
          {
            'from': '919000000001',
            'id': 'wamid.IN1',
            'timestamp': '1761300100',
            'type': 'text',
            'text': {'body': ' 1 '},
            'context': {'from': '919876543210', 'id': 'wamid.OUT1'},
          },
        ]),
      );
      final m = events.messages.single;
      expect(m.providerMessageId, 'wamid.IN1');
      expect(m.fromPhone, '+919000000001');
      expect(m.type, 'text');
      expect(m.text, ' 1 ');
      expect(m.isConfirmationReply, isTrue);
      expect(m.contextMessageId, 'wamid.OUT1');
      expect(m.phoneNumberId, 'PNID_1');
      expect(m.timestamp, DateTime.utc(2025, 10, 24, 10, 1, 40));
    });

    test('quick-reply button and interactive replies carry their text', () {
      final events = parseMetaWebhook(
        _webhook(const [], [
          {
            'from': '919000000001',
            'id': 'wamid.IN2',
            'timestamp': 1761300200,
            'type': 'button',
            'button': {'payload': '1', 'text': '1'},
          },
          {
            'from': '919000000001',
            'id': 'wamid.IN3',
            'timestamp': '1761300300',
            'type': 'interactive',
            'interactive': {
              'type': 'button_reply',
              'button_reply': {'id': 'confirm', 'title': 'Confirm'},
            },
          },
          {
            'from': '919000000001',
            'id': 'wamid.IN4',
            'timestamp': '1761300400',
            'type': 'image',
            'image': {'id': 'media1', 'mime_type': 'image/jpeg'},
          },
          {'bogus': true},
        ]),
      );
      expect(events.messages, hasLength(3));
      expect(events.messages[0].text, '1');
      expect(events.messages[0].isConfirmationReply, isTrue);
      expect(events.messages[1].text, 'Confirm');
      expect(events.messages[1].isConfirmationReply, isFalse);
      expect(events.messages[2].type, 'image');
      expect(events.messages[2].text, isNull);
    });
  });
}
