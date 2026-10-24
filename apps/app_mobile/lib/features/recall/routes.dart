import 'package:go_router/go_router.dart';

import 'recall_page.dart';

/// Recall list routes.
final List<RouteBase> recallRoutes = [
  GoRoute(path: '/recall', builder: (context, state) => const RecallPage()),
];
