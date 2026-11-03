/// Ties the cloud to the app lifecycle: starts the `SyncScheduler` whenever
/// a real engine appears, syncs and probes reachability on resume, probes
/// every [reachabilityProbeInterval] while the app is in the foreground
/// (with a throttled device heartbeat), and runs the clinic-link check once
/// when the app starts already signed in. No connectivity plugin: the
/// engine reports `offline` on failure and the probe retries.
library;

import 'dart:async';

import 'package:ampdent_data/ampdent_data.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'clinic_link.dart';
import 'cloud_config.dart';
import 'cloud_providers.dart';
import 'reachability.dart';
import 'whatsapp_cloud.dart';

/// Wrap the app in this once, above the router.
class CloudLifecycle extends ConsumerStatefulWidget {
  /// Creates the hook around [child].
  const CloudLifecycle({super.key, required this.child});

  /// The app.
  final Widget child;

  @override
  ConsumerState<CloudLifecycle> createState() => _CloudLifecycleState();
}

class _CloudLifecycleState extends ConsumerState<CloudLifecycle> {
  AppLifecycleListener? _listener;
  ProviderSubscription<SyncScheduler?>? _schedulerSub;
  Timer? _probeTimer;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onResume: _onResume,
      onStateChange: _onStateChange,
    );
    _schedulerSub = ref.listenManual(
      syncSchedulerProvider,
      (previous, next) => _start(next),
      fireImmediately: true,
    );
    _startProbing();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(clinicLinkProvider.notifier).ensureStarted());
    });
  }

  void _start(SyncScheduler? scheduler) {
    if (scheduler == null || !ref.read(schedulerEnabledProvider)) return;
    scheduler
      ..start()
      ..resume();
  }

  /// The app is in the foreground: probe every [reachabilityProbeInterval].
  void _startProbing() {
    _probeTimer?.cancel();
    _probeTimer = Timer.periodic(reachabilityProbeInterval, (_) => _probe());
  }

  /// Backgrounded: no probing, no heartbeats.
  void _stopProbing() {
    _probeTimer?.cancel();
    _probeTimer = null;
  }

  void _probe() {
    if (!mounted) return;
    unawaited(ref.read(reachabilityProbeProvider)());
  }

  void _onStateChange(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startProbing();
    } else {
      _stopProbing();
    }
  }

  void _onResume() {
    ref.read(syncSchedulerProvider)?.onAppResumed();
    ref.invalidate(whatsappStatusProvider);
    _probe();
  }

  @override
  void dispose() {
    _stopProbing();
    _schedulerSub?.close();
    _listener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
