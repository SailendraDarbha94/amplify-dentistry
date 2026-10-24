import 'package:go_router/go_router.dart';

import 'lab_case_detail_page.dart';
import 'lab_cases_page.dart';
import 'new_lab_case_page.dart';

/// Lab case routes. `/lab/new` is listed before `/lab/:caseId` so the
/// literal segment wins. `/lab/new` accepts `patientId` and `procedureId`.
final List<RouteBase> labRoutes = [
  GoRoute(path: '/lab', builder: (context, state) => const LabCasesPage()),
  GoRoute(
    path: '/lab/new',
    builder: (context, state) => NewLabCasePage(
      patientId: state.uri.queryParameters['patientId'],
      procedureId: state.uri.queryParameters['procedureId'],
    ),
  ),
  GoRoute(
    path: '/lab/:caseId',
    builder: (context, state) =>
        LabCaseDetailPage(caseId: state.pathParameters['caseId']!),
  ),
];
