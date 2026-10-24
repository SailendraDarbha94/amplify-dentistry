import 'package:ampdent_chart_engine/ampdent_chart_engine.dart';
import 'package:ampdent_core/ampdent_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ToothId _t(String fdi) => ToothId.parse(fdi);

void main() {
  group('perioEntrySequence', () {
    final all = ToothId.permanentTeeth();

    test(
      'upper facial walks 18..28 left to right, distal first on the right side',
      () {
        final seq = perioEntrySequence(Arch.upper, PerioAspect.facial, all);
        expect(seq.length, 48);
        expect(seq[0], (_t('18'), PerioSite.distoBuccal));
        expect(seq[1], (_t('18'), PerioSite.buccal));
        expect(seq[2], (_t('18'), PerioSite.mesioBuccal));
        expect(seq[21], (_t('11'), PerioSite.distoBuccal));
        expect(seq[23], (_t('11'), PerioSite.mesioBuccal));
        expect(seq[24], (_t('21'), PerioSite.mesioBuccal));
        expect(seq[26], (_t('21'), PerioSite.distoBuccal));
        expect(seq.last, (_t('28'), PerioSite.distoBuccal));
      },
    );

    test('lower lingual uses lingual sites and only lower teeth', () {
      final seq = perioEntrySequence(Arch.lower, PerioAspect.lingual, all);
      expect(seq.length, 48);
      expect(seq.first, (_t('48'), PerioSite.distoLingual));
      expect(seq.last, (_t('38'), PerioSite.distoLingual));
      expect(seq.every((e) => e.$1.arch == Arch.lower && !e.$2.facial), isTrue);
    });

    test('skips teeth that are not present', () {
      final present = all
          .where((t) => t.arch == Arch.upper && t.position <= 2)
          .toList();
      final seq = perioEntrySequence(Arch.upper, PerioAspect.facial, present);
      expect(seq.length, 12);
      expect(seq.first.$1, _t('12'));
    });

    test('cursor advances and clamps', () {
      final seq = perioEntrySequence(Arch.upper, PerioAspect.facial, [
        _t('11'),
      ]);
      var cursor = PerioEntryCursor(seq);
      expect(cursor.current, (_t('11'), PerioSite.distoBuccal));
      cursor = cursor.next().next();
      expect(cursor.current, (_t('11'), PerioSite.mesioBuccal));
      cursor = cursor.next();
      expect(cursor.isAtEnd, isTrue);
      expect(cursor.current, isNull);
      expect(cursor.next().index, 3);
      expect(cursor.previous().previous().previous().previous().index, 0);
      expect(cursor.jumpTo((_t('11'), PerioSite.buccal)).index, 1);
    });
  });

  group('PerioStyle thresholds', () {
    test('PD >= 4 amber, >= 6 red', () {
      const s = PerioStyle.light;
      expect(s.depthColor(null), s.mutedText);
      expect(s.depthColor(3), s.depthNormal);
      expect(s.depthColor(4), s.depthWarning);
      expect(s.depthColor(5), s.depthWarning);
      expect(s.depthColor(6), s.depthSevere);
      expect(s.depthColor(9), s.depthSevere);
      expect(PerioStyle.dark.depthColor(6), PerioStyle.dark.depthSevere);
    });
  });

  group('PerioGridLayout', () {
    final teeth = ToothId.archRow(Arch.upper, Dentition.permanent);
    final layout = PerioGridLayout.compute(
      PerioGridSpec(
        arch: Arch.upper,
        aspect: PerioAspect.facial,
        teeth: teeth,
        availableWidth: 1500,
      ),
    );

    test('hit-tests sites in viewer order and per-tooth rows', () {
      final pd = layout.cellRect(
        0,
        PerioRowKind.probingDepth,
        site: PerioSite.distoBuccal,
      );
      final hit = layout.hitTest(pd.center);
      expect(
        hit,
        PerioCell(
          tooth: _t('18'),
          site: PerioSite.distoBuccal,
          type: PerioMeasurementType.probingDepth,
        ),
      );
      final right = layout.cellRect(
        0,
        PerioRowKind.probingDepth,
        site: PerioSite.mesioBuccal,
      );
      expect(right.left, greaterThan(pd.left));
      final mob = layout.hitTest(
        layout.cellRect(15, PerioRowKind.mobility).center,
      );
      expect(
        mob,
        PerioCell(
          tooth: _t('28'),
          site: null,
          type: PerioMeasurementType.mobility,
        ),
      );
      expect(layout.hitTest(const Offset(5, 5)), isNull);
      expect(layout.hitTest(Offset(layout.size.width + 5, 50)), isNull);
    });

    test('narrow widths keep the minimum column width', () {
      final narrow = PerioGridLayout.compute(
        PerioGridSpec(
          arch: Arch.upper,
          aspect: PerioAspect.facial,
          teeth: teeth,
          availableWidth: 390,
        ),
      );
      expect(narrow.columnWidth, 72);
      expect(narrow.overflowsWidth, isTrue);
    });
  });

  testWidgets('PerioChart paints readings and reports cell taps', (
    tester,
  ) async {
    final states = defaultToothStates(ageYears: 30);
    final readings = [
      PerioSiteReading(
        tooth: _t('16'),
        site: PerioSite.mesioBuccal,
        probingDepth: 6,
        bleeding: true,
        gingivalMargin: -2,
      ),
      PerioSiteReading(
        tooth: _t('16'),
        site: PerioSite.buccal,
        probingDepth: 4,
        plaque: true,
      ),
      PerioSiteReading(
        tooth: _t('11'),
        site: PerioSite.distoBuccal,
        probingDepth: 2,
        suppuration: true,
      ),
    ];
    final taps = <(ToothId, PerioSite?, PerioMeasurementType)>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 400,
            child: PerioChart(
              arch: Arch.upper,
              aspect: PerioAspect.facial,
              states: states,
              readings: readings,
              toothReadings: [
                PerioToothReading(
                  tooth: _t('16'),
                  mobility: MobilityGrade.grade2,
                  furcation: FurcationGrade.grade1,
                ),
              ],
              focusedCell: (_t('16'), PerioSite.buccal),
              onCellTap: (t, s, type) => taps.add((t, s, type)),
            ),
          ),
        ),
      ),
    );
    final paintFinder = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is PerioGridPainter,
    );
    final painter =
        tester.widget<CustomPaint>(paintFinder).painter! as PerioGridPainter;
    final origin = tester.getTopLeft(paintFinder);
    final layout = painter.layout;
    final column = layout.spec.teeth.indexOf(_t('16'));
    await tester.tapAt(
      origin +
          layout
              .cellRect(
                column,
                PerioRowKind.probingDepth,
                site: PerioSite.mesioBuccal,
              )
              .center,
    );
    await tester.tapAt(
      origin + layout.cellRect(column, PerioRowKind.furcation).center,
    );
    await tester.pump();
    expect(taps, [
      (_t('16'), PerioSite.mesioBuccal, PerioMeasurementType.probingDepth),
      (_t('16'), null, PerioMeasurementType.furcation),
    ]);
  });

  test('PerioChart.enterValue routes to onValueEntered', () {
    final entered = <(ToothId, PerioSite?, PerioMeasurementType, int?)>[];
    final chart = PerioChart(
      arch: Arch.upper,
      aspect: PerioAspect.facial,
      states: defaultToothStates(ageYears: 30),
      readings: const [],
      onValueEntered: (t, s, type, v) => entered.add((t, s, type, v)),
    );
    expect(
      chart.enterValue(
        _t('16'),
        PerioSite.buccal,
        PerioMeasurementType.probingDepth,
        5,
      ),
      isTrue,
    );
    expect(
      chart.enterValue(_t('16'), null, PerioMeasurementType.mobility, null),
      isTrue,
    );
    expect(entered, [
      (_t('16'), PerioSite.buccal, PerioMeasurementType.probingDepth, 5),
      (_t('16'), null, PerioMeasurementType.mobility, null),
    ]);
    final unwired = PerioChart(
      arch: Arch.upper,
      aspect: PerioAspect.facial,
      states: const {},
      readings: const [],
    );
    expect(
      unwired.enterValue(
        _t('16'),
        PerioSite.buccal,
        PerioMeasurementType.probingDepth,
        5,
      ),
      isFalse,
    );
  });

  testWidgets('PerioNumberPad reports digits, toggles and next', (
    tester,
  ) async {
    final digits = <int>[];
    final toggles = <PerioMeasurementType>[];
    var next = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PerioNumberPad(
            onDigit: digits.add,
            onNext: () => next++,
            onToggle: toggles.add,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('perio-digit-5')));
    await tester.tap(find.byKey(const ValueKey('perio-digit-12')));
    await tester.tap(
      find.byKey(const ValueKey('perio-flag-bleedingOnProbing')),
    );
    await tester.tap(find.byKey(const ValueKey('perio-next')));
    await tester.pump();
    expect(digits, [5, 12]);
    expect(toggles, [PerioMeasurementType.bleedingOnProbing]);
    expect(next, 1);
  });
}
