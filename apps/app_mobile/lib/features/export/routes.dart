import 'package:go_router/go_router.dart';

import 'audit_page.dart';
import 'data_ownership_page.dart';
import 'export_page.dart';

/// Export, data-ownership statement and audit log routes.
final List<RouteBase> exportRoutes = [
  GoRoute(path: '/export', builder: (context, state) => const ExportPage()),
  GoRoute(
    path: '/export/data-ownership',
    builder: (context, state) => const DataOwnershipPage(),
  ),
  GoRoute(path: '/audit', builder: (context, state) => const AuditPage()),
];
