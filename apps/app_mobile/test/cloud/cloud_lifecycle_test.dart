import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_mobile/core/clinic_link.dart';
import 'package:ampdent_mobile/core/cloud_config.dart' show appBuildVersion;
import 'package:ampdent_mobile/core/device_info.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/core/reachability.dart';
import 'package:ampdent_mobile/core/remote_devices.dart'
    show devicePlatformName;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'cloud_test_support.dart';

/// Lifecycle wiring: the reachability probe runs on resume and every 60 s
/// while the app is in the foreground, stops in the background, and the
/// engine carries this install's `DeviceInfo` for heartbeats.
void main() {
  group('probe timer', () {
    late AppTestEnv env;
    var probes = 0;

    setUp(() async {
      probes = 0;
      env = await AppTestEnv.open(
        overrides: [
          reachabilityProbeProvider.overrideWithValue(() async => probes++),
        ],
      );
    });
    tearDown(() => env.close());

    /// Walks the binding through the valid transitions to [target].
    void moveTo(WidgetTester tester, AppLifecycleState target) {
      final path = target == AppLifecycleState.paused
          ? const [
              AppLifecycleState.inactive,
              AppLifecycleState.hidden,
              AppLifecycleState.paused,
            ]
          : const [
              AppLifecycleState.hidden,
              AppLifecycleState.inactive,
              AppLifecycleState.resumed,
            ];
      for (final s in path) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
    }

    testWidgets('every 60 s in the foreground, on resume, never in the '
        'background', (tester) async {
      await env.pumpApp(tester);
      expect(probes, 0, reason: 'nothing until the first minute');

      await tester.pump(reachabilityProbeInterval);
      expect(probes, 1);
      await tester.pump(reachabilityProbeInterval);
      expect(probes, 2);

      moveTo(tester, AppLifecycleState.paused);
      await tester.pump();
      await tester.pump(reachabilityProbeInterval * 3);
      expect(probes, 2, reason: 'backgrounded: timer stopped');

      moveTo(tester, AppLifecycleState.resumed);
      await tester.pump();
      expect(probes, 3, reason: 'resume probes at once');
      await tester.pump(reachabilityProbeInterval);
      expect(probes, 4, reason: 'and the timer runs again');
    });
  });

  group('wiring', () {
    late FakeSupabase fake;

    setUp(() => fake = FakeSupabase());

    test('the engine carries this install\'s DeviceInfo', () async {
      final env = await openCloudEnv(fake);
      addTearDown(env.close);
      await signIn(env.container, fake);
      expect((await runLink(env.container)).phase, LinkPhase.linked);
      final engine = env.container.read(syncEngineProvider);
      expect(engine, isA<SupabaseSyncEngine>());
      final info = (engine as SupabaseSyncEngine).deviceInfo;
      expect(info, isNotNull);
      expect(info!.appVersion, appBuildVersion);
      expect(info.platform, devicePlatform());
      expect(info.platform.name, devicePlatformName());
    });

    test('the default probe feeds the scheduler\'s reachability', () async {
      var health = 0;
      final probe = Reachability(
        supabaseUrl: Uri.parse('http://localhost:54321'),
        client: MockClient((req) async {
          health++;
          return http.Response('', 200);
        }),
      );
      final env = await AppTestEnv.open(
        cloudClient: fake.client(),
        reachability: probe,
      );
      addTearDown(env.close);
      await signIn(env.container, fake);
      expect((await runLink(env.container)).phase, LinkPhase.linked);
      final scheduler = env.container.read(syncSchedulerProvider)!;
      expect(scheduler.reachability, same(probe));

      await env.container.read(reachabilityProbeProvider)();
      expect(health, 1);
      expect(probe.lastResult, isTrue);
      expect(scheduler.isOnline, isTrue);
    });

    test('without a scheduler the probe is a no-op', () async {
      final env = await AppTestEnv.open();
      addTearDown(env.close);
      expect(env.container.read(syncSchedulerProvider), isNull);
      await env.container.read(reachabilityProbeProvider)();
    });
  });
}
