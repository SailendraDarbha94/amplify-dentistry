import 'package:ampdent_chart_engine/ampdent_chart_engine.dart';
import 'package:ampdent_core/ampdent_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _key = Key('golden-chart');

Future<void> _pumpChart(
  WidgetTester tester, {
  required Map<ToothId, ToothVisual> teeth,
  required double width,
  required double height,
  bool mixed = false,
  ToothId? selected,
  SurfaceSet selectedSurfaces = const SurfaceSet.empty(),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.light(),
      home: Center(
        child: RepaintBoundary(
          key: _key,
          child: Container(
            width: width,
            height: height,
            color: Colors.white,
            child: Odontogram(
              teeth: teeth,
              notation: ToothNotation.fdi,
              mixedDentition: mixed,
              selectedTooth: selected,
              selectedSurfaces: selectedSurfaces,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  const sizes = [(390.0, 300.0), (800.0, 400.0)];

  for (final (w, h) in sizes) {
    final tag = '${w.toInt()}x${h.toInt()}';

    testWidgets('adult chart $tag', (tester) async {
      await _pumpChart(tester, teeth: DemoCharts.adult(), width: w, height: h);
      await expectLater(
        find.byKey(_key),
        matchesGoldenFile('goldens/adult_$tag.png'),
      );
    });

    testWidgets('mixed dentition chart (age 8) $tag', (tester) async {
      await _pumpChart(
        tester,
        teeth: DemoCharts.mixedAge8(),
        width: w,
        height: h,
        mixed: true,
      );
      await expectLater(
        find.byKey(_key),
        matchesGoldenFile('goldens/mixed_age8_$tag.png'),
      );
    });

    testWidgets('chart with overlays $tag', (tester) async {
      await _pumpChart(
        tester,
        teeth: DemoCharts.adultWithOverlays(),
        width: w,
        height: h,
        selected: ToothId.parse('16'),
        selectedSurfaces: SurfaceSet.parse('MO'),
      );
      await expectLater(
        find.byKey(_key),
        matchesGoldenFile('goldens/overlays_$tag.png'),
      );
    });
  }
}
