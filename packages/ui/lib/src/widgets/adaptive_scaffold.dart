import 'package:flutter/material.dart';

/// One top-level destination for [AdaptiveScaffold].
@immutable
class AdaptiveDestination {
  /// Creates a destination.
  const AdaptiveDestination({
    required this.icon,
    required this.label,
    this.selectedIcon,
    this.badgeCount,
  });

  /// Icon when unselected.
  final IconData icon;

  /// Icon when selected; defaults to [icon].
  final IconData? selectedIcon;

  /// Short label.
  final String label;

  /// Optional count badge.
  final int? badgeCount;

  Widget _icon(IconData data) => badgeCount != null && badgeCount! > 0
      ? Badge.count(count: badgeCount!, child: Icon(data))
      : Icon(data);

  /// Unselected icon widget.
  Widget get iconWidget => _icon(icon);

  /// Selected icon widget.
  Widget get selectedIconWidget => _icon(selectedIcon ?? icon);
}

/// Scaffold that places primary navigation in a bottom [NavigationBar] on
/// phones and a leading [NavigationRail] once the width reaches
/// [railBreakpoint] (600 px, Material's medium window class).
class AdaptiveScaffold extends StatelessWidget {
  /// Creates an adaptive scaffold.
  const AdaptiveScaffold({
    super.key,
    required this.body,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.appBar,
    this.floatingActionButton,
    this.banner,
    this.railLeading,
    this.railTrailing,
    this.backgroundColor,
  }) : assert(destinations.length >= 2, 'Need at least two destinations');

  /// Width at or above which the rail replaces the bottom bar.
  static const double railBreakpoint = 600;

  /// Screen content.
  final Widget body;

  /// Top-level destinations (2-5 on phones).
  final List<AdaptiveDestination> destinations;

  /// Index of the active destination.
  final int selectedIndex;

  /// Called when a destination is tapped.
  final ValueChanged<int> onDestinationSelected;

  /// Optional app bar.
  final PreferredSizeWidget? appBar;

  /// Optional FAB (placed in the rail's leading slot on wide layouts).
  final Widget? floatingActionButton;

  /// Optional banner above the body (e.g. an `OfflineBanner`).
  final Widget? banner;

  /// Widget above the rail destinations; defaults to the FAB when present.
  final Widget? railLeading;

  /// Widget below the rail destinations.
  final Widget? railTrailing;

  /// Scaffold background override.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= railBreakpoint;
        final content = banner == null
            ? body
            : Column(
                children: [
                  banner!,
                  Expanded(child: body),
                ],
              );
        if (wide) {
          return Scaffold(
            appBar: appBar,
            backgroundColor: backgroundColor,
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  leading: railLeading ?? floatingActionButton,
                  trailing: railTrailing,
                  groupAlignment: -0.9,
                  destinations: [
                    for (final d in destinations)
                      NavigationRailDestination(
                        icon: d.iconWidget,
                        selectedIcon: d.selectedIconWidget,
                        label: Text(d.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            ),
          );
        }
        return Scaffold(
          appBar: appBar,
          backgroundColor: backgroundColor,
          body: content,
          floatingActionButton: floatingActionButton,
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            destinations: [
              for (final d in destinations)
                NavigationDestination(
                  icon: d.iconWidget,
                  selectedIcon: d.selectedIconWidget,
                  label: d.label,
                ),
            ],
          ),
        );
      },
    );
  }
}
