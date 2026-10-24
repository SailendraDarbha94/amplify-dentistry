import 'package:ampdent_core/ampdent_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chart_test_support.dart';

const String perioPath = '/patients/$testPatientId/chart/perio';

void main() {
  late ChartTestEnv env;

  setUp(() async => env = await ChartTestEnv.open());
  tearDown(() => env.close());

  bool digitEnabled(WidgetTester tester, int v) =>
      tester
          .widget<FilledButton>(find.byKey(ValueKey('perio-digit-$v')))
          .onPressed !=
      null;

  testWidgets('BPE gates charting and a saved exam persists sites and '
      'recomputes the summary', (tester) async {
    await env.pumpAt(tester, perioPath);

    // Nothing unlocked yet: the pad is disabled and the hint shows.
    await tester.dragUntilVisible(
      find.textContaining('Enter BPE code 3 or 4'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    expect(find.textContaining('Enter BPE code 3 or 4'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pump();
    expect(digitEnabled(tester, 5), isFalse);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('perio-save')))
          .onPressed,
      isNull,
    );

    // Code 4 in the upper right posterior unlocks the full mouth.
    await tapKey(tester, 'bpe-1-code4');
    expect(digitEnabled(tester, 5), isTrue);
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('perio-chart')),
      find.byType(ListView),
      const Offset(0, -200),
    );
    expect(find.byKey(const ValueKey('perio-chart')), findsOneWidget);

    await tapKey(tester, 'perio-digit-5');
    await tapKey(tester, 'perio-digit-3');
    await tapKey(tester, 'perio-flag-bleedingOnProbing');

    await tapKey(tester, 'perio-save', frames: 15);
    final exam = await env.repos.perio.latestExam(testPatientId);
    expect(exam, isNotNull);
    expect(exam!.examinerId, testDentistId);
    expect(exam.bpe[Sextant.upperRightPosterior], BpeCode.code4);
    expect(exam.sites.length, 2);
    // Auto-advance went distal to mesial on the viewer's left tooth (18).
    expect(exam.sites[0].tooth, ToothId.parse('18'));
    expect(exam.sites[0].site, PerioSite.distoBuccal);
    expect(exam.sites[0].probingDepth, 5);
    expect(exam.sites[1].site, PerioSite.buccal);
    expect(exam.sites[1].probingDepth, 3);
    // BOP tapped right after the digit flags the site just probed.
    expect(exam.sites[1].bleeding, isTrue);
    expect(exam.sites[0].bleeding, isFalse);
    final summary = exam.summary;
    expect(summary.sitesRecorded, 2);
    expect(summary.bleedingPercent, 50);
    expect(summary.sitesPd4Plus, 1);
    expect(summary.sitesPd6Plus, 0);
    expect(summary.maxProbingDepth, 5);
    // Primary teeth of an adult are exfoliated, not skipped rows; absent
    // permanent teeth would be. All 32 are present at 36.
    expect(exam.teeth.where((t) => t.skipped), isEmpty);
    expect(find.textContaining('Perio exam saved'), findsOneWidget);
    await tester.dragUntilVisible(
      find.textContaining('Last exam'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    expect(find.textContaining('Last exam'), findsOneWidget);
  });

  testWidgets('code 3 unlocks only that sextant', (tester) async {
    await env.pumpAt(tester, perioPath);
    await tapKey(tester, 'bpe-2-code3');
    // Upper anterior unlocked: entering a digit lands on 13 (viewer order).
    await tapKey(tester, 'perio-digit-2');
    await tapKey(tester, 'perio-save', frames: 15);
    final exam = (await env.repos.perio.latestExam(testPatientId))!;
    expect(exam.sites.single.tooth, ToothId.parse('13'));
    expect(exam.sites.single.probingDepth, 2);
    expect(exam.bpe, {Sextant.upperAnterior: BpeCode.code3});
  });
}
