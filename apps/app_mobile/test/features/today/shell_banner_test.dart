import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_env.dart';

void main() {
  late AppTestEnv env;

  setUp(() async => env = await AppTestEnv.open(withPatient: true));
  tearDown(() => env.close());

  testWidgets('one pending-sync banner, inside the safe area, with honest '
      'copy', (tester) async {
    // A status bar / Dynamic Island inset.
    tester.view.padding = const FakeViewPadding(top: 47);
    addTearDown(tester.view.resetPadding);
    await env.pumpApp(tester);
    await settle(tester, frames: 12);
    expect(env.location, '/today');

    // The fixtures wrote outbox rows, so the banner is up.
    final pending = await env.repos.outbox.pendingCount(testClinicId);
    expect(pending, greaterThan(0));

    final banner = find.byType(OfflineBanner);
    expect(banner, findsOneWidget);
    expect(find.byKey(const ValueKey('shell-sync-banner')), findsOneWidget);
    expect(find.byKey(const ValueKey('today-offline-banner')), findsNothing);
    expect(tester.getTopLeft(banner).dy, 47);
    expect(
      find.text('Not synced yet - $pending changes waiting'),
      findsOneWidget,
    );
    expect(find.textContaining('Syncing'), findsNothing);

    // The page's app bar starts right under the banner: no second inset.
    final appBar = find.byType(AppBar);
    expect(appBar, findsOneWidget);
    expect(tester.getTopLeft(appBar).dy, tester.getBottomLeft(banner).dy);
    expect(tester.getSize(appBar).height, kToolbarHeight);
  });
}
