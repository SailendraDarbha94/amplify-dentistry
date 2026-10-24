import 'package:ampdent_mobile/core/placeholder_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Odontogram, findings and procedures routes (placeholder in this build).
final List<RouteBase> chartRoutes = [
  placeholderRoute('/patients/:id/chart', 'Chart', icon: Icons.grid_on),
  placeholderRoute(
    '/patients/:id/chart/perio',
    'Perio chart',
    icon: Icons.table_chart_outlined,
  ),
];
