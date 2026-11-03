/// Reachability probing on the app's own cadence: the lifecycle hook runs
/// [reachabilityProbeProvider] on resume and every
/// [reachabilityProbeInterval] while the app is in the foreground. No
/// connectivity plugin: the scheduler's probe (`Reachability`, one short
/// request to the project's auth health endpoint) tells it whether the
/// backend answers, and a device that just came back online runs a sync
/// at once; the engine's own heartbeat then refreshes `devices.last_seen_at`.
library;

import 'package:ampdent_data/ampdent_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cloud_config.dart';
import 'cloud_providers.dart';

/// How often the foreground probe runs.
const Duration reachabilityProbeInterval = Duration(seconds: 60);

/// The server probe for the configured project, or null when the cloud is
/// not configured (the scheduler then keeps its connectivity flag as is).
/// Tests override it with a probe over a mock client, or with null.
final Provider<Reachability?> reachabilityProvider = Provider<Reachability?>((
  ref,
) {
  final config = ref.watch(cloudConfigProvider);
  if (!config.isConfigured) return null;
  final url = Uri.tryParse(config.url.trim());
  if (url == null || url.host.isEmpty) return null;
  return Reachability(supabaseUrl: url);
});

/// What the lifecycle hook runs on resume and on the probe timer: the
/// scheduler's reachability probe, when a scheduler exists. Tests override
/// it to count calls.
final Provider<Future<void> Function()> reachabilityProbeProvider =
    Provider<Future<void> Function()>(
      (ref) => () async {
        final scheduler = ref.read(syncSchedulerProvider);
        if (scheduler == null) return;
        await scheduler.probeReachability();
      },
    );
