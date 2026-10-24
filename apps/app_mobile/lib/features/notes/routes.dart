import 'package:ampdent_mobile/core/placeholder_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Clinical notes, medical history and photo routes (placeholder in this
/// build).
final List<RouteBase> notesRoutes = [
  placeholderRoute(
    '/patients/:id/notes',
    'Clinical notes',
    icon: Icons.notes_outlined,
  ),
  placeholderRoute(
    '/patients/:id/notes/new',
    'New clinical note',
    icon: Icons.note_add_outlined,
  ),
];
