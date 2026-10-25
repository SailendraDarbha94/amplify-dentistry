import 'package:ampdent_chart_engine/ampdent_chart_engine.dart';
import 'package:ampdent_core/ampdent_core.dart';
import 'package:flutter_test/flutter_test.dart';

ToothId _t(String fdi) => ToothId.parse(fdi);

void main() {
  final adultVisible = visibleTeeth(defaultToothStates(ageYears: 30));

  group('OdontogramLayout standard mode', () {
    final layout = OdontogramLayout.compute(
      OdontogramLayoutSpec(
        availableWidth: 800,
        availableHeight: 400,
        visibleTeeth: adultVisible,
      ),
    );

    test('positions all 32 permanent teeth in two rows', () {
      expect(layout.shapes.length, 32);
      expect(layout.cells.length, 32);
      expect(layout.rows.length, 2);
      expect(layout.rows.first.arch, Arch.upper);
      expect(layout.rows.last.arch, Arch.lower);
      expect(layout.size.width, lessThanOrEqualTo(800));
      expect(layout.size.height, lessThanOrEqualTo(400));
      expect(layout.overflowsWidth, isFalse);
    });

    test('patient right is on the viewer left: 18 < 11 < 21 < 28', () {
      final x18 = layout.cells[_t('18')]!.left;
      final x11 = layout.cells[_t('11')]!.left;
      final x21 = layout.cells[_t('21')]!.left;
      final x28 = layout.cells[_t('28')]!.left;
      expect(x18, lessThan(x11));
      expect(x11, lessThan(x21));
      expect(x21, lessThan(x28));
      expect(layout.cells[_t('48')]!.left, layout.cells[_t('18')]!.left);
      expect(layout.cells[_t('31')]!.left, layout.cells[_t('21')]!.left);
    });

    test('upper row above lower row, midline between 11 and 21', () {
      expect(
        layout.cells[_t('11')]!.bottom,
        lessThan(layout.cells[_t('41')]!.top),
      );
      final mid = layout.midlineX!;
      expect(mid, greaterThan(layout.cells[_t('11')]!.right));
      expect(mid, lessThan(layout.cells[_t('21')]!.left));
      expect(
        layout.cells[_t('21')]!.left - layout.cells[_t('11')]!.right,
        closeTo(12, 0.01),
      );
    });

    test('hit-testing returns the tooth and surface under a point', () {
      final hit = layout.hitTest(layout.cells[_t('16')]!.center);
      expect(hit?.tooth, _t('16'));
      expect(layout.toothAt(const Offset(-10, -10)), isNull);
      final shape = layout.shapes[_t('16')]!;
      expect(
        layout.hitTest(shape.occlusalCentre)?.surface,
        ToothSurface.occlusal,
      );
    });
  });

  group('OdontogramLayout narrow and compact', () {
    test('keeps 44 px per tooth and overflows when the width is too small', () {
      final layout = OdontogramLayout.compute(
        OdontogramLayoutSpec(availableWidth: 390, visibleTeeth: adultVisible),
      );
      expect(layout.rows.first.cellWidth, 44);
      expect(layout.overflowsWidth, isTrue);
      expect(layout.size.width, closeTo(16 * 44 + 12 + 8, 0.01));
      for (final cell in layout.cells.values) {
        expect(cell.width, greaterThanOrEqualTo(44));
      }
    });

    test('compact mode stacks the four quadrant rows', () {
      final layout = OdontogramLayout.compute(
        OdontogramLayoutSpec(
          availableWidth: 360,
          visibleTeeth: adultVisible,
          compact: true,
        ),
      );
      expect(layout.rows.length, 4);
      expect(layout.rows.map((r) => r.quadrant), [
        Quadrant.upperRight,
        Quadrant.upperLeft,
        Quadrant.lowerRight,
        Quadrant.lowerLeft,
      ]);
      expect(layout.midlineX, isNull);
      expect(layout.overflowsWidth, isFalse);
      expect(layout.size.width, 360);
      expect(layout.shapes.length, 32);
      // 11 sits at the right end of its row, 21 at the left end of the next.
      expect(
        layout.cells[_t('11')]!.right,
        closeTo(layout.size.width - 4, 0.01),
      );
      expect(layout.cells[_t('21')]!.left, closeTo(4, 0.01));
      expect(
        layout.cells[_t('21')]!.top,
        greaterThan(layout.cells[_t('11')]!.bottom),
      );
    });

    test('compact rows keep the patient right first in both arches', () {
      final layout = OdontogramLayout.compute(
        OdontogramLayoutSpec(
          availableWidth: 360,
          visibleTeeth: adultVisible,
          compact: true,
        ),
      );
      double top(String fdi) => layout.cells[_t(fdi)]!.top;
      // UR above UL above LR above LL.
      expect(top('18'), lessThan(top('28')));
      expect(top('28'), lessThan(top('48')));
      expect(top('48'), lessThan(top('38')));
      // Within each row the molar sits on the outside, as in the mouth.
      expect(
        layout.cells[_t('48')]!.left,
        lessThan(layout.cells[_t('41')]!.left),
      );
      expect(
        layout.cells[_t('31')]!.left,
        lessThan(layout.cells[_t('38')]!.left),
      );
    });

    test('compact mixed rows put primary rows towards the midline', () {
      final layout = OdontogramLayout.compute(
        OdontogramLayoutSpec(
          availableWidth: 360,
          visibleTeeth: visibleTeeth(defaultToothStates(ageYears: 8)),
          compact: true,
          mixedDentition: true,
        ),
      );
      expect(layout.rows.map((r) => (r.quadrant, r.dentition)), [
        (Quadrant.upperRight, Dentition.permanent),
        (Quadrant.upperRight, Dentition.primary),
        (Quadrant.upperLeft, Dentition.permanent),
        (Quadrant.upperLeft, Dentition.primary),
        (Quadrant.lowerRight, Dentition.primary),
        (Quadrant.lowerRight, Dentition.permanent),
        (Quadrant.lowerLeft, Dentition.primary),
        (Quadrant.lowerLeft, Dentition.permanent),
      ]);
    });
  });

  group('OdontogramLayout mixed dentition', () {
    final states = defaultToothStates(ageYears: 8);
    final visible = visibleTeeth(states);
    final layout = OdontogramLayout.compute(
      OdontogramLayoutSpec(
        availableWidth: 800,
        visibleTeeth: visible,
        mixedDentition: true,
      ),
    );

    test('draws a primary row between the permanent rows', () {
      expect(layout.rows.length, 4);
      expect(layout.rows.map((r) => r.dentition), [
        Dentition.permanent,
        Dentition.primary,
        Dentition.primary,
        Dentition.permanent,
      ]);
      final c15 = layout.cells[_t('15')];
      final c55 = layout.cells[_t('55')]!;
      final c85 = layout.cells[_t('85')]!;
      final c45 = layout.cells[_t('45')];
      // At age 8 the premolars are unerupted and hidden; the primary molars
      // are present and sit between the permanent rows.
      expect(c15, isNull);
      expect(c45, isNull);
      expect(c55.top, greaterThan(layout.cells[_t('16')]!.bottom));
      expect(c85.top, greaterThan(c55.bottom));
      expect(layout.cells[_t('46')]!.top, greaterThan(c85.bottom));
      // Primary teeth sit in the column of their permanent successor.
      expect(
        c55.center.dx,
        closeTo(
          layout.rows.first.cellBounds.left + 3.5 * layout.rows.first.cellWidth,
          0.01,
        ),
      );
      // Exfoliated primary incisors are not drawn.
      expect(layout.cells.containsKey(_t('51')), isFalse);
      expect(layout.cells.containsKey(_t('11')), isTrue);
    });

    test('primary shapes are smaller than permanent shapes', () {
      final primary = layout.shapes[_t('55')]!.bounds;
      final permanent = layout.shapes[_t('16')]!.bounds;
      expect(primary.width, lessThan(permanent.width));
      expect(primary.height, lessThan(permanent.height));
    });
  });

  group('ToothLayoutCache', () {
    test('returns the same layout for an equal spec and evicts oldest', () {
      final cache = ToothLayoutCache(capacity: 2);
      final a = OdontogramLayoutSpec(
        availableWidth: 800,
        visibleTeeth: adultVisible,
      );
      final b = OdontogramLayoutSpec(
        availableWidth: 700,
        visibleTeeth: adultVisible,
      );
      final c = OdontogramLayoutSpec(
        availableWidth: 600,
        visibleTeeth: adultVisible,
      );
      final first = cache.layoutFor(a);
      expect(identical(cache.layoutFor(a), first), isTrue);
      cache.layoutFor(b);
      cache.layoutFor(c);
      expect(cache.length, 2);
      expect(identical(cache.layoutFor(a), first), isFalse);
    });
  });
}
