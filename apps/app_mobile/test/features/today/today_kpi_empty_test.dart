import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../export/feature_harness.dart';

void main() {
  late FeatureTestEnv env;

  setUp(() async => env = await FeatureTestEnv.open(withPatient: true));
  tearDown(() => env.close());

  testWidgets('the no-show tile keeps its dash with an accessible label when '
      'nothing happened yet', (tester) async {
    final handle = tester.ensureSemantics();
    await env.pumpApp(tester);
    await settle(tester, frames: 12);
    final tile = find.byKey(const ValueKey('kpi-noshow'));
    expect(tile, findsOneWidget);
    expect(find.descendant(of: tile, matching: find.text('-')), findsOneWidget);
    expect(
      tester.getSemantics(tile).label,
      'No-show rate this month: no completed or missed appointments yet',
    );
    handle.dispose();
  });
}
