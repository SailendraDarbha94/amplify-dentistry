import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/features/chart/perio_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chart_test_support.dart';

void main() {
  final states = defaultToothStates(ageYears: 30);
  final site = (ToothId.parse('18'), PerioSite.distoBuccal);

  test('gingival margin digits default to recession so CAL is not '
      'understated: PD 5 with 2 mm recession is CAL 7', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(perioControllerProvider('p').notifier);
    expect(const PerioDraft().recession, isTrue);
    controller.toggleChartAll();
    expect(controller.currentCell(states), site);

    controller.enterDigit(5, states);
    controller.setMeasure(PerioMeasurementType.gingivalMargin);
    controller.previous();
    controller.enterDigit(2, states);
    var reading = controller.readingAt(site);
    expect(reading.probingDepth, 5);
    expect(reading.gingivalMargin, -2);
    expect(reading.recession, 2);
    expect(reading.clinicalAttachmentLoss, 7);

    // Explicit toggle for a margin coronal to the CEJ.
    controller.toggleRecession();
    controller.previous();
    controller.enterDigit(2, states);
    reading = controller.readingAt(site);
    expect(reading.gingivalMargin, 2);
    expect(reading.clinicalAttachmentLoss, 3);
  });

  test('the furcation * flag sits beside the code, unlocks the sextant and '
      'is saved on the exam', () async {
    final env = await ChartTestEnv.open();
    addTearDown(env.close);
    final controller = env.container.read(
      perioControllerProvider(testPatientId).notifier,
    );
    const sextant = Sextant.upperRightPosterior;
    expect(controller.state.sextantUnlocked(sextant), isFalse);
    controller.setBpe(sextant, BpeCode.code2);
    controller.toggleBpeFurcation(sextant);
    expect(controller.state.bpe[sextant], BpeCode.code2);
    expect(controller.state.bpeFurcation, {sextant});
    expect(controller.state.sextantUnlocked(sextant), isTrue);
    expect(controller.state.sextantUnlocked(Sextant.upperAnterior), isFalse);
    expect(controller.state.hasContent, isTrue);
    final exam = await controller.save(
      ctx: testCtx,
      repo: env.repos.perio,
      now: DateTime.utc(2026, 10, 25, 9),
      states: states,
    );
    final stored = (await env.repos.perio.getExam(exam.id))!;
    expect(stored.bpe, {sextant: BpeCode.code2});
    expect(stored.bpeFurcation, {sextant});
    // Toggling again clears the flag.
    controller.toggleBpeFurcation(sextant);
    controller.toggleBpeFurcation(sextant);
    expect(controller.state.bpeFurcation, isEmpty);
  });

  test('the recession toggle persists across a saved exam', () async {
    final env = await ChartTestEnv.open();
    addTearDown(env.close);
    final controller = env.container.read(
      perioControllerProvider(testPatientId).notifier,
    );
    controller.toggleChartAll();
    controller.toggleRecession();
    controller.enterDigit(3, states);
    await controller.save(
      ctx: testCtx,
      repo: env.repos.perio,
      now: DateTime.utc(2026, 10, 25, 9),
      states: states,
    );
    final draft = env.container.read(perioControllerProvider(testPatientId));
    expect(draft.sites, isEmpty);
    expect(draft.recession, isFalse);
  });
}
