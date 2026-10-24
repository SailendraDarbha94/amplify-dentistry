import 'package:ampdent_core/ampdent_core.dart';
import 'package:go_router/go_router.dart';

import 'chart_page.dart';
import 'perio_page.dart';

/// Odontogram (`/patients/:id/chart`, optional `?tooth=16` to preselect a
/// tooth) and perio chart (`/patients/:id/chart/perio`).
final List<RouteBase> chartRoutes = [
  GoRoute(
    path: '/patients/:id/chart',
    builder: (context, state) => ChartPage(
      patientId: state.pathParameters['id']!,
      initialTooth: ToothId.tryParse(state.uri.queryParameters['tooth'] ?? ''),
    ),
  ),
  GoRoute(
    path: '/patients/:id/chart/perio',
    builder: (context, state) =>
        PerioPage(patientId: state.pathParameters['id']!),
  ),
];
