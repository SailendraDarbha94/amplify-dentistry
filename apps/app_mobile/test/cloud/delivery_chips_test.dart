import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_messaging/ampdent_messaging.dart';
import 'package:ampdent_mobile/core/cloud_messaging.dart';
import 'package:ampdent_mobile/features/patients/patient_timeline.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_env.dart';

/// Message rows appear on the patient timeline with their delivery status.
void main() {
  late AppTestEnv env;
  final t = DateTime.utc(2026, 10, 24, 9);

  MessageLog log(String id, MessageStatus status, {String? error}) =>
      MessageLog(
        id: id,
        clinicId: testClinicId,
        patientId: testPatientId,
        channel: MessageChannel.whatsapp,
        category: MessageCategory.utility,
        templateCode: 'APPT_REMINDER_24H',
        toPhone: '+919876543210',
        variables: const {
          MessageLogKeys.provider: MessageLogKeys.cloudApiProvider,
        },
        renderedPreview: 'Reminder',
        status: status,
        error: error,
        createdAt: t,
      );

  setUp(() async {
    env = await AppTestEnv.open(withPatient: true);
    await env.repos.messages.enqueue(
      testCtx,
      log('m-queued', MessageStatus.queued),
    );
    await env.repos.messages.enqueue(
      testCtx,
      log('m-delivered', MessageStatus.delivered),
    );
    await env.repos.messages.enqueue(
      testCtx,
      log(
        'm-failed',
        MessageStatus.failed,
        error: '131026 Message undeliverable',
      ),
    );
  });
  tearDown(() => env.close());

  test('buildTimeline maps messages to badges', () {
    final events = buildTimeline(
      patientId: testPatientId,
      notation: ToothNotation.fdi,
      messages: [log('a', MessageStatus.read), log('b', MessageStatus.sent)],
    );
    expect(events, hasLength(2));
    expect(events.first.kind, TimelineKind.message);
    expect(events.map((e) => e.badge), containsAll(['Read', 'Sent']));
    expect(events.first.title, 'Appt reminder 24h');
    expect(events.first.subtitle, contains('via Cloud API'));
    expect(events.first.subtitle, isNot(contains('9876543210')));
    expect(messageStatusTone(MessageStatus.failed), BadgeTone.danger);
    expect(messageStatusTone(MessageStatus.delivered), BadgeTone.success);
  });

  testWidgets('the timeline tab shows one chip per message', (tester) async {
    await env.pumpApp(tester);
    await env.go(tester, '/patients/$testPatientId');
    await tester.tap(find.text('Timeline'));
    await settle(tester, frames: 10);
    expect(find.byKey(const ValueKey('timeline-badge-m-queued')), findsOne);
    expect(find.byKey(const ValueKey('timeline-badge-m-delivered')), findsOne);
    expect(find.byKey(const ValueKey('timeline-badge-m-failed')), findsOne);
    expect(find.text('Queued'), findsOneWidget);
    expect(find.text('Delivered'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
    expect(find.textContaining('131026 Message undeliverable'), findsOneWidget);
  });
}
