import 'package:ampdent_mobile/core/placeholder_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Prescription routes (placeholder in this build).
final List<RouteBase> prescriptionsRoutes = [
  placeholderRoute(
    '/patients/:id/prescriptions',
    'Prescriptions',
    icon: Icons.medication_outlined,
  ),
  placeholderRoute(
    '/patients/:id/prescriptions/new',
    'New prescription',
    icon: Icons.medication_outlined,
  ),
];
