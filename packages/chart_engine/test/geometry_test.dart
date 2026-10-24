import 'dart:ui';

import 'package:ampdent_chart_engine/ampdent_chart_engine.dart';
import 'package:ampdent_core/ampdent_core.dart';
import 'package:flutter_test/flutter_test.dart';

const _cell = Rect.fromLTWH(0, 0, 100, 200);
const _faces = [
  ToothSurface.mesial,
  ToothSurface.occlusal,
  ToothSurface.distal,
  ToothSurface.facial,
  ToothSurface.lingual,
];

void main() {
  group('ToothGeometry surface hit-testing', () {
    test('a molar has five crown regions and each centre hits itself', () {
      final shape = ToothGeometry.build(ToothId.parse('16'), _cell);
      expect(shape.surfaces.keys, containsAll(_faces));
      for (final face in _faces) {
        final centre = shape.pathForSurface(face).getBounds().center;
        expect(shape.surfaceAt(centre), face, reason: face.name);
      }
    });

    test(
      'an incisor has an incisal strip plus M/D/F/L and each centre hits',
      () {
        final shape = ToothGeometry.build(ToothId.parse('11'), _cell);
        final strip = shape.pathForSurface(ToothSurface.occlusal).getBounds();
        final facial = shape.pathForSurface(ToothSurface.facial).getBounds();
        expect(strip.height, lessThan(facial.height));
        expect(strip.width, greaterThan(strip.height));
        for (final face in _faces) {
          final centre = shape.pathForSurface(face).getBounds().center;
          expect(shape.surfaceAt(centre), face, reason: face.name);
        }
      },
    );

    test(
      'a point off the tooth returns null, a point on the root returns root',
      () {
        final shape = ToothGeometry.build(ToothId.parse('36'), _cell);
        expect(shape.surfaceAt(const Offset(500, 500)), isNull);
        final rootCentre = shape.rootPath.getBounds().center;
        // Lower molar: two roots, the centre lies in the gap; probe one root.
        final rootBounds = shape.rootPath.getBounds();
        final onRoot = Offset(
          rootBounds.left + rootBounds.width * 0.22,
          rootBounds.top + rootBounds.height * 0.3,
        );
        expect(shape.surfaceAt(onRoot), ToothSurface.root);
        expect(shape.contains(onRoot), isTrue);
        expect(rootCentre.dy, greaterThan(shape.crownBounds.center.dy));
      },
    );
  });

  group('ToothGeometry orientation', () {
    test(
      'mesial of 11 is to the viewer right of centre, of 21 to the left',
      () {
        final ur1 = ToothGeometry.build(ToothId.parse('11'), _cell);
        final ul1 = ToothGeometry.build(ToothId.parse('21'), _cell);
        final urMesial = ur1
            .pathForSurface(ToothSurface.mesial)
            .getBounds()
            .center;
        final ulMesial = ul1
            .pathForSurface(ToothSurface.mesial)
            .getBounds()
            .center;
        expect(urMesial.dx, greaterThan(ur1.crownBounds.center.dx));
        expect(ulMesial.dx, lessThan(ul1.crownBounds.center.dx));
        final urDistal = ur1
            .pathForSurface(ToothSurface.distal)
            .getBounds()
            .center;
        expect(urDistal.dx, lessThan(ur1.crownBounds.center.dx));
      },
    );

    test('mesial of lower teeth also faces the midline', () {
      final lr6 = ToothGeometry.build(ToothId.parse('46'), _cell);
      final ll6 = ToothGeometry.build(ToothId.parse('36'), _cell);
      expect(
        lr6.pathForSurface(ToothSurface.mesial).getBounds().center.dx,
        greaterThan(lr6.crownBounds.center.dx),
      );
      expect(
        ll6.pathForSurface(ToothSurface.mesial).getBounds().center.dx,
        lessThan(ll6.crownBounds.center.dx),
      );
    });

    test(
      'facial faces the lips: top for upper teeth, bottom for lower teeth',
      () {
        final upper = ToothGeometry.build(ToothId.parse('16'), _cell);
        final lower = ToothGeometry.build(ToothId.parse('46'), _cell);
        expect(
          upper.pathForSurface(ToothSurface.facial).getBounds().center.dy,
          lessThan(upper.occlusalCentre.dy),
        );
        expect(
          upper.pathForSurface(ToothSurface.lingual).getBounds().center.dy,
          greaterThan(upper.occlusalCentre.dy),
        );
        expect(
          lower.pathForSurface(ToothSurface.facial).getBounds().center.dy,
          greaterThan(lower.occlusalCentre.dy),
        );
      },
    );

    test('roots point away from the occlusal plane', () {
      final upper = ToothGeometry.build(ToothId.parse('16'), _cell);
      final lower = ToothGeometry.build(ToothId.parse('46'), _cell);
      expect(upper.rootUp, isTrue);
      expect(upper.rootPath.getBounds().top, lessThan(upper.crownBounds.top));
      expect(lower.rootUp, isFalse);
      expect(
        lower.rootPath.getBounds().bottom,
        greaterThan(lower.crownBounds.bottom),
      );
      expect(upper.labelAnchor.dy, greaterThan(upper.crownBounds.bottom - 1));
      expect(lower.labelAnchor.dy, lessThan(lower.crownBounds.top + 1));
    });

    test('every tooth builds with a non-empty root and crown', () {
      for (final tooth in [
        ...ToothId.permanentTeeth(),
        ...ToothId.primaryTeeth(),
      ]) {
        final shape = ToothGeometry.build(tooth, _cell);
        expect(shape.rootPath.getBounds().isEmpty, isFalse, reason: tooth.fdi);
        expect(shape.crownBounds.isEmpty, isFalse, reason: tooth.fdi);
        expect(
          shape.pathForSurface(ToothSurface.whole).getBounds().isEmpty,
          isFalse,
        );
        expect(
          shape.pathForSurface(ToothSurface.classV).getBounds().isEmpty,
          isFalse,
        );
      }
    });

    test('crown width narrows from molar to lateral incisor', () {
      expect(
        ToothGeometry.crownWidthFraction(ToothId.parse('16')),
        greaterThan(ToothGeometry.crownWidthFraction(ToothId.parse('14'))),
      );
      expect(
        ToothGeometry.crownWidthFraction(ToothId.parse('14')),
        greaterThan(ToothGeometry.crownWidthFraction(ToothId.parse('12'))),
      );
    });
  });
}
