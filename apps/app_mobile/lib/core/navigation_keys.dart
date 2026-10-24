import 'package:flutter/widgets.dart';

/// Root navigator. A feature route that must cover the bottom navigation
/// bar (full-screen chart, signature capture) passes this as
/// `parentNavigatorKey` on its `GoRoute`.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// Navigator of the shell that hosts the four tab branches.
final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'shell',
);
