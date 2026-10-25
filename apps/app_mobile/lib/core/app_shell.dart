import 'dart:async';

import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_strings.dart';
import 'providers.dart';
import 'sync_banner.dart';

/// Key for the app's root [ScaffoldMessenger] (the one `MaterialApp.router`
/// in `main.dart` owns; pass it as `scaffoldMessengerKey` there). A page
/// that shows a SnackBar whose action may fire after the page is gone (the
/// chart's "Add to bill") shows it through this key, falling back to
/// `ScaffoldMessenger.of` until the key is bound. The shell deliberately
/// does not nest a second messenger: nested messengers split SnackBars
/// between two hosts and the test harnesses only clear the root one.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>(debugLabel: 'rootMessenger');

/// Key of the single sync banner in the shell.
const ValueKey<String> shellSyncBannerKey = ValueKey('shell-sync-banner');

/// Shell around the four tab branches: bottom navigation on phones, a rail
/// on wider screens, with the single sync banner inside the top safe area.
/// Pages never render their own copy of the banner.
///
/// Without a cloud engine the banner only says that writes are waiting;
/// with one it shows the real state (offline, waiting, syncing, synced at
/// hh:mm for a moment, error with tap-to-retry).
class AppShell extends ConsumerStatefulWidget {
  /// Creates the shell for [navigationShell].
  const AppShell({super.key, required this.navigationShell});

  /// The stateful shell supplied by go_router.
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  /// Rebuilds once the "Synced at" window has passed so the banner hides.
  void _scheduleHide(SyncState state, DateTime now) {
    _hideTimer?.cancel();
    final remaining = syncedBannerRemaining(state, now);
    if (remaining == null) return;
    _hideTimer = Timer(remaining + const Duration(milliseconds: 50), () {
      if (mounted) setState(() {});
    });
  }

  Widget? _banner(BuildContext context, SyncState? sync) {
    if (sync == null) return null;
    final pending = sync.pendingCount;
    if (sync.status == SyncStatus.disabled) {
      // Null (not an empty banner) when nothing is pending, so the body
      // keeps its own top inset; see AdaptiveScaffold.banner.
      return pending > 0
          ? OfflineBanner(
              key: shellSyncBannerKey,
              isOffline: false,
              pendingCount: pending,
            )
          : null;
    }
    final now = ref.read(clockProvider)();
    final spec = syncBannerSpec(sync, strings: context.strings, now: now);
    _scheduleHide(sync, now);
    if (spec == null) return null;
    return CloudSyncBanner(
      key: shellSyncBannerKey,
      spec: spec,
      onRetry: () => unawaited(ref.read(syncNowProvider)()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final shell = widget.navigationShell;
    final sync = ref.watch(syncStateProvider).value;
    return AdaptiveScaffold(
      body: shell,
      selectedIndex: shell.currentIndex,
      onDestinationSelected: (index) =>
          shell.goBranch(index, initialLocation: index == shell.currentIndex),
      banner: _banner(context, sync),
      destinations: [
        AdaptiveDestination(
          icon: Icons.today_outlined,
          selectedIcon: Icons.today,
          label: s.today,
        ),
        AdaptiveDestination(
          icon: Icons.people_outline,
          selectedIcon: Icons.people,
          label: s.patients,
        ),
        AdaptiveDestination(
          icon: Icons.calendar_month_outlined,
          selectedIcon: Icons.calendar_month,
          label: s.schedule,
        ),
        AdaptiveDestination(
          icon: Icons.more_horiz,
          selectedIcon: Icons.more_horiz,
          label: s.more,
        ),
      ],
    );
  }
}
