import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/features/recall/recall_actions.dart';
import 'package:ampdent_mobile/features/recall/recall_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'feature_harness.dart';

void main() {
  late FeatureHarness h;

  setUp(() async {
    h = await FeatureHarness.open();
    final recalls = h.env.repos.recalls;
    await recalls.upsert(
      testCtx,
      recallFixture(
        id: 'overdue-1',
        dueAt: h.now.subtract(const Duration(days: 5)),
        value: const Money.rupees(1500),
      ),
    );
    await recalls.upsert(
      testCtx,
      recallFixture(
        id: 'overdue-2',
        dueAt: h.now.subtract(const Duration(days: 1)),
        type: RecallType.review,
        value: const Money.rupees(500),
      ),
    );
    await recalls.upsert(
      testCtx,
      recallFixture(
        id: 'today-1',
        dueAt: DateTime(2026, 10, 21, 16),
        value: const Money.rupees(800),
      ),
    );
    await recalls.upsert(
      testCtx,
      recallFixture(
        id: 'upcoming-1',
        dueAt: h.now.add(const Duration(days: 10)),
        value: const Money.rupees(2000),
      ),
    );
  });
  tearDown(() => h.close());

  testWidgets('groups recalls with the rupee value of each group', (
    tester,
  ) async {
    await h.pumpApp(tester);
    await h.go(tester, '/recall');
    Finder headerValue(String group, String text) => find.descendant(
      of: find.byKey(ValueKey('recall-group-$group')),
      matching: find.text(text),
    );
    // Overdue sits at the top: 1,500 + 500.
    expect(find.byKey(const ValueKey('recall-group-overdue')), findsOneWidget);
    expect(headerValue('overdue', '₹2,000'), findsOneWidget);
    expect(find.byKey(const ValueKey('recall-row-overdue-1')), findsOneWidget);
    expect(find.text('Asha Rao'), findsWidgets);
    // The list culls rows out of view, so scroll before checking later groups.
    await h.scrollTo(
      tester,
      find.byKey(const ValueKey('recall-group-dueToday')),
      page: RecallPage,
    );
    expect(headerValue('dueToday', '₹800'), findsOneWidget);
    await h.scrollTo(
      tester,
      find.byKey(const ValueKey('recall-group-upcoming')),
      page: RecallPage,
    );
    expect(headerValue('upcoming', '₹2,000'), findsOneWidget);
  });

  testWidgets('type filter hides other types', (tester) async {
    await h.pumpApp(tester);
    await h.go(tester, '/recall');
    await tester.tap(find.widgetWithText(FilterChip, 'Review'));
    await settle(tester);
    expect(find.byKey(const ValueKey('recall-row-overdue-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('recall-row-overdue-1')), findsNothing);
    expect(find.byKey(const ValueKey('recall-group-upcoming')), findsNothing);
  });

  testWidgets('WhatsApp sends RECALL_OVERDUE and marks notified', (
    tester,
  ) async {
    await h.consent(DataPurpose.recallReminders);
    await h.pumpApp(tester);
    await h.go(tester, '/recall');
    await tester.tap(find.byKey(const ValueKey('recall-whatsapp-overdue-1')));
    await settle(tester, frames: 10);

    expect(h.launched, hasLength(1));
    expect(h.launched.single.host, 'wa.me');
    expect(h.launched.single.path, '/919876543210');
    final logs = await h.env.repos.messages.forPatient(testPatientId);
    expect(logs, hasLength(1));
    expect(logs.single.templateCode, 'RECALL_OVERDUE');
    expect(logs.single.status, MessageStatus.sent);
    expect(logs.single.renderedPreview, contains('hygiene visit'));
    expect(logs.single.renderedPreview, isNot(contains('Scaling')));
    final recall = await h.env.repos.recalls.getById('overdue-1');
    expect(recall!.status, RecallStatus.notified);
    expect(recall.notifyCount, 1);
    expect(find.text('Opened WhatsApp with the message'), findsOneWidget);
  });

  testWidgets('due-today recall uses RECALL_DUE with appointment consent', (
    tester,
  ) async {
    await h.consent(DataPurpose.appointmentReminders);
    await h.pumpApp(tester);
    await h.go(tester, '/recall');
    await h.scrollTo(
      tester,
      find.byKey(const ValueKey('recall-whatsapp-today-1')),
      page: RecallPage,
    );
    await tester.tap(find.byKey(const ValueKey('recall-whatsapp-today-1')));
    await settle(tester, frames: 10);
    final logs = await h.env.repos.messages.forPatient(testPatientId);
    expect(logs.single.templateCode, 'RECALL_DUE');
  });

  testWidgets('without consent nothing is sent or launched', (tester) async {
    await h.pumpApp(tester);
    await h.go(tester, '/recall');
    await tester.tap(find.byKey(const ValueKey('recall-whatsapp-overdue-1')));
    await settle(tester, frames: 10);
    expect(h.launched, isEmpty);
    expect(await h.env.repos.messages.forPatient(testPatientId), isEmpty);
    final recall = await h.env.repos.recalls.getById('overdue-1');
    expect(recall!.status, RecallStatus.due);
    expect(recall.notifyCount, 0);
    expect(find.textContaining('No reminder consent'), findsOneWidget);
  });

  testWidgets('dismiss requires a reason', (tester) async {
    await h.pumpApp(tester);
    await h.go(tester, '/recall');
    await tester.tap(find.byKey(const ValueKey('recall-dismiss-overdue-1')));
    await settle(tester);
    final confirm = find.byKey(const ValueKey('reason-confirm'));
    expect(confirm, findsOneWidget);
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    await h.confirmReason(tester, 'Patient declined');

    final recall = await h.env.repos.recalls.getById('overdue-1');
    expect(recall!.status, RecallStatus.dismissed);
    expect(find.byKey(const ValueKey('recall-row-overdue-1')), findsNothing);
    final audit = await h.env.repos.audit.forEntity(
      testClinicId,
      'Recall',
      'overdue-1',
    );
    expect(audit.last.reason, 'Patient declined');
  });

  test('RecallActions.dismiss rejects a blank reason', () async {
    final actions = h.container.read(recallActionsProvider);
    expect(() => actions.dismiss('overdue-1', '  '), throwsArgumentError);
    final recall = await h.env.repos.recalls.getById('overdue-1');
    expect(recall!.status, RecallStatus.due);
  });

  testWidgets('Book opens the new appointment flow for the patient', (
    tester,
  ) async {
    await h.pumpApp(tester);
    await h.go(tester, '/recall');
    await tester.tap(find.byKey(const ValueKey('recall-book-overdue-1')));
    await settle(tester, frames: 10);
    expect(h.location, '/schedule/new');
    final pushed =
        h.router.routerDelegate.currentConfiguration.last
            as ImperativeRouteMatch;
    expect(pushed.matches.uri.queryParameters['patientId'], testPatientId);
    expect(pushed.matches.uri.queryParameters['recallId'], 'overdue-1');
  });

  testWidgets('Incomplete tab lists an RCT without a crown and nudges', (
    tester,
  ) async {
    await h.consent(DataPurpose.recallReminders);
    await h.env.repos.chart.createProcedure(
      testCtx,
      procedureFixture(
        id: 'rct-36',
        code: 'RCT-MOL',
        name: 'Root canal treatment, molar',
        status: ProcedureStatus.completed,
        tooth: '36',
        completedAt: h.now.subtract(const Duration(days: 45)),
      ),
    );
    await h.pumpApp(tester);
    await h.go(tester, '/recall');
    await tester.tap(find.byKey(const ValueKey('recall-tab-incomplete')));
    await settle(tester, frames: 8);
    expect(find.byKey(const ValueKey('incomplete-row-rct-36')), findsOneWidget);
    expect(find.text('RCT without crown'), findsOneWidget);
    expect(find.textContaining('a crown on tooth 36'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('incomplete-whatsapp-rct-36')));
    await settle(tester, frames: 10);
    final logs = await h.env.repos.messages.forPatient(testPatientId);
    expect(logs.single.templateCode, 'TREATMENT_INCOMPLETE');
    expect(logs.single.renderedPreview, contains('a crown on tooth 36'));
    expect(h.launched, hasLength(1));
  });
}
