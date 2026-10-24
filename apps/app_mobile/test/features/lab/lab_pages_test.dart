import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/features/lab/lab_case_detail_page.dart';
import 'package:ampdent_mobile/features/lab/lab_directory.dart';
import 'package:ampdent_mobile/features/lab/new_lab_case_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../recall/feature_harness.dart';

void main() {
  late FeatureHarness h;

  setUp(() async {
    h = await FeatureHarness.open(initialLocation: '/lab');
    await h.env.repos.labs.upsertLab(testCtx, labFixture(days: 5));
  });
  tearDown(() => h.close());

  testWidgets('cases list groups by status and highlights overdue', (
    tester,
  ) async {
    final labs = h.env.repos.labs;
    await labs.createCase(testCtx, labCaseFixture(id: 'fresh'));
    await labs.createCase(
      testCtx,
      labCaseFixture(
        id: 'late',
        status: LabCaseStatus.sent,
        sentAt: h.now.subtract(const Duration(days: 10)),
        dueAt: h.now.subtract(const Duration(days: 2)),
      ),
    );
    await h.pumpApp(tester);
    await h.go(tester, '/lab');
    expect(find.byKey(const ValueKey('lab-group-created')), findsOneWidget);
    expect(find.byKey(const ValueKey('lab-group-sent')), findsOneWidget);
    expect(find.byKey(const ValueKey('lab-case-row-fresh')), findsOneWidget);
    expect(find.byKey(const ValueKey('lab-case-row-late')), findsOneWidget);
    expect(find.text('1 overdue'), findsOneWidget);
    expect(
      find.textContaining('Crown - Zirconia  ·  16  ·  A2'),
      findsNWidgets(2),
    );
  });

  testWidgets('detail page walks the status buttons and stamps timestamps', (
    tester,
  ) async {
    await h.env.repos.labs.createCase(testCtx, labCaseFixture(id: 'c1'));
    await h.pumpApp(tester);
    await h.go(tester, '/lab/c1');
    expect(
      find.byKey(const ValueKey('labcase-status-created')),
      findsOneWidget,
    );

    Future<void> mark(String status) async {
      final key = ValueKey('labcase-mark-$status');
      await h.scrollTo(tester, find.byKey(key), page: LabCaseDetailPage);
      await tester.tap(find.byKey(key));
      await settle(tester, frames: 10);
    }

    await mark('sent');
    var c = (await h.env.repos.labs.getCase('c1'))!;
    expect(c.status, LabCaseStatus.sent);
    expect(c.sentAt, h.now.toUtc());
    expect(c.dueAt, computeDueDate(h.now.toUtc(), 5));
    await h.scrollTo(
      tester,
      find.byKey(const ValueKey('labcase-status-sent')),
      page: LabCaseDetailPage,
      delta: -160,
    );
    expect(find.byKey(const ValueKey('labcase-notify')), findsNothing);

    await mark('received');
    c = (await h.env.repos.labs.getCase('c1'))!;
    expect(c.status, LabCaseStatus.received);
    expect(c.receivedAt, h.now.toUtc());
    await h.scrollTo(
      tester,
      find.byKey(const ValueKey('labcase-notify')),
      page: LabCaseDetailPage,
    );
    expect(find.byKey(const ValueKey('labcase-book')), findsOneWidget);

    await mark('qualityChecked');
    c = (await h.env.repos.labs.getCase('c1'))!;
    expect(c.qualityCheckedAt, h.now.toUtc());

    await mark('fitted');
    c = (await h.env.repos.labs.getCase('c1'))!;
    expect(c.status, LabCaseStatus.fitted);
    expect(c.fittedAt, h.now.toUtc());
    await h.scrollTo(
      tester,
      find.byKey(const ValueKey('labcase-status-fitted')),
      page: LabCaseDetailPage,
      delta: -160,
    );
    expect(find.byKey(const ValueKey('labcase-remake')), findsNothing);
  });

  testWidgets('received case messages the patient with LAB_READY_SEAT_APPT', (
    tester,
  ) async {
    await h.consent(DataPurpose.recallReminders);
    await h.env.repos.labs.createCase(
      testCtx,
      labCaseFixture(
        id: 'c2',
        status: LabCaseStatus.received,
        sentAt: h.now.subtract(const Duration(days: 6)),
        dueAt: h.now.subtract(const Duration(days: 1)),
      ),
    );
    await h.pumpApp(tester);
    await h.go(tester, '/lab/c2');
    await h.scrollTo(
      tester,
      find.byKey(const ValueKey('labcase-notify')),
      page: LabCaseDetailPage,
    );
    await tester.tap(find.byKey(const ValueKey('labcase-notify')));
    await settle(tester, frames: 10);
    final logs = await h.env.repos.messages.forPatient(testPatientId);
    expect(logs.single.templateCode, 'LAB_READY_SEAT_APPT');
    expect(logs.single.renderedPreview, contains('zirconia crown'));
    expect(logs.single.status, MessageStatus.sent);
    expect(h.launched.single.host, 'wa.me');
  });

  testWidgets('remake asks for a reason and opens the linked case', (
    tester,
  ) async {
    await h.env.repos.labs.createCase(
      testCtx,
      labCaseFixture(
        id: 'c3',
        status: LabCaseStatus.received,
        sentAt: h.now.subtract(const Duration(days: 6)),
        dueAt: h.now.subtract(const Duration(days: 1)),
      ),
    );
    await h.pumpApp(tester);
    await h.go(tester, '/lab/c3');
    await h.scrollTo(
      tester,
      find.byKey(const ValueKey('labcase-remake')),
      page: LabCaseDetailPage,
    );
    await tester.tap(find.byKey(const ValueKey('labcase-remake')));
    await settle(tester);
    final confirm = find.byKey(const ValueKey('reason-confirm'));
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await h.confirmReason(tester, 'Open margin');

    final original = (await h.env.repos.labs.getCase('c3'))!;
    expect(original.status, LabCaseStatus.remakeRequested);
    expect(original.remakeReason, 'Open margin');
    final cases = await h.env.repos.labs.casesForPatient(testPatientId);
    final remake = cases.singleWhere((c) => c.remakeOfCaseId == 'c3');
    expect(h.location, '/lab/${remake.id}');
    expect(find.text('Remake'), findsOneWidget);
  });

  testWidgets('new case from a procedure prefills teeth and type, then saves', (
    tester,
  ) async {
    await h.env.repos.chart.createProcedure(
      testCtx,
      procedureFixture(
        id: 'crn-16',
        code: 'CRN-PFM',
        name: 'PFM crown',
        status: ProcedureStatus.accepted,
        tooth: '16',
      ),
    );
    await h.pumpApp(tester);
    await h.go(tester, '/lab/new?patientId=$testPatientId&procedureId=crn-16');
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('labcase-teeth')))
          .controller!
          .text,
      '16',
    );
    expect(find.text('Crown - PFM'), findsOneWidget);
    expect(find.byKey(const ValueKey('labcase-due-preview')), findsOneWidget);

    await h.scrollTo(
      tester,
      find.byKey(const ValueKey('labcase-shade-A3.5')),
      page: NewLabCasePage,
    );
    await tester.tap(find.byKey(const ValueKey('labcase-shade-A3.5')));
    await settle(tester);
    await h.scrollTo(
      tester,
      find.byKey(const ValueKey('labcase-fee')),
      page: NewLabCasePage,
    );
    await tester.enterText(find.byKey(const ValueKey('labcase-fee')), '2500');
    await h.scrollTo(
      tester,
      find.byKey(const ValueKey('labcase-save')),
      page: NewLabCasePage,
    );
    await tester.tap(find.byKey(const ValueKey('labcase-save')));
    await settle(tester, frames: 12);

    final cases = await h.env.repos.labs.casesForPatient(testPatientId);
    expect(cases, hasLength(1));
    final c = cases.single;
    expect(c.caseType, LabCaseType.crownPfm);
    expect(c.teeth, [ToothId.parse('16')]);
    expect(c.shade, 'A3.5');
    expect(c.labFee, const Money.rupees(2500));
    expect(c.procedureId, 'crn-16');
    expect(c.labId, 'lab-1');
    expect((await h.env.repos.chart.getProcedure('crn-16'))!.labCaseId, c.id);
    expect(h.location, '/lab/${c.id}');
  });

  testWidgets('labs tab lists labs and adds one with per-type turnaround', (
    tester,
  ) async {
    await h.pumpApp(tester);
    await h.go(tester, '/lab');
    await tester.tap(find.byKey(const ValueKey('lab-tab-labs')));
    await settle(tester, frames: 8);
    expect(find.byKey(const ValueKey('labs-dir-row-lab-1')), findsOneWidget);
    expect(find.textContaining('5 working days'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('labs-dir-add')));
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('lab-edit-name')),
      'Smile Lab',
    );
    await h.scrollTo(
      tester,
      find.byKey(const ValueKey('lab-edit-days-completeDenture')),
      page: LabEditSheet,
    );
    await tester.enterText(
      find.byKey(const ValueKey('lab-edit-days-completeDenture')),
      '10',
    );
    await h.scrollTo(
      tester,
      find.byKey(const ValueKey('lab-edit-save')),
      page: LabEditSheet,
    );
    await tester.tap(find.byKey(const ValueKey('lab-edit-save')));
    await settle(tester, frames: 10);

    final labs = await h.env.repos.labs.labs(testClinicId);
    expect(
      labs.map((l) => l.name),
      containsAll(['Smile Lab', 'Precision Dental Lab']),
    );
    final smile = labs.singleWhere((l) => l.name == 'Smile Lab');
    expect(smile.turnaroundFor(LabCaseType.completeDenture), 10);
    expect(smile.turnaroundFor(LabCaseType.crownZirconia), 7);
  });
}
