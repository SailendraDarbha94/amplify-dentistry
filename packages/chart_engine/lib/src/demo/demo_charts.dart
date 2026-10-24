import 'package:ampdent_core/ampdent_core.dart';

import '../model/tooth_overlay.dart';

/// Demo and test data built from `defaultToothStates` in `ampdent_core`.
class DemoCharts {
  const DemoCharts._();

  /// A 30-year-old with every permanent tooth present and no findings.
  static Map<ToothId, ToothVisual> adult() =>
      toothVisualsFromStates(defaultToothStates(ageYears: 30));

  /// An 8-year-old in mixed dentition.
  static Map<ToothId, ToothVisual> mixedAge8() =>
      toothVisualsFromStates(defaultToothStates(ageYears: 8));

  /// A 30-year-old with a spread of overlays covering every kind.
  static Map<ToothId, ToothVisual> adultWithOverlays() {
    final chart = adult();
    void add(
      String fdi,
      ToothOverlay overlay, {
      ToothState? state,
      int badge = 0,
    }) {
      final id = ToothId.parse(fdi);
      final current = chart[id]!;
      chart[id] = current.copyWith(
        state: state,
        overlays: [...current.overlays, overlay],
        badgeCount: badge,
      );
    }

    add(
      '16',
      ToothOverlay(kind: OverlayKind.caries, surfaces: SurfaceSet.parse('O')),
      badge: 2,
    );
    add(
      '17',
      ToothOverlay(
        kind: OverlayKind.restoration,
        surfaces: SurfaceSet.parse('MOD'),
      ),
    );
    add(
      '15',
      ToothOverlay(
        kind: OverlayKind.plannedRestoration,
        surfaces: SurfaceSet.parse('DO'),
      ),
    );
    add('14', const ToothOverlay(kind: OverlayKind.rootCanal));
    add('14', const ToothOverlay(kind: OverlayKind.crown));
    add('25', const ToothOverlay(kind: OverlayKind.plannedRootCanal));
    add('25', const ToothOverlay(kind: OverlayKind.plannedCrown));
    add(
      '26',
      const ToothOverlay(kind: OverlayKind.missing),
      state: ToothState.extracted,
    );
    add('27', const ToothOverlay(kind: OverlayKind.extractionPlanned));
    add(
      '36',
      const ToothOverlay(kind: OverlayKind.implant),
      state: ToothState.implant,
    );
    add(
      '46',
      const ToothOverlay(kind: OverlayKind.plannedImplant),
      state: ToothState.extracted,
    );
    add('45', const ToothOverlay(kind: OverlayKind.bridgeAbutment));
    add(
      '44',
      const ToothOverlay(kind: OverlayKind.bridgePontic),
      state: ToothState.missing,
    );
    add('43', const ToothOverlay(kind: OverlayKind.bridgeAbutment));
    add(
      '11',
      ToothOverlay(kind: OverlayKind.veneer, surfaces: SurfaceSet.parse('F')),
    );
    add('21', const ToothOverlay(kind: OverlayKind.fracture));
    add(
      '37',
      ToothOverlay(kind: OverlayKind.sealant, surfaces: SurfaceSet.parse('O')),
    );
    add('47', const ToothOverlay(kind: OverlayKind.watch), badge: 1);
    add(
      '12',
      ToothOverlay(
        kind: OverlayKind.custom,
        surfaces: SurfaceSet.parse('L'),
        label: 'Z',
      ),
    );
    return chart;
  }
}
