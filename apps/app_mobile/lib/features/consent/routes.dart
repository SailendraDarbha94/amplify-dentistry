import 'package:ampdent_mobile/core/placeholder_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Procedure consent routes (placeholder in this build).
final List<RouteBase> consentRoutes = [
  placeholderRoute(
    '/patients/:id/consent/new',
    'New consent',
    icon: Icons.draw_outlined,
  ),
  placeholderRoute(
    '/patients/:id/consent/:consentId',
    'Consent',
    icon: Icons.draw_outlined,
  ),
];
