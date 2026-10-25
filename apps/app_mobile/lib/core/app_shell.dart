import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_strings.dart';
import 'providers.dart';

/// Key for the app's root [ScaffoldMessenger] (the one `MaterialApp.router`
/// in `main.dart` owns; pass it as `scaffoldMessengerKey` there). A page
/// that shows a SnackBar whose action may fire after the page is gone (the
/// chart's "Add to bill") shows it through this key, falling back to
/// `ScaffoldMessenger.of` until the key is bound. The shell deliberately
/// does not nest a second messenger: nested messengers split SnackBars
/// between two hosts and the test harnesses only clear the root one.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>(debugLabel: 'rootMessenger');

/// Shell around the four tab branches: bottom navigation on phones, a rail
/// on wider screens, with the single pending-sync banner inside the top
/// safe area. Pages never render their own copy of the banner.
class AppShell extends ConsumerWidget {
  /// Creates the shell for [navigationShell].
  const AppShell({super.key, required this.navigationShell});

  /// The stateful shell supplied by go_router.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final sync = ref.watch(syncStateProvider).value;
    final pending = sync?.pendingCount ?? 0;
    return AdaptiveScaffold(
      body: navigationShell,
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: (index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      ),
      // Null (not an empty banner) when nothing is pending, so the body
      // keeps its own top inset; see AdaptiveScaffold.banner.
      banner: pending > 0
          ? OfflineBanner(
              key: const ValueKey('shell-sync-banner'),
              isOffline: false,
              pendingCount: pending,
            )
          : null,
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
