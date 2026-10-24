import 'package:ampdent_core/ampdent_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../export/feature_harness.dart';

void main() {
  late FeatureTestEnv env;
  final now = DateTime.now();
  final t = DateTime.utc(2026, 10, 1);

  SterilisationCycle cycle(DateTime at, BiologicalIndicatorResult? bi) =>
      SterilisationCycle(
        id: newId(),
        clinicId: testClinicId,
        cycleNumber: '',
        autoclaveName: 'Autoclave 1',
        cycledAt: at.toUtc(),
        cycleType: SterilisationCycleType.classB,
        biologicalIndicatorResult: bi,
        operatorId: testDentistId,
        createdAt: t,
      );

  Licence licence(String id, DateTime expiresAt) => Licence(
    id: id,
    clinicId: testClinicId,
    kind: LicenceKind.aerbRegistration,
    identifier: 'AERB/TS/123',
    authority: 'AERB',
    expiresAt: expiresAt.toUtc(),
    createdAt: t,
    updatedAt: t,
  );

  setUp(() async {
    env = await FeatureTestEnv.open();
  });
  tearDown(() => env.close());

  testWidgets('spore test banner shows when the last test is 8 days old '
      'and clears after a passing cycle is logged', (tester) async {
    await env.repos.compliance.recordCycle(
      testCtx,
      cycle(
        now.subtract(const Duration(days: 8)),
        BiologicalIndicatorResult.pass,
      ),
    );
    await env.pumpApp(tester);
    await env.go(tester, '/compliance');
    expect(find.byKey(const ValueKey('spore-test-banner')), findsOneWidget);
    expect(find.textContaining('SC-00001'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('compliance-log-cycle')));
    await settle(tester, frames: 10);
    await tester.enterText(
      find.byKey(const ValueKey('cycle-autoclave')),
      'Autoclave 1',
    );
    await tester.ensureVisible(find.text('Pass'));
    await tester.tap(find.text('Pass'));
    await settle(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('cycle-save')));
    await tester.tap(find.byKey(const ValueKey('cycle-save')));
    await settle(tester, frames: 12);

    expect(find.byKey(const ValueKey('spore-test-banner')), findsNothing);
    expect(find.textContaining('SC-00002'), findsWidgets);
    final cycles = await env.repos.compliance.cycles(testClinicId);
    expect(cycles.length, 2);
    expect(
      cycles.first.biologicalIndicatorResult,
      BiologicalIndicatorResult.pass,
    );
  });

  testWidgets('no banner when a spore test ran within the week', (
    tester,
  ) async {
    await env.repos.compliance.recordCycle(
      testCtx,
      cycle(
        now.subtract(const Duration(days: 6)),
        BiologicalIndicatorResult.pass,
      ),
    );
    await env.pumpApp(tester);
    await env.go(tester, '/compliance');
    expect(find.byKey(const ValueKey('spore-test-banner')), findsNothing);
  });

  testWidgets('licence expiring within 60 days raises the banner', (
    tester,
  ) async {
    await env.repos.compliance.upsertLicence(
      testCtx,
      licence('lic-soon', now.add(const Duration(days: 30))),
    );
    await env.repos.compliance.upsertLicence(
      testCtx,
      licence('lic-far', now.add(const Duration(days: 300))),
    );
    await env.pumpApp(tester);
    await env.go(tester, '/compliance?tab=licences');
    expect(find.byKey(const ValueKey('licence-expiry-banner')), findsOneWidget);
    expect(find.text('1 licence needs attention'), findsOneWidget);
    expect(find.byKey(const ValueKey('licence-row-lic-soon')), findsOneWidget);
    expect(find.byKey(const ValueKey('licence-row-lic-far')), findsOneWidget);
    expect(
      find.text('Due in 29 d').evaluate().length +
          find.text('Due in 30 d').evaluate().length,
      1,
    );
    expect(
      find.byKey(const ValueKey('compliance-add-licence')),
      findsOneWidget,
    );
  });

  testWidgets('no licence banner when everything is far from expiry', (
    tester,
  ) async {
    await env.repos.compliance.upsertLicence(
      testCtx,
      licence('lic-far', now.add(const Duration(days: 300))),
    );
    await env.pumpApp(tester);
    await env.go(tester, '/compliance');
    expect(find.byKey(const ValueKey('licence-expiry-banner')), findsNothing);
  });

  testWidgets('Today quick action badges compliance alerts', (tester) async {
    await env.repos.compliance.upsertLicence(
      testCtx,
      licence('lic-soon', now.add(const Duration(days: 10))),
    );
    await env.pumpApp(tester);
    await settle(tester, frames: 10);
    // licence due soon + no spore test ever = 2 alerts
    expect(find.byKey(const ValueKey('qa-compliance')), findsOneWidget);
    expect(find.text('2'), findsWidgets);
  });
}
