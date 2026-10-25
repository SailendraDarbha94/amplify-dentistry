// On-device smoke test: boots the real app over an in-memory database and
// walks the first-day path of a clinic. Run it with
// `flutter test integration_test -d "iPhone 17"` from apps/app_mobile. The
// same flow runs as a widget test in `test/smoke_flow_test.dart`.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'smoke_flow.dart';
import 'smoke_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late SmokeEnv env;

  setUp(() async => env = await SmokeEnv.open());
  tearDown(() => env.close());

  testWidgets('onboarding to first paid invoice updates the Today KPIs', (
    tester,
  ) async {
    await env.pumpApp(tester);
    await runSmokeFlow(tester, env);
  });
}
