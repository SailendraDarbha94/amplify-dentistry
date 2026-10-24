import 'package:go_router/go_router.dart';

import 'patient_detail_page.dart';
import 'patient_form_page.dart';
import 'patient_list_page.dart';

/// Patient list, add/edit form and detail. `/patients/new` is listed before
/// `/patients/:id` so the literal segment wins.
final List<RouteBase> patientsRoutes = [
  GoRoute(
    path: '/patients',
    builder: (context, state) => const PatientListPage(),
  ),
  GoRoute(
    path: '/patients/new',
    builder: (context, state) => const PatientFormPage(),
  ),
  GoRoute(
    path: '/patients/:id',
    builder: (context, state) =>
        PatientDetailPage(patientId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/patients/:id/edit',
    builder: (context, state) =>
        PatientFormPage(patientId: state.pathParameters['id']!),
  ),
];
