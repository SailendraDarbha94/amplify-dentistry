import 'package:ampdent_mobile/core/placeholder_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Lab case routes (placeholder in this build).
final List<RouteBase> labRoutes = [
  placeholderRoute('/lab', 'Lab cases', icon: Icons.science_outlined),
  placeholderRoute('/lab/new', 'New lab case', icon: Icons.science_outlined),
  placeholderRoute('/lab/:caseId', 'Lab case', icon: Icons.science_outlined),
];
