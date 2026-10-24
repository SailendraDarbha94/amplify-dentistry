import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_env.dart';

void main() {
  late AppTestEnv env;

  setUp(() async {
    env = await AppTestEnv.open(withPatient: true);
    await env.addPatient(
      testPatient(
        id: 'patient-2',
        firstName: 'Ravi',
        lastName: 'Kumar',
        phone: '+919123456789',
      ),
    );
  });
  tearDown(() => env.close());

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(
      find.byKey(const ValueKey('patients-search')),
      query,
    );
    // SearchField debounces for 300 ms before firing onChanged.
    await tester.pump(const Duration(milliseconds: 350));
    await settle(tester);
  }

  testWidgets('shows recently seen patients when the query is blank', (
    tester,
  ) async {
    await env.pumpApp(tester);
    await env.go(tester, '/patients');
    expect(find.text('Recently seen'), findsOneWidget);
    expect(find.text('Asha Rao'), findsOneWidget);
    expect(find.text('Ravi Kumar'), findsOneWidget);
    expect(find.text('Patients (2)'), findsOneWidget);
  });

  testWidgets('filters by name', (tester) async {
    await env.pumpApp(tester);
    await env.go(tester, '/patients');
    await search(tester, 'ravi');
    expect(find.text('Ravi Kumar'), findsOneWidget);
    expect(find.text('Asha Rao'), findsNothing);
  });

  testWidgets('filters by phone fragment and patient number', (tester) async {
    await env.pumpApp(tester);
    await env.go(tester, '/patients');
    await search(tester, '98765');
    expect(find.text('Asha Rao'), findsOneWidget);
    expect(find.text('Ravi Kumar'), findsNothing);

    final asha = await env.repos.patients.getById(testPatientId);
    await search(tester, asha!.patientNumber);
    expect(find.text('Asha Rao'), findsOneWidget);
    expect(find.text('Ravi Kumar'), findsNothing);
  });

  testWidgets('no match shows an empty state', (tester) async {
    await env.pumpApp(tester);
    await env.go(tester, '/patients');
    await search(tester, 'zzz');
    expect(find.text('No results'), findsOneWidget);
  });

  testWidgets('tapping a row opens the detail page', (tester) async {
    await env.pumpApp(tester);
    await env.go(tester, '/patients');
    await tester.tap(find.text('Asha Rao'));
    await settle(tester, frames: 10);
    expect(env.location, '/patients/$testPatientId');
    expect(find.byKey(const ValueKey('qa-chart')), findsOneWidget);
  });
}
