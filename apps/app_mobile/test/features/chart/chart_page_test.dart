import 'package:ampdent_chart_engine/ampdent_chart_engine.dart';
import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/features/plan/plan_model.dart';
import 'package:ampdent_mobile/features/plan/plan_providers.dart'
    show planServiceProvider;
import 'package:ampdent_terminology/ampdent_terminology.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chart_test_support.dart';

const String chartPath = '/patients/$testPatientId/chart';

void main() {
  late ChartTestEnv env;

  setUp(() async {
    env = await ChartTestEnv.open();
  });
  tearDown(() => env.close());

  Future<ProcedureRecord> plan(
    String code, {
    ToothId? tooth,
    SurfaceSet surfaces = const SurfaceSet.empty(),
  }) async {
    final item = (await env.repos.catalog.byCode(testClinicId, code))!;
    final now = DateTime.now().toUtc();
    return env.repos.chart.createProcedure(
      testCtx,
      ProcedureRecord(
        id: 'proc-$code',
        clinicId: testClinicId,
        patientId: testPatientId,
        catalogItemId: item.id,
        code: item.code,
        name: item.name,
        tooth: tooth,
        surfaces: surfaces,
        treatmentArea: item.treatmentArea,
        providerId: testDentistId,
        fee: item.defaultFee,
        totalStages: item.stages.isEmpty ? 1 : item.stages.length,
        stageNames: item.stages,
        plannedAt: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Odontogram odontogram(WidgetTester tester) =>
      tester.widget<Odontogram>(find.byKey(const ValueKey('chart-odontogram')));

  testWidgets('first open seeds age-default tooth states in one audited '
      'batch', (tester) async {
    expect(await env.repos.chart.currentStates(testPatientId), isEmpty);
    await env.pumpAt(tester, chartPath);

    final history = await env.repos.chart.toothStateHistory(testPatientId);
    expect(history.length, 52);
    expect(
      history.every((r) => r.source == ToothStateSource.ageDefault),
      isTrue,
    );
    // One batch: every audit event of the seed carries the same instant.
    final events = (await env.repos.audit.inRange(
      testClinicId,
      DateTime.utc(2000),
      DateTime.utc(2100),
    )).where((e) => e.entityType == 'ToothStateRecord').toList();
    expect(events.length, 52);
    expect(events.map((e) => e.occurredAt).toSet(), hasLength(1));
    expect(events.every((e) => e.action == AuditAction.create), isTrue);
    expect(
      await env.repos.outbox.pendingCount(testClinicId),
      greaterThanOrEqualTo(52),
    );
    final states = await env.repos.chart.currentStates(testPatientId);
    // Asha is 36: permanent teeth present, primary teeth exfoliated.
    expect(states[ToothId.parse('16')], ToothState.present);
    expect(states[ToothId.parse('18')], ToothState.present);
    expect(states[ToothId.parse('55')], ToothState.exfoliated);
    expect(find.byKey(const ValueKey('chart-odontogram')), findsOneWidget);
    expect(odontogram(tester).teeth.length, 52);
    expect(odontogram(tester).mixedDentition, isFalse);
    expect(find.text('No procedures charted yet'), findsOneWidget);

    // Reopening does not seed again.
    await env.go(tester, '/patients');
    await env.go(tester, chartPath);
    expect((await env.repos.chart.toothStateHistory(testPatientId)).length, 52);
  });

  testWidgets('a child defaults to the mixed-dentition view', (tester) async {
    await env.addPatient(
      testPatient(
        id: 'child-1',
        firstName: 'Kiran',
        dateOfBirth: DateTime.now().toUtc().subtract(
          const Duration(days: 365 * 8),
        ),
      ),
    );
    await env.pumpAt(tester, '/patients/child-1/chart');
    expect(odontogram(tester).mixedDentition, isTrue);
    final states = await env.repos.chart.currentStates('child-1');
    expect(states[ToothId.parse('55')], ToothState.present);
    expect(states[ToothId.parse('17')], ToothState.unerupted);
  });

  testWidgets('adding a caries finding on 16 MO shows an overlay', (
    tester,
  ) async {
    await env.pumpAt(tester, '$chartPath?tooth=16');
    expect(find.byKey(const ValueKey('chart-action-finding')), findsOneWidget);
    expect(odontogram(tester).selectedTooth, ToothId.parse('16'));

    await tapKey(tester, 'chart-action-finding');
    expect(find.byKey(const ValueKey('finding-save')), findsOneWidget);
    await tapKey(tester, 'finding-icdas-5');
    await tapKey(tester, 'chart-surface-M');
    await tapKey(tester, 'chart-surface-O');
    await tapKey(tester, 'finding-save', frames: 15);

    final findings = await env.repos.chart.findings(testPatientId);
    expect(findings.length, 1);
    final f = findings.single;
    expect(f.tooth, ToothId.parse('16'));
    expect(f.surfaces.code, 'MO');
    expect(f.icdas, IcdasCode.distinctCavity);
    expect(f.icd10Code, 'K02.1');

    final visual = odontogram(tester).teeth[ToothId.parse('16')]!;
    expect(
      visual.overlays,
      contains(
        ToothOverlay(
          kind: OverlayKind.caries,
          surfaces: SurfaceSet.parse('MO'),
        ),
      ),
    );
    expect(visual.badgeCount, 1);
    // The sheet closed and the surface selection was cleared.
    expect(find.byKey(const ValueKey('finding-save')), findsNothing);
    expect(odontogram(tester).selectedSurfaces.isEmpty, isTrue);
  });

  testWidgets('marking an RCT stage asks for consent and the pre-op '
      'radiograph once and advances stageIndex', (tester) async {
    final rct = await plan('RCT-MOL', tooth: ToothId.parse('16'));
    expect(rct.totalStages, rctStages.length);
    await env.pumpAt(tester, chartPath);

    await tapKey(tester, 'proc-done-${rct.id}');
    // No consent on record: the consent guard comes first and blocks until a
    // reason is typed.
    expect(find.byKey(const ValueKey('consent-reason')), findsOneWidget);
    expect(find.byKey(const ValueKey('preop-reason')), findsNothing);
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('consent-confirm')))
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const ValueKey('consent-reason')),
      'Verbal consent, form to follow',
    );
    await tester.pump();
    await tapKey(tester, 'consent-confirm', frames: 15);
    // No radiograph on record: the guard dialog blocks until a reason is typed.
    expect(find.byKey(const ValueKey('preop-reason')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('preop-confirm')))
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const ValueKey('preop-reason')),
      'Patient declined radiograph after counselling',
    );
    await tester.pump();
    await tapKey(tester, 'preop-confirm', frames: 15);

    var p = (await env.repos.chart.getProcedure(rct.id))!;
    expect(p.status, ProcedureStatus.inProgress);
    expect(p.stageIndex, 0);
    expect(p.note, contains('Consent not on record: Verbal consent'));
    expect(p.note, contains('Pre-op radiograph not taken'));
    expect(find.text('Next stage'), findsOneWidget);

    await tapKey(tester, 'proc-done-${rct.id}', frames: 15);
    expect(find.byKey(const ValueKey('consent-reason')), findsNothing);
    expect(find.byKey(const ValueKey('preop-reason')), findsNothing);
    p = (await env.repos.chart.getProcedure(rct.id))!;
    expect(p.status, ProcedureStatus.inProgress);
    expect(p.stageIndex, 1);
    expect(
      odontogram(tester).teeth[ToothId.parse('16')]!.overlays.single.kind,
      OverlayKind.rootCanal,
    );

    await tapKey(tester, 'proc-done-${rct.id}', frames: 15);
    p = (await env.repos.chart.getProcedure(rct.id))!;
    expect(p.status, ProcedureStatus.completed);
    expect(p.stageIndex, 2);
    final recalls = await env.repos.recalls.forPatient(testPatientId);
    expect(recalls.single.type, RecallType.review);
  });

  testWidgets('completing a scaling creates a hygiene recall and offers '
      'billing', (tester) async {
    final scaling = await plan('SCALING-ADULT');
    await env.pumpAt(tester, chartPath);

    await tapKey(tester, 'proc-done-${scaling.id}', frames: 15);
    expect(find.byKey(const ValueKey('preop-reason')), findsNothing);
    final p = (await env.repos.chart.getProcedure(scaling.id))!;
    expect(p.status, ProcedureStatus.completed);

    final recalls = await env.repos.recalls.forPatient(testPatientId);
    expect(recalls.length, 1);
    final recall = recalls.single;
    expect(recall.type, RecallType.hygiene);
    expect(recall.triggeredByProcedureId, scaling.id);
    expect(recall.status, RecallStatus.due);
    expect(
      recall.dueAt.difference(p.completedAt!).inDays,
      inInclusiveRange(179, 181),
    );
    expect(find.textContaining('Recall due'), findsOneWidget);

    await tapKey(tester, 'proc-bill-${scaling.id}', frames: 10);
    expect(env.location, '/patients/$testPatientId/billing/invoice/new');
    // The stub billing page echoes the query it received.
    expect(find.textContaining('procedureIds=${scaling.id}'), findsOneWidget);
  });

  testWidgets('a plan line cannot start treatment before an estimate is '
      'issued', (tester) async {
    final scaling = await plan('SCALING-ADULT');
    final service = env.container.read(planServiceProvider);
    final created = await service.createPlan(patientId: testPatientId);
    final editor = await service.save(
      PlanEditor(
        plan: created,
        lines: const [],
      ).addLine(lineFromProcedure(scaling, plan: created)),
      providerId: testDentistId,
    );
    expect(
      (await env.repos.chart.getProcedure(scaling.id))!.planId,
      created.id,
    );
    await env.pumpAt(tester, chartPath);

    await tapKey(tester, 'proc-done-${scaling.id}', frames: 15);
    expect(find.text(PlanStrings.estimateRequired), findsOneWidget);
    expect(
      (await env.repos.chart.getProcedure(scaling.id))!.status,
      ProcedureStatus.planned,
    );
    expect(await env.repos.recalls.forPatient(testPatientId), isEmpty);

    await service.issueEstimate(editor.plan.id);
    await tapKey(tester, 'proc-done-${scaling.id}', frames: 15);
    expect(
      (await env.repos.chart.getProcedure(scaling.id))!.status,
      ProcedureStatus.completed,
    );
  });

  testWidgets('a double tap on Mark done records one completion and one '
      'recall', (tester) async {
    final scaling = await plan('SCALING-ADULT');
    await env.pumpAt(tester, chartPath);
    await dismissSnackBars(tester);
    final button = find.byKey(ValueKey('proc-done-${scaling.id}'));
    await tester.ensureVisible(button);
    await tester.pump();
    // Two taps in the same frame: the second must hit the busy guard.
    await tester.tap(button);
    await tester.tap(button, warnIfMissed: false);
    await settle(tester, frames: 15);

    final p = (await env.repos.chart.getProcedure(scaling.id))!;
    expect(p.status, ProcedureStatus.completed);
    final events = await env.repos.audit.forEntity(
      testClinicId,
      'ProcedureRecord',
      scaling.id,
    );
    expect(events.where((e) => e.action == AuditAction.statusChange).length, 1);
    expect(await env.repos.recalls.forPatient(testPatientId), hasLength(1));
  });

  testWidgets('a double tap on Next stage advances a single stage', (
    tester,
  ) async {
    final inlay = await plan('INLAY-CER', tooth: ToothId.parse('16'));
    expect(inlay.totalStages, 2);
    // Consent signed on the inlay's template: no guard dialog in the way.
    await env.signConsent('FILLING');
    await env.pumpAt(tester, chartPath);
    await dismissSnackBars(tester);
    final button = find.byKey(ValueKey('proc-done-${inlay.id}'));
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await tester.tap(button, warnIfMissed: false);
    await settle(tester, frames: 15);

    final p = (await env.repos.chart.getProcedure(inlay.id))!;
    expect(p.status, ProcedureStatus.inProgress);
    expect(p.stageIndex, 0);
    // While the first transition runs the button is disabled.
    expect(find.text('Next stage'), findsOneWidget);
  });

  testWidgets('a double tap on Save adds the procedure once', (tester) async {
    await env.pumpAt(tester, '$chartPath?tooth=36');
    await tapKey(tester, 'chart-action-procedure');
    await tester.enterText(
      find.byKey(const ValueKey('procedure-search')),
      'SCALING-ADULT',
    );
    await settle(tester);
    await tapKey(tester, 'procedure-item-SCALING-ADULT');
    await tapKey(tester, 'procedure-status-done');
    final save = find.byKey(const ValueKey('procedure-save'));
    await tester.ensureVisible(save);
    await tester.pump();
    await tester.tap(save);
    await tester.tap(save, warnIfMissed: false);
    await settle(tester, frames: 15);

    final procedures = await env.repos.chart.proceduresForPatient(
      testPatientId,
    );
    expect(procedures, hasLength(1));
    expect(procedures.single.status, ProcedureStatus.completed);
    expect(await env.repos.recalls.forPatient(testPatientId), hasLength(1));
  });

  testWidgets('the odontogram fits a 360 px phone without horizontal '
      'scrolling', (tester) async {
    await env.pumpAt(tester, chartPath);
    final paint = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is OdontogramPainter,
    );
    expect(paint, findsOneWidget);
    final painter =
        tester.widget<CustomPaint>(paint).painter! as OdontogramPainter;
    expect(painter.layout.spec.compact, isTrue);
    expect(painter.layout.spec.availableWidth, 360);
    expect(painter.layout.overflowsWidth, isFalse);
    expect(tester.getSize(paint).width, 360);
    expect(tester.getTopLeft(paint).dx, 0);
    // Every tooth keeps the 44 px touch target.
    for (final cell in painter.layout.cells.values) {
      expect(cell.width, greaterThanOrEqualTo(44));
    }
    expect(
      find.ancestor(
        of: paint,
        matching: find.byWidgetPredicate(
          (w) =>
              w is SingleChildScrollView &&
              w.scrollDirection == Axis.horizontal,
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('a signed consent covering the procedure skips the consent '
      'guard, and Get consent routes to the form', (tester) async {
    final crown = await plan('CRN-ZIR', tooth: ToothId.parse('16'));
    final other = await plan('EXT-SIMPLE', tooth: ToothId.parse('26'));
    await env.signConsent('CROWN', procedureIds: [crown.id]);
    await env.addRadiograph(
      id: 'iopa-16',
      teeth: ['16', '26'],
      capturedAt: DateTime.now().toUtc().subtract(const Duration(days: 3)),
    );
    await env.pumpAt(tester, chartPath);

    await tapKey(tester, 'proc-done-${crown.id}', frames: 15);
    expect(find.byKey(const ValueKey('consent-reason')), findsNothing);
    expect(find.byKey(const ValueKey('preop-reason')), findsNothing);
    final p = (await env.repos.chart.getProcedure(crown.id))!;
    expect(p.status, isNot(ProcedureStatus.planned));
    expect(p.preOpImageIds, ['iopa-16']);

    // The extraction has no consent: one tap leads to the consent form with
    // the procedure preselected, and nothing is written.
    await tapKey(tester, 'proc-done-${other.id}');
    expect(find.byKey(const ValueKey('consent-reason')), findsOneWidget);
    await tapKey(tester, 'consent-get', frames: 15);
    expect(env.location, '/patients/$testPatientId/consent/new');
    expect(find.textContaining('procedureIds=${other.id}'), findsOneWidget);
    expect(
      (await env.repos.chart.getProcedure(other.id))!.status,
      ProcedureStatus.planned,
    );
  });

  testWidgets('a fee outside the catalogue range needs a confirm tap', (
    tester,
  ) async {
    await env.pumpAt(tester, '$chartPath?tooth=36');
    await tapKey(tester, 'chart-action-procedure');
    await tester.enterText(
      find.byKey(const ValueKey('procedure-search')),
      'COMP-POST-2',
    );
    await settle(tester);
    await tapKey(tester, 'procedure-item-COMP-POST-2');
    final item = (await env.repos.catalog.byCode(testClinicId, 'COMP-POST-2'))!;
    final tooHigh = item.feeMax + Money.rupees(1000);
    await tester.enterText(
      find.byKey(const ValueKey('procedure-fee')),
      tooHigh.wholeRupees.toString(),
    );
    await tapKey(tester, 'chart-surface-O');
    await tapKey(tester, 'procedure-save');
    expect(find.byKey(const ValueKey('fee-confirm')), findsOneWidget);
    expect(find.textContaining('outside'), findsWidgets);
    await tapKey(tester, 'fee-cancel');
    expect(await env.repos.chart.proceduresForPatient(testPatientId), isEmpty);

    await tapKey(tester, 'procedure-save');
    await tapKey(tester, 'fee-confirm', frames: 15);
    final saved = await env.repos.chart.proceduresForPatient(testPatientId);
    expect(saved.single.fee, tooHigh);
  });

  testWidgets('adding a procedure from the sheet prefills the fee and plans '
      'it on the selected tooth and surfaces', (tester) async {
    await env.pumpAt(tester, '$chartPath?tooth=36');
    await tapKey(tester, 'chart-action-procedure');
    await tester.enterText(
      find.byKey(const ValueKey('procedure-search')),
      'COMP-POST-2',
    );
    await settle(tester);
    await tapKey(tester, 'procedure-item-COMP-POST-2');
    final fee = tester.widget<TextField>(
      find.byKey(const ValueKey('procedure-fee')),
    );
    final item = (await env.repos.catalog.byCode(testClinicId, 'COMP-POST-2'))!;
    expect(fee.controller!.text, item.defaultFee.wholeRupees.toString());
    await tapKey(tester, 'chart-surface-O');
    await tapKey(tester, 'chart-surface-D');
    await tapKey(tester, 'procedure-save', frames: 15);

    final procedures = await env.repos.chart.proceduresForPatient(
      testPatientId,
    );
    final p = procedures.single;
    expect(p.code, 'COMP-POST-2');
    expect(p.tooth, ToothId.parse('36'));
    expect(p.surfaces.code, 'OD');
    expect(p.status, ProcedureStatus.planned);
    expect(p.fee, item.defaultFee);
    expect(
      odontogram(tester).teeth[ToothId.parse('36')]!.overlays.single.kind,
      OverlayKind.plannedRestoration,
    );
  });
}
