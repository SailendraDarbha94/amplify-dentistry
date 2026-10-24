import 'package:ampdent_mobile/core/placeholder_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Appointment book routes (placeholder in this build).
final List<RouteBase> appointmentsRoutes = [
  placeholderRoute('/schedule', 'Schedule', icon: Icons.calendar_month),
  placeholderRoute(
    '/schedule/new',
    'New appointment',
    icon: Icons.event_available_outlined,
  ),
  placeholderRoute(
    '/schedule/:appointmentId',
    'Appointment',
    icon: Icons.event_outlined,
  ),
];
