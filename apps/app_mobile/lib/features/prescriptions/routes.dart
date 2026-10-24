import 'package:go_router/go_router.dart';

import 'prescription_detail_page.dart';
import 'prescription_editor_page.dart';
import 'prescription_list_page.dart';

/// Prescription routes. `new` is listed before `:rxId`; `?repeatOf=<id>`
/// pre-fills the editor from an earlier prescription.
final List<RouteBase> prescriptionsRoutes = [
  GoRoute(
    path: '/patients/:id/prescriptions',
    builder: (context, state) =>
        PrescriptionListPage(patientId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/patients/:id/prescriptions/new',
    builder: (context, state) => PrescriptionEditorPage(
      patientId: state.pathParameters['id']!,
      repeatOfId: state.uri.queryParameters['repeatOf'],
    ),
  ),
  GoRoute(
    path: '/patients/:id/prescriptions/:rxId',
    builder: (context, state) => PrescriptionDetailPage(
      patientId: state.pathParameters['id']!,
      prescriptionId: state.pathParameters['rxId']!,
    ),
  ),
];
