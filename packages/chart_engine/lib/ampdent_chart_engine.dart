/// Pure dart:ui odontogram and six-site periodontal chart for AmpDent.
///
/// Depends only on `ampdent_core` and Flutter. The painters use dart:ui
/// alone; the public widgets are thin Material wrappers.
///
/// Public API
///
/// Geometry (`src/geometry/tooth_geometry.dart`)
/// - `ToothGeometry.build(ToothId, Rect) -> ToothShape`: procedural crown map
///   view (five faces keyed by `ToothSurface`), 1-3 root silhouette and label
///   anchor, mirrored per side and arch.
/// - `ToothShape.pathForSurface(ToothSurface)`, `ToothShape.surfaceAt(Offset)`.
///
/// Layout (`src/layout/odontogram_layout.dart`)
/// - `OdontogramLayoutSpec`: size, compact / mixed-dentition flags, visible
///   teeth, midline gap, 44 px minimum touch width.
/// - `OdontogramLayout.compute(spec)`: rows, shapes, cells, `hitTest`.
/// - `ToothLayoutCache.layoutFor(spec)`: memoised layouts.
///
/// Model and style
/// - `OverlayKind`, `ToothOverlay`, `ToothVisual`, `toothVisualsFromStates`.
/// - `OdontogramStyle.light` / `.dark`, `PerioStyle.light` / `.dark`.
///
/// Painting
/// - `OdontogramPainter`, `OverlayPainter`, `PerioGridPainter`,
///   `ChartTextCache`.
///
/// Widgets
/// - `Odontogram`: tap tooth, then tap surface; long press; scrolls when
///   narrow; `compact` stacks quadrant rows.
/// - `ToothLegend`, `OdontogramNotationToggle`.
/// - `PerioChart` (one arch, one aspect), `PerioNumberPad`.
///
/// Perio helpers (`src/perio/perio_sequence.dart`)
/// - `PerioAspect`, `sitesInViewerOrder`, `perioEntrySequence`,
///   `PerioEntryCursor`.
///
/// Demo data: `DemoCharts.adult()`, `.mixedAge8()`, `.adultWithOverlays()`.
library;

export 'src/demo/demo_charts.dart';
export 'src/geometry/tooth_geometry.dart';
export 'src/layout/odontogram_layout.dart';
export 'src/layout/perio_grid_layout.dart';
export 'src/model/tooth_overlay.dart';
export 'src/painting/chart_text_cache.dart';
export 'src/painting/odontogram_painter.dart';
export 'src/painting/overlay_painter.dart';
export 'src/painting/perio_grid_painter.dart';
export 'src/perio/perio_sequence.dart';
export 'src/style/odontogram_style.dart';
export 'src/style/perio_style.dart';
export 'src/widgets/notation_toggle.dart';
export 'src/widgets/odontogram.dart';
export 'src/widgets/perio_chart.dart';
export 'src/widgets/perio_number_pad.dart';
export 'src/widgets/tooth_legend.dart';
