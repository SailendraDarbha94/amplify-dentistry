import 'package:ampdent_mobile/core/placeholder_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Export and audit log routes (placeholder in this build).
final List<RouteBase> exportRoutes = [
  placeholderRoute('/export', 'Export', icon: Icons.download_outlined),
  placeholderRoute('/audit', 'Audit log', icon: Icons.history_outlined),
];
