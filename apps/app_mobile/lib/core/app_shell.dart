import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_strings.dart';
import 'providers.dart';

/// Shell around the four tab branches: bottom navigation on phones, a rail
/// on wider screens, with the offline / pending-sync banner on top.
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
      banner: OfflineBanner(isOffline: false, pendingCount: pending),
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
