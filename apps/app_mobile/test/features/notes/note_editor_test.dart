import 'package:ampdent_mobile/features/notes/note_editor_model.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_env.dart';

void main() {
  group('NoteDraft', () {
    test('folds intraoral sub-sections and splits them back', () {
      const draft = NoteDraft(
        sections: {
          'intraoralExamination': 'Generalised plaque',
          'intraoralSoftTissue': 'Gingiva inflamed',
          'intraoralHardTissue': 'Caries 36 occlusal',
          'treatmentPlan': 'Phase 1: scaling',
        },
      );
      final note = draft.toNote(
        id: 'n1',
        clinicId: 'c',
        patientId: 'p',
        visitId: 'v',
        authorId: 'm',
        now: DateTime.utc(2026, 10, 25),
      );
      expect(
        note.intraoralExam,
        'Generalised plaque\nSoft tissue: Gingiva inflamed\n'
        'Hard tissue: Caries 36 occlusal',
      );
      expect(note.freeText, 'Phase 1: scaling');
      final back = NoteDraft.fromNote(note);
      expect(back['intraoralExamination'], 'Generalised plaque');
      expect(back['intraoralSoftTissue'], 'Gingiva inflamed');
      expect(back['intraoralHardTissue'], 'Caries 36 occlusal');
      expect(back['treatmentPlan'], 'Phase 1: scaling');
      expect(back.filledKeys, [
        'intraoralExamination',
        'intraoralSoftTissue',
        'intraoralHardTissue',
        'treatmentPlan',
      ]);
    });
  });

  group('NoteSaver', () {
    late AppTestEnv env;
    final now = DateTime.utc(2026, 10, 25, 9);

    setUp(() async => env = await AppTestEnv.open(withPatient: true));
    tearDown(() => env.close());

    NoteSaver saver() => NoteSaver(
      clinical: env.repos.clinical,
      appointments: env.repos.appointments,
      ctx: testCtx,
    );

    test('opens a visit, saves, signs, and an edit makes version 2', () async {
      final first = await saver().save(
        patientId: testPatientId,
        draft: const NoteDraft(sections: {'chiefComplaint': 'Pain in 36'}),
        now: now,
      );
      expect(first.version, 1);
      expect(first.authorId, testDentistId);
      final visit = await env.repos.appointments.getVisit(first.visitId);
      expect(visit, isNotNull);
      expect(visit!.isOpen, isTrue);

      // Unsigned edits stay on the same row.
      final edited = await saver().save(
        patientId: testPatientId,
        draft: const NoteDraft(
          sections: {'chiefComplaint': 'Pain in 36 since 3 days'},
        ),
        existing: first,
        now: now,
      );
      expect(edited.id, first.id);
      expect(edited.version, 1);

      final signed = await saver().sign(first.id, now: now);
      expect(signed.isSigned, isTrue);

      final amended = await saver().save(
        patientId: testPatientId,
        draft: const NoteDraft(
          sections: {
            'chiefComplaint': 'Pain in 36 since 3 days',
            'finalDiagnosis': 'K04.0 Pulpitis',
          },
        ),
        existing: signed,
        now: now.add(const Duration(hours: 1)),
      );
      expect(amended.id, isNot(first.id));
      expect(amended.version, 2);
      expect(amended.supersedesNoteId, first.id);
      expect(amended.isSigned, isFalse);
      expect(amended.visitId, first.visitId);

      final versions = await env.repos.clinical.noteVersions(amended.id);
      expect(versions.map((n) => n.version), [1, 2]);
      final latest = await env.repos.clinical.notesForVisit(first.visitId);
      expect(latest.map((n) => n.id), [amended.id]);
    });
  });

  group('Note editor', () {
    late AppTestEnv env;

    setUp(() async => env = await AppTestEnv.open(withPatient: true));
    tearDown(() => env.close());

    testWidgets('save, sign, amend creates a second version', (tester) async {
      await env.pumpApp(tester);
      await env.go(tester, '/patients/$testPatientId/notes/new');
      expect(find.byKey(const ValueKey('note-save')), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('note-chiefComplaint')),
        'Pain in lower left molar',
      );
      await tester.tap(find.byKey(const ValueKey('note-save')));
      await settle(tester, frames: 10);
      expect(find.text('v1'), findsOneWidget);
      // A plain query: awaiting a stream inside FakeAsync would stall.
      final notes = await env.db.select(env.db.clinicalNotes).get();
      expect(notes, hasLength(1));

      // Let the "Note saved" snackbar clear the bottom bar.
      await tester.pump(const Duration(seconds: 5));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('note-sign')));
      await settle(tester);
      expect(find.byType(ConfirmSheet), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(ConfirmSheet),
          matching: find.text('Sign'),
        ),
      );
      await settle(tester, frames: 10);
      await tester.pump(const Duration(seconds: 5));
      await settle(tester);
      expect(find.byKey(const ValueKey('note-signed-badge')), findsOneWidget);
      expect(find.byKey(const ValueKey('note-amend')), findsOneWidget);
      expect(find.byKey(const ValueKey('note-save')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('note-amend')));
      await settle(tester);
      await tester.enterText(
        find.byKey(const ValueKey('note-chiefComplaint')),
        'Pain in 36, worse at night',
      );
      await tester.tap(find.byKey(const ValueKey('note-save')));
      await settle(tester, frames: 10);
      expect(find.text('v2'), findsOneWidget);
      expect(find.byKey(const ValueKey('note-signed-badge')), findsNothing);

      final versions = await env.repos.clinical.noteVersions(notes.first.id);
      expect(versions, hasLength(2));
      expect(versions.last.chiefComplaint, 'Pain in 36, worse at night');
      expect(versions.first.isSigned, isTrue);
      expect(versions.first.chiefComplaint, 'Pain in lower left molar');
    });

    testWidgets('notes page lists the note and opens the editor', (
      tester,
    ) async {
      await NoteSaver(
        clinical: env.repos.clinical,
        appointments: env.repos.appointments,
        ctx: testCtx,
      ).save(
        patientId: testPatientId,
        draft: const NoteDraft(sections: {'chiefComplaint': 'Bleeding gums'}),
      );
      await env.pumpApp(tester);
      await env.go(tester, '/patients/$testPatientId/notes');
      await settle(tester);
      expect(find.text('Bleeding gums'), findsOneWidget);
      await tester.tap(find.text('Bleeding gums'));
      await settle(tester, frames: 10);
      expect(
        env.location,
        matches(RegExp(r'^/patients/patient-test/notes/[^/]+$')),
      );
      expect(find.byKey(const ValueKey('note-versions')), findsOneWidget);
    });
  });
}
