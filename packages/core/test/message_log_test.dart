import 'dart:convert';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:test/test.dart';

final _t0 = DateTime.utc(2026, 10, 18, 9, 30);

MessageLog _log({
  MessageProvider? provider,
  String? optInReason,
  Map<String, String> variables = const {'patient_name': 'Asha'},
}) => MessageLog(
  id: 'm-1',
  clinicId: 'clinic-1',
  patientId: 'patient-1',
  channel: MessageChannel.whatsapp,
  category: MessageCategory.utility,
  templateCode: 'appt_reminder_24h',
  toPhone: '+919000000002',
  variables: variables,
  renderedPreview: 'Hi Asha',
  createdAt: _t0,
  provider: provider,
  optInReason: optInReason,
);

void main() {
  group('MessageProvider', () {
    test('wire names match the server check constraint', () {
      expect(MessageProvider.deeplink.wireName, 'deeplink');
      expect(MessageProvider.cloudApi.wireName, 'cloud_api');
      expect(MessageProvider.smsGateway.wireName, 'sms_gateway');
    });

    test('parses wire names and Dart names, null for unknown', () {
      expect(MessageProvider.tryParse('cloud_api'), MessageProvider.cloudApi);
      expect(MessageProvider.tryParse('cloudApi'), MessageProvider.cloudApi);
      expect(MessageProvider.tryParse('deeplink'), MessageProvider.deeplink);
      expect(MessageProvider.tryParse(null), isNull);
      expect(MessageProvider.tryParse('fax'), isNull);
      expect(MessageProvider.tryParse(42), isNull);
      expect(() => MessageProvider.parse('fax'), throwsFormatException);
    });
  });

  group('MessageLog provider and optInReason', () {
    test('round-trip through JSON with the wire name', () {
      final log = _log(
        provider: MessageProvider.cloudApi,
        optInReason: 'transactional',
      );
      final json = log.toJson();
      expect(json['provider'], 'cloud_api');
      expect(json['optInReason'], 'transactional');
      final wire = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
      final parsed = MessageLog.fromJson(wire.cast<String, Object?>());
      expect(parsed.provider, MessageProvider.cloudApi);
      expect(parsed.optInReason, 'transactional');
      expect(parsed.toJson(), json);
    });

    test('unset fields serialise as null and parse back as null', () {
      final parsed = MessageLog.fromJson(_log().toJson());
      expect(parsed.provider, isNull);
      expect(parsed.optInReason, isNull);
    });

    test('fromJson falls back to the legacy variables stamps', () {
      final json = _log(
        variables: const {
          'patient_name': 'Asha',
          '_provider': 'cloud_api',
          '_opt_in_reason': 'recall_reminders_consent',
        },
      ).toJson();
      // Rows written by an older build carry no top-level fields at all.
      json.remove('provider');
      json.remove('optInReason');
      final parsed = MessageLog.fromJson(json);
      expect(parsed.provider, MessageProvider.cloudApi);
      expect(parsed.optInReason, 'recall_reminders_consent');
      // The stamps stay in variables so the row keeps its original shape.
      expect(parsed.variables['_provider'], 'cloud_api');
    });

    test('an explicit field wins over a legacy stamp', () {
      final json = _log(
        provider: MessageProvider.deeplink,
        variables: const {'_provider': 'cloud_api'},
      ).toJson();
      expect(MessageLog.fromJson(json).provider, MessageProvider.deeplink);
    });

    test('copyWith replaces and keeps the new fields', () {
      final log = _log(provider: MessageProvider.deeplink);
      final sent = log.copyWith(status: MessageStatus.sent, sentAt: _t0);
      expect(sent.provider, MessageProvider.deeplink);
      expect(sent.optInReason, isNull);
      final re = sent.copyWith(
        provider: MessageProvider.cloudApi,
        optInReason: 'r',
      );
      expect(re.provider, MessageProvider.cloudApi);
      expect(re.optInReason, 'r');
      expect(re.status, MessageStatus.sent);
    });
  });
}
