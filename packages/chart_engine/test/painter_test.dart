import 'dart:ui';

import 'package:ampdent_chart_engine/ampdent_chart_engine.dart';
import 'package:ampdent_core/ampdent_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  OdontogramPainter painterFor(
    Map<ToothId, ToothVisual> teeth, {
    bool mixed = false,
    ToothId? selected,
  }) {
    final layout = OdontogramLayout.compute(
      OdontogramLayoutSpec(
        availableWidth: 800,
        availableHeight: 400,
        mixedDentition: mixed,
        visibleTeeth: visibleTeeth({
          for (final e in teeth.entries) e.key: e.value.state,
        }),
      ),
    );
    return OdontogramPainter(
      layout: layout,
      teeth: teeth,
      notation: ToothNotation.fdi,
      style: OdontogramStyle.light,
      textCache: ChartTextCache(),
      selectedTooth: selected,
      selectedSurfaces: SurfaceSet.parse('MO'),
    );
  }

  Duration paintFrames(OdontogramPainter painter, int frames) {
    final sw = Stopwatch()..start();
    for (var i = 0; i < frames; i++) {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, painter.layout.size);
      recorder.endRecording().dispose();
    }
    return sw.elapsed;
  }

  test('paints a default adult chart 20 times without throwing, fast', () {
    final painter = painterFor(
      DemoCharts.adult(),
      selected: ToothId.parse('16'),
    );
    paintFrames(painter, 1); // warm-up: text shaping, path bounds
    final elapsed = paintFrames(painter, 20);
    final perFrame = elapsed.inMicroseconds / 20 / 1000;
    expect(
      perFrame,
      lessThan(50),
      reason: 'avg ${perFrame.toStringAsFixed(1)} ms/frame',
    );
  });

  test('paints every overlay kind and a mixed dentition chart', () {
    expect(
      () => paintFrames(painterFor(DemoCharts.adultWithOverlays()), 2),
      returnsNormally,
    );
    expect(
      () => paintFrames(painterFor(DemoCharts.mixedAge8(), mixed: true), 2),
      returnsNormally,
    );
    for (final notation in ToothNotation.values) {
      final p = painterFor(DemoCharts.adult());
      final painter = OdontogramPainter(
        layout: p.layout,
        teeth: p.teeth,
        notation: notation,
        style: OdontogramStyle.dark,
        textCache: p.textCache,
      );
      expect(() => paintFrames(painter, 1), returnsNormally);
    }
  });

  test('shouldRepaint only when inputs change', () {
    final teeth = DemoCharts.adult();
    final a = painterFor(teeth);
    final same = OdontogramPainter(
      layout: a.layout,
      teeth: Map.of(teeth),
      notation: a.notation,
      style: a.style,
      textCache: a.textCache,
      selectedSurfaces: SurfaceSet.parse('OM'),
    );
    expect(same.shouldRepaint(a), isFalse);
    final changed = OdontogramPainter(
      layout: a.layout,
      teeth: teeth,
      notation: ToothNotation.palmer,
      style: a.style,
      textCache: a.textCache,
      selectedSurfaces: SurfaceSet.parse('MO'),
    );
    expect(changed.shouldRepaint(a), isTrue);
    final selected = OdontogramPainter(
      layout: a.layout,
      teeth: teeth,
      notation: a.notation,
      style: a.style,
      textCache: a.textCache,
      selectedTooth: ToothId.parse('11'),
      selectedSurfaces: SurfaceSet.parse('MO'),
    );
    expect(selected.shouldRepaint(a), isTrue);
  });

  test('ToothOverlay and ToothVisual round-trip through JSON', () {
    final visual = ToothVisual(
      tooth: ToothId.parse('16'),
      state: ToothState.present,
      badgeCount: 2,
      overlays: [
        ToothOverlay(
          kind: OverlayKind.caries,
          surfaces: SurfaceSet.parse('MO'),
        ),
        const ToothOverlay(
          kind: OverlayKind.crown,
          label: 'PFM',
          colorValue: 0xFF123456,
        ),
      ],
    );
    expect(ToothVisual.fromJson(visual.toJson()), visual);
    expect(OverlayKind.plannedCrown.isPlanned, isTrue);
    expect(OverlayKind.crown.isPlanned, isFalse);
  });
}
