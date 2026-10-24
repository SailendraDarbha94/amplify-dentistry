import 'package:go_router/go_router.dart';

import 'compliance_page.dart';

/// Sterilisation log and licence wallet routes.
final List<RouteBase> complianceRoutes = [
  GoRoute(
    path: '/compliance',
    builder: (context, state) => CompliancePage(
      initialTab: state.uri.queryParameters['tab'] == 'licences' ? 1 : 0,
    ),
  ),
];
