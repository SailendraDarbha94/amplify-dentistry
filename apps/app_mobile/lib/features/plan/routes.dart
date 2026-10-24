import 'package:go_router/go_router.dart';

import 'plan_builder_page.dart';
import 'plan_list_page.dart';

/// Treatment plan routes: the patient's plan list and the plan builder.
final List<RouteBase> planRoutes = [
  GoRoute(
    path: '/patients/:id/plan',
    builder: (context, state) =>
        PlanListPage(patientId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/patients/:id/plan/:planId',
    builder: (context, state) => PlanBuilderPage(
      patientId: state.pathParameters['id']!,
      planId: state.pathParameters['planId']!,
    ),
  ),
];
