import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_messaging/ampdent_messaging.dart';
import 'package:ampdent_mobile/core/clinic_link.dart';
import 'package:ampdent_mobile/core/whatsapp_cloud.dart';
import 'package:ampdent_mobile/features/settings/whatsapp_test_message.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'cloud_test_support.dart';

/// Settings > WhatsApp: the token goes to the RPC and nowhere else; the
/// test message is queued through the cloud provider.
void main() {
  const token = 'EAAG-permanent-system-user-token-0123456789';
  late FakeSupabase fake;
  late AppTestEnv env;

  setUp(() async {
    fake = FakeSupabase();
    env = await openCloudEnv(fake);
  });
  tearDown(() => env.close());

  Future<void> reveal(WidgetTester tester, Key key) async {
    await tester.scrollUntilVisible(
      find.byKey(key),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
  }

  // Pressing through the widget: a tap's hit test can land on the list that
  // scrolled the button into view a frame earlier.
  Future<void> pressKey(WidgetTester tester, String key) async {
    final button = tester.widget<BigActionButton>(find.byKey(ValueKey(key)));
    button.onPressed!();
    await tester.pump();
  }

  Future<void> type(WidgetTester tester, String key, String text) async {
    await reveal(tester, ValueKey(key));
    await tester.enterText(find.byKey(ValueKey(key)), text);
  }

  group('validators', () {
    test('ids are digits, token long enough, verify token 8-128', () {
      expect(WhatsAppConfigValidators.digits('123456789012345', 'x'), isNull);
      expect(
        WhatsAppConfigValidators.digits('12ab', 'Phone number id'),
        isNotNull,
      );
      expect(WhatsAppConfigValidators.accessToken('short'), isNotNull);
      expect(WhatsAppConfigValidators.accessToken(token), isNull);
      expect(WhatsAppConfigValidators.verifyToken('abc'), isNotNull);
      expect(WhatsAppConfigValidators.verifyToken('verify-me-please'), isNull);
    });

    test('status parses the RPC jsonb', () {
      final s = WhatsAppStatus.fromJson({
        'configured': true,
        'enabled': false,
        'phoneNumberId': '1',
        'queuedCount': 2,
        'failedLast24h': 1,
        'updatedAt': '2026-10-20T08:00:00+00:00',
      });
      expect(s.configured, isTrue);
      expect(s.isActive, isFalse);
      expect(s.queuedCount, 2);
      expect(s.updatedAt, DateTime.utc(2026, 10, 20, 8));
    });
  });

  testWidgets(
    'signed out: the page asks to sign in and shows the deep-link mode',
    (tester) async {
      await env.pumpApp(tester);
      await env.go(tester, '/settings/whatsapp');
      expect(find.byKey(const ValueKey('whatsapp-signed-out')), findsOneWidget);
      expect(find.text('This phone'), findsOneWidget);
    },
  );

  testWidgets('saving sends the token to the RPC only and clears the field', (
    tester,
  ) async {
    await signIn(env.container, fake);
    expect((await runLink(env.container)).phase, LinkPhase.linked);
    await env.pumpApp(tester);
    await env.go(tester, '/settings/whatsapp');
    await settle(tester, frames: 10);
    expect(find.byKey(const ValueKey('whatsapp-status')), findsOneWidget);
    expect(find.text('Not configured'), findsOneWidget);

    await type(tester, 'whatsapp-phone-number-id', '123456789012345');
    await type(tester, 'whatsapp-waba-id', '987654321098765');
    await type(tester, 'whatsapp-display-phone', '+919000000001');
    await type(tester, 'whatsapp-access-token', token);
    await type(tester, 'whatsapp-verify-token', 'verify-me-please');
    await reveal(tester, const ValueKey('whatsapp-save'));
    await pressKey(tester, 'whatsapp-save');
    await settle(tester, frames: 12);

    expect(fake.receivedTokens, [token]);
    final (fn, params) = fake.rpcCalls.lastWhere(
      (c) => c.$1 == 'set_whatsapp_config',
    );
    expect(fn, 'set_whatsapp_config');
    expect(params['p_clinic'], testClinicId);
    expect(params['p_phone_number_id'], '123456789012345');
    expect(params['p_verify_token'], 'verify-me-please');

    // The field is cleared and the token is nowhere on the device.
    final field = tester.widget<TextFormField>(
      find.byKey(const ValueKey('whatsapp-access-token')),
    );
    expect(field.controller!.text, isEmpty);
    expect(await findSecretInStore(env.db, token), isEmpty);
    expect(
      await env.repos.clinics.getSetting(testClinicId, 'whatsapp.token'),
      isNull,
    );
    final settings = await env.db.select(env.db.settings).get();
    expect(settings.any((s) => s.valueJson.contains(token)), isFalse);
    // The status refreshed from the server.
    expect(find.text('Paused'), findsOneWidget);
  });

  testWidgets('enabled: the test message is queued for the owner\'s number', (
    tester,
  ) async {
    fake.whatsappStatus = {
      ...fake.whatsappStatus,
      'configured': true,
      'enabled': true,
      'phoneNumberId': '123456789012345',
      'wabaId': '987654321098765',
      'displayPhone': '+919000000001',
    };
    await signIn(env.container, fake);
    expect((await runLink(env.container)).phase, LinkPhase.linked);
    await env.pumpApp(tester);
    await env.go(tester, '/settings/whatsapp');
    await settle(tester, frames: 10);
    expect(find.text('Cloud API'), findsOneWidget);
    expect(find.text('Enabled'), findsOneWidget);

    await reveal(tester, const ValueKey('whatsapp-send-test'));
    await pressKey(tester, 'whatsapp-send-test');
    await settle(tester, frames: 12);

    final queued = await env.repos.messages.queued(testClinicId);
    expect(queued, hasLength(1));
    final log = queued.single;
    expect(log.templateCode, testMessageTemplateCode);
    expect(log.toPhone, testDentist().phone);
    expect(log.patientId, isNull);
    expect(log.status, MessageStatus.queued);
    expect(MessageLogKeys.providerOf(log), MessageLogKeys.cloudApiProvider);
    expect(log.renderedPreview, contains('Smile Dental'));
    expect(find.byKey(const ValueKey('whatsapp-test-result')), findsOneWidget);
  });
}
