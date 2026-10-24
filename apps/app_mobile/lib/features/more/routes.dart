import 'package:go_router/go_router.dart';

import 'more_page.dart';

/// The More tab root.
final List<RouteBase> moreRoutes = [
  GoRoute(path: '/more', builder: (context, state) => const MorePage()),
];
