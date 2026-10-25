// Widget-test twin of integration_test/smoke_test.dart: the same first-day
// flow on a 360 x 800 surface with the Ahem font, so the end-to-end path is
// checked on every `flutter test` run without a device.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/smoke_flow.dart';
import '../integration_test/smoke_support.dart';

void main() {
  late SmokeEnv env;

  setUp(() async => env = await SmokeEnv.open());
  tearDown(() => env.close());

  testWidgets('onboarding to first paid invoice updates the Today KPIs', (
    tester,
  ) async {
    await env.pumpApp(tester, surface: const Size(360, 800));
    await runSmokeFlow(tester, env);
  });
}
