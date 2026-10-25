import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/features/plan/plan_accept_sheet.dart';
import 'package:ampdent_mobile/features/plan/plan_model.dart';
import 'package:ampdent_mobile/features/plan/plan_phase_section.dart';
import 'package:ampdent_mobile/features/plan/plan_service.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../feature_test_env.dart';

void main() {
  late FeatureTestEnv env;

  setUp(() async {
    env = await FeatureTestEnv.open();
    await env.repos.chart.createProcedure(testCtx, plannedProcedure());
  });
  tearDown(() => env.close());

  Future<void> openMenu(WidgetTester tester, String item) async {
    await tester.tap(find.byKey(const ValueKey('plan-menu')));
    await settle(tester);
    await tester.tap(find.byKey(ValueKey(item)));
    await settle(tester, frames: 10);
  }

  /// Scrolls the accept sheet until [key] is built and visible.
  Future<Finder> inSheet(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.scrollUntilVisible(
      finder,
      80,
      scrollable: find
          .descendant(
            of: find.byType(PlanAcceptSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await settle(tester, frames: 2);
    return finder;
  }

  testWidgets(
    'builds a plan from a planned procedure, warns on fee, presents and '
    'accepts with a signature',
    (tester) async {
      await env.pumpApp(tester);
      await env.go(tester, '/patients/$testPatientId/plan');
      expect(find.byKey(const ValueKey('plan-new')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('plan-new')));
      await settle(tester, frames: 12);
      expect(env.location, startsWith('/patients/$testPatientId/plan/'));
      expect(find.byKey(const ValueKey('funnel-presented')), findsOneWidget);

      // Pull the planned RCT from the chart into phase 1.
      await tester.tap(find.byKey(const ValueKey('plan-add-line')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('plan-proc-proc-rct')));
      await settle(tester);
      expect(find.byType(PlanLineTile), findsOneWidget);

      // Fee below the catalogue minimum shows a warning but is allowed.
      await tester.tap(find.byType(PlanLineTile));
      await settle(tester);
      await tester.enterText(find.byKey(const ValueKey('line-fee')), '100');
      await settle(tester, frames: 2);
      expect(find.byKey(const ValueKey('line-fee-warning')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('line-fee')), '6000');
      await settle(tester, frames: 2);
      expect(find.byKey(const ValueKey('line-fee-warning')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('line-save')));
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('plan-save')));
      await settle(tester, frames: 12);
      final plan = (await env.repos.treatmentPlans.activePlan(testPatientId))!;
      final lines = await env.repos.treatmentPlans.linesForPlan(plan.id);
      expect(lines, hasLength(1));
      expect(lines.single.procedureId, 'proc-rct');
      expect(lines.single.unitFee, const Money.rupees(6000));
      final proc = await env.repos.chart.getProcedure('proc-rct');
      expect(proc!.planId, plan.id);
      expect(proc.fee, const Money.rupees(6000));

      await openMenu(tester, 'plan-menu-present');
      final presented = await env.repos.treatmentPlans.getPlan(plan.id);
      expect(presented!.presentedAt, isNotNull);
      expect(find.textContaining('Presented'), findsWidgets);

      await openMenu(tester, 'plan-menu-accept');
      // No estimate was issued: the sheet says so and the confirm button
      // stays disabled until the patient's refusal is recorded.
      expect(
        find.byKey(const ValueKey('accept-estimate-missing')),
        findsOneWidget,
      );
      await tester.drag(
        await inSheet(tester, 'accept-signature'),
        const Offset(80, 20),
      );
      await settle(tester, frames: 2);
      expect(
        tester
            .widget<BigActionButton>(await inSheet(tester, 'accept-confirm'))
            .onPressed,
        isNull,
      );
      await tester.tap(await inSheet(tester, 'accept-estimate-declined'));
      await settle(tester, frames: 2);
      await tester.enterText(
        await inSheet(tester, 'accept-estimate-declined-reason'),
        'Wants to start today, declined the paper estimate',
      );
      await settle(tester, frames: 2);
      await tester.tap(await inSheet(tester, 'accept-confirm'));
      await settle(tester, frames: 15);

      final accepted = await env.repos.treatmentPlans.getPlan(plan.id);
      expect(accepted!.isAccepted, isTrue);
      expect(accepted.acceptedSignatureHash, hasLength(64));
      final acceptedProc = await env.repos.chart.getProcedure('proc-rct');
      expect(acceptedProc!.status, ProcedureStatus.accepted);
      expect(find.byKey(const ValueKey('plan-frozen-banner')), findsOneWidget);
      expect(find.byKey(const ValueKey('plan-save')), findsNothing);
    },
  );

  testWidgets('estimate v2 asks for a justification and refuses a blank one', (
    tester,
  ) async {
    final service = PlanService(
      plans: env.repos.treatmentPlans,
      chart: env.repos.chart,
      catalog: env.repos.catalog,
      ctx: testCtx,
    );
    final plan = await service.createPlan(
      patientId: testPatientId,
      now: testNow,
    );
    final proc = (await env.repos.chart.getProcedure('proc-rct'))!;
    final editor = (await service.load(plan.id))!
        .addLine(lineFromProcedure(proc, plan: plan));
    await service.save(editor, providerId: testDentistId, now: testNow);
    await service.issueEstimate(plan.id, now: testNow);

    await env.pumpApp(tester);
    await env.go(tester, '/patients/$testPatientId/plan/${plan.id}');
    await settle(tester, frames: 10);
    await openMenu(tester, 'plan-menu-estimate');
    expect(
      find.byKey(const ValueKey('estimate-justification')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('estimate-issue')));
    await settle(tester, frames: 10);
    expect(
      find.text('A revised estimate needs a justification'),
      findsOneWidget,
    );
    expect(
      await env.repos.treatmentPlans.estimatesForPlan(plan.id),
      hasLength(1),
    );

    await openMenu(tester, 'plan-menu-estimate');
    await tester.enterText(
      find.byKey(const ValueKey('estimate-justification')),
      'Crown added after discussion',
    );
    await tester.tap(find.byKey(const ValueKey('estimate-issue')));
    await settle(tester, frames: 10);
    final estimates = await env.repos.treatmentPlans.estimatesForPlan(plan.id);
    expect(estimates, hasLength(2));
    expect(estimates.last.version, 2);
    expect(estimates.last.justification, 'Crown added after discussion');
  });
}
