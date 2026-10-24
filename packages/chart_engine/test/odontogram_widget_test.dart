import 'package:ampdent_chart_engine/ampdent_chart_engine.dart';
import 'package:ampdent_core/ampdent_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _chartPaint() => find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter is OdontogramPainter,
);

OdontogramPainter _painter(WidgetTester tester) =>
    (tester.widget<CustomPaint>(_chartPaint()).painter as OdontogramPainter);

void main() {
  testWidgets(
    'tap on tooth 16 selects it, second tap on occlusal reports the surface',
    (tester) async {
      final toothTaps = <ToothId>[];
      final surfaceTaps = <(ToothId, ToothSurface)>[];
      ToothId? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SizedBox(
                width: 800,
                height: 400,
                child: Odontogram(
                  teeth: DemoCharts.adult(),
                  notation: ToothNotation.fdi,
                  selectedTooth: selected,
                  onToothTap: (t) => setState(() {
                    toothTaps.add(t);
                    selected = t;
                  }),
                  onSurfaceTap: (t, s) => surfaceTaps.add((t, s)),
                ),
              ),
            ),
          ),
        ),
      );

      final layout = _painter(tester).layout;
      final origin = tester.getTopLeft(_chartPaint());
      final tooth16 = ToothId.parse('16');

      await tester.tapAt(origin + layout.cells[tooth16]!.center);
      await tester.pump();
      expect(toothTaps, [tooth16]);
      expect(surfaceTaps, isEmpty);
      expect(_painter(tester).selectedTooth, tooth16);

      await tester.tapAt(origin + layout.shapes[tooth16]!.occlusalCentre);
      await tester.pump();
      expect(surfaceTaps, [(tooth16, ToothSurface.occlusal)]);
      expect(toothTaps, [tooth16]);

      // Tapping another tooth while 16 is selected is a tooth tap, not a surface.
      final tooth26 = ToothId.parse('26');
      await tester.tapAt(origin + layout.shapes[tooth26]!.occlusalCentre);
      await tester.pump();
      expect(toothTaps, [tooth16, tooth26]);
      expect(surfaceTaps.length, 1);
    },
  );

  testWidgets('long press reports the tooth', (tester) async {
    ToothId? pressed;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 800,
          height: 400,
          child: Odontogram(
            teeth: DemoCharts.adult(),
            notation: ToothNotation.fdi,
            onToothLongPress: (t) => pressed = t,
          ),
        ),
      ),
    );
    final layout = _painter(tester).layout;
    final origin = tester.getTopLeft(_chartPaint());
    await tester.longPressAt(
      origin + layout.cells[ToothId.parse('31')]!.center,
    );
    await tester.pump();
    expect(pressed, ToothId.parse('31'));
  });

  testWidgets('narrow widths scroll horizontally instead of shrinking teeth', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 360,
            height: 300,
            child: Odontogram(
              teeth: DemoCharts.adult(),
              notation: ToothNotation.fdi,
            ),
          ),
        ),
      ),
    );
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(_painter(tester).layout.rows.first.cellWidth, 44);
  });

  testWidgets('notation toggle changes the labels the painter draws', (
    tester,
  ) async {
    var notation = ToothNotation.fdi;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                OdontogramNotationToggle(
                  value: notation,
                  onChanged: (n) => setState(() => notation = n),
                ),
                SizedBox(
                  width: 800,
                  height: 400,
                  child: Odontogram(
                    teeth: DemoCharts.adult(),
                    notation: notation,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(_painter(tester).notation, ToothNotation.fdi);
    await tester.tap(find.text('Universal'));
    await tester.pumpAndSettle();
    expect(_painter(tester).notation, ToothNotation.universal);
    expect(_painter(tester).notation.formatPlain(ToothId.parse('16')), '3');
    await tester.tap(find.text('Palmer'));
    await tester.pumpAndSettle();
    expect(_painter(tester).notation.formatPlain(ToothId.parse('16')), 'UR6');
  });

  testWidgets('legend renders a swatch and label per kind', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ToothLegend())),
    );
    for (final kind in ToothLegend.defaultKinds) {
      expect(find.text(kind.label), findsOneWidget);
    }
  });
}
