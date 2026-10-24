import 'package:go_router/go_router.dart';

import 'today_page.dart';

/// The Today tab root.
final List<RouteBase> todayRoutes = [
  GoRoute(path: '/today', builder: (context, state) => const TodayPage()),
];
