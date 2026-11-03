import 'dart:convert';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_data/ampdent_data.dart';
// ignore: implementation_imports
import 'package:ampdent_data/src/db/app_database.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

import 'sync_helpers.dart';

void main() {
  late SyncTestEnv s;

  setUp(() async => s = await SyncTestEnv.open());
  tearDown(() => s.close());

  group('message_logs provider and opt-in reason', () {
    test('round-trip through the local store', () async {
      final log = message(id: 'm-1').copyWith(
        provider: MessageProvider.cloudApi,
        optInReason: 'appointment_reminders_consent',
      );
      await s.repos.messages.enqueue(ctx, log);
      final stored = (await s.repos.messages.getById('m-1'))!;
      expect(stored.provider, MessageProvider.cloudApi);
      expect(stored.optInReason, 'appointment_reminders_consent');
      final raw = (await s.localRow('message_logs', 'm-1'))!;
      expect(raw['provider'], 'cloud_api', reason: 'wire name on disk');
      expect(raw['opt_in_reason'], 'appointment_reminders_consent');
      final plain = await s.repos.messages.enqueue(ctx, message(id: 'm-2'));
      expect(plain.provider, isNull);
      expect((await s.repos.messages.getById('m-2'))!.provider, isNull);
    });

    test('v6 backfill copies the legacy variables stamps', () async {
      Future<void> insertLegacy(String id, Map<String, String> vars) =>
          s.db.customInsert(
            'INSERT INTO message_logs (id, clinic_id, patient_id, channel, '
            'category, template_code, to_phone, variables, rendered_preview, '
            'status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            variables: [
              Variable.withString(id),
              Variable.withString(clinicId),
              Variable.withString(patientId),
              Variable.withString('whatsapp'),
              Variable.withString('utility'),
              Variable.withString('appt_reminder_24h'),
              Variable.withString('+919000000004'),
              Variable.withString(jsonEncode(vars)),
              Variable.withString('Reminder'),
              Variable.withString('queued'),
              Variable.withString(encodeIsoUtc(t0)),
            ],
          );
      await insertLegacy('old-cloud', {
        'name': 'Anil',
        '_provider': 'cloud_api',
        '_opt_in_reason': 'transactional',
      });
      await insertLegacy('old-deeplink', {'_provider': 'deeplink'});
      await insertLegacy('old-plain', {'name': 'Anil'});
      await insertLegacy('old-bad', {'_provider': 'fax'});
      expect(await s.db.migrateLegacyMessageLogStamps(), 3);

      final cloud = (await s.repos.messages.getById('old-cloud'))!;
      expect(cloud.provider, MessageProvider.cloudApi);
      expect(cloud.optInReason, 'transactional');
      expect(cloud.variables['_provider'], 'cloud_api', reason: 'kept');
      expect(
        (await s.repos.messages.getById('old-deeplink'))!.provider,
        MessageProvider.deeplink,
      );
      final plain = (await s.repos.messages.getById('old-plain'))!;
      expect(plain.provider, isNull);
      expect(plain.optInReason, isNull);
      expect((await s.repos.messages.getById('old-bad'))!.provider, isNull);
      // Running it again changes nothing.
      expect(await s.db.migrateLegacyMessageLogStamps(), 0);
    });

    test('push sends the wire name and the opt-in reason, and omits a null '
        'provider', () async {
      await s.repos.messages.enqueue(
        ctx,
        message(id: 'm-cloud').copyWith(
          provider: MessageProvider.cloudApi,
          optInReason: 'transactional',
        ),
      );
      await s.repos.messages.enqueue(ctx, message(id: 'm-plain'));
      await s.engine().pushPending();
      final rows = s.fake.requestsFor('message_logs').single.rows;
      final cloud = rows.firstWhere((r) => r['id'] == 'm-cloud');
      expect(cloud['provider'], 'cloud_api');
      expect(cloud['opt_in_reason'], 'transactional');
      final plain = rows.firstWhere((r) => r['id'] == 'm-plain');
      expect(
        plain.containsKey('provider'),
        isFalse,
        reason: 'server default applies',
      );
      expect(plain['opt_in_reason'], isNull);
      expect(await s.pendingCount(), 0);
    });

    test('pull reads the server provider, including sms_gateway', () async {
      s.fake.seed('message_logs', {
        ...s.serverRow('message_logs', message(id: 'srv-1').toInsertable()),
        'provider': 'cloud_api',
        'status': 'delivered',
        'opt_in_reason': 'appointment_reminders_consent',
      });
      s.fake.seed('message_logs', {
        ...s.serverRow('message_logs', message(id: 'srv-2').toInsertable()),
        'provider': 'sms_gateway',
      });
      await s.engine().pullSince(null);
      final a = (await s.repos.messages.getById('srv-1'))!;
      expect(a.provider, MessageProvider.cloudApi);
      expect(a.status, MessageStatus.delivered);
      expect(a.optInReason, 'appointment_reminders_consent');
      expect((await s.repos.messages.getById('srv-2'))!.optInReason, isNull);
      expect(
        (await s.repos.messages.getById('srv-2'))!.provider,
        MessageProvider.smsGateway,
      );
    });
  });
}
