import 'package:ampdent_mobile/core/placeholder_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Treatment plan and estimate routes (placeholder in this build).
final List<RouteBase> planRoutes = [
  placeholderRoute(
    '/patients/:id/plan',
    'Treatment plans',
    icon: Icons.assignment_outlined,
  ),
  placeholderRoute(
    '/patients/:id/plan/:planId',
    'Treatment plan',
    icon: Icons.assignment_outlined,
  ),
];
