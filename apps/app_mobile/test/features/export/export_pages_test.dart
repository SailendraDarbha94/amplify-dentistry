import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feature_harness.dart';

void main() {
  late FeatureTestEnv env;

  setUp(() async {
    env = await FeatureTestEnv.open(withPatient: true);
  });
  tearDown(() => env.close());

  Finder rows() => find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key as ValueKey<String>).value.startsWith('audit-row-'),
  );

  testWidgets('export page searches patients and links to ownership', (
    tester,
  ) async {
    await env.pumpApp(tester);
    await env.go(tester, '/export');
    expect(find.byKey(const ValueKey('export-clinic')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('export-patient-search')),
      'asha',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await settle(tester);
    expect(
      find.byKey(const ValueKey('export-patient-$testPatientId')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('export-ownership')));
    await settle(tester, frames: 10);
    expect(env.location, '/export/data-ownership');
    expect(find.text('Data ownership'), findsOneWidget);
    expect(find.text('You own every record'), findsOneWidget);
  });

  testWidgets('audit page lists events, filters by entity and opens a diff', (
    tester,
  ) async {
    await env.pumpApp(tester);
    await env.go(tester, '/audit');
    await settle(tester, frames: 10);
    expect(rows(), findsWidgets);
    expect(find.text('Patient  ·  patient-'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('audit-filter-entity')));
    await settle(tester);
    await tester.tap(find.text('Chair').last);
    await settle(tester, frames: 10);
    expect(rows(), findsOneWidget);
    expect(find.text('Patient  ·  patient-'), findsNothing);

    await tester.tap(rows().first);
    await settle(tester, frames: 10);
    expect(find.text('Changes'), findsOneWidget);
    expect(find.byKey(const ValueKey('audit-diff-name')), findsOneWidget);
    expect(find.text('Chair 1'), findsOneWidget);
  });
}
