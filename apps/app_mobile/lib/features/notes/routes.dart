import 'package:go_router/go_router.dart';

import 'medical_history_page.dart';
import 'note_editor_page.dart';
import 'notes_page.dart';
import 'photos/photo_capture_page.dart';

/// Clinical notes, medical history and photo routes. Literal segments
/// (`new`, `history`, `photos/new`) are listed before `:noteId`.
final List<RouteBase> notesRoutes = [
  GoRoute(
    path: '/patients/:id/notes',
    builder: (context, state) =>
        NotesPage(patientId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/patients/:id/notes/new',
    builder: (context, state) =>
        NoteEditorPage(patientId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/patients/:id/notes/history',
    builder: (context, state) =>
        MedicalHistoryPage(patientId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/patients/:id/notes/photos/new',
    builder: (context, state) =>
        PhotoCapturePage(patientId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/patients/:id/notes/:noteId',
    builder: (context, state) => NoteEditorPage(
      patientId: state.pathParameters['id']!,
      noteId: state.pathParameters['noteId']!,
    ),
  ),
];
