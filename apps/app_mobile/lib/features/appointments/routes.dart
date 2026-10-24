import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'appointment_detail_page.dart';
import 'appointment_form_page.dart';
import 'schedule_page.dart';

/// Appointment book routes: `/schedule` (day view), `/schedule/new`
/// (`?patientId=&at=&chairId=&procedureId=`) and `/schedule/:appointmentId`.
final List<RouteBase> appointmentsRoutes = [
  GoRoute(
    path: '/schedule',
    builder: (context, state) => const SchedulePage(),
    routes: [
      GoRoute(
        path: 'new',
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          child: AppointmentFormPage(
            patientId: state.uri.queryParameters['patientId'],
            at: state.uri.queryParameters['at'],
            chairId: state.uri.queryParameters['chairId'],
            procedureId: state.uri.queryParameters['procedureId'],
          ),
        ),
      ),
      GoRoute(
        path: ':appointmentId',
        builder: (context, state) => AppointmentDetailPage(
          appointmentId: state.pathParameters['appointmentId']!,
        ),
      ),
    ],
  ),
];
