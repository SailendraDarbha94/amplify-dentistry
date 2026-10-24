import 'dart:ui';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:flutter/foundation.dart';

import '../geometry/tooth_geometry.dart';

/// Inputs that fully determine an [OdontogramLayout]. Equal specs produce
/// identical layouts, which is what [ToothLayoutCache] keys on.
@immutable
class OdontogramLayoutSpec {
  const OdontogramLayoutSpec({
    required this.availableWidth,
    required this.visibleTeeth,
    this.availableHeight = double.infinity,
    this.compact = false,
    this.mixedDentition = false,
    this.midlineGap = 12,
    this.minToothWidth = 44,
    this.labelHeight = 16,
    this.primaryScale = 0.72,
    this.rowSpacing = 6,
    this.padding = 4,
    this.toothAspect = 2.0,
  });

  /// Width offered by the parent; the layout may exceed it (then scroll).
  final double availableWidth;

  /// Height offered by the parent, or infinity when unconstrained.
  final double availableHeight;

  /// Compact mode stacks the four quadrant rows (8 teeth each).
  final bool compact;

  /// Draw the primary rows between the permanent rows.
  final bool mixedDentition;

  /// Teeth that get a shape (see `visibleTeeth` in `ampdent_core`).
  final List<ToothId> visibleTeeth;

  /// Horizontal gap at the midline in standard mode.
  final double midlineGap;

  /// Minimum tooth column width (touch target).
  final double minToothWidth;

  /// Height of the label band on the occlusal side of each row.
  final double labelHeight;

  /// Scale of primary teeth relative to permanent teeth.
  final double primaryScale;

  /// Vertical spacing between rows.
  final double rowSpacing;

  /// Outer padding.
  final double padding;

  /// Cell height / cell width of a permanent tooth.
  final double toothAspect;

  @override
  bool operator ==(Object other) =>
      other is OdontogramLayoutSpec &&
      other.availableWidth == availableWidth &&
      other.availableHeight == availableHeight &&
      other.compact == compact &&
      other.mixedDentition == mixedDentition &&
      other.midlineGap == midlineGap &&
      other.minToothWidth == minToothWidth &&
      other.labelHeight == labelHeight &&
      other.primaryScale == primaryScale &&
      other.rowSpacing == rowSpacing &&
      other.padding == padding &&
      other.toothAspect == toothAspect &&
      listEquals(other.visibleTeeth, visibleTeeth);

  @override
  int get hashCode => Object.hash(
    availableWidth,
    availableHeight,
    compact,
    mixedDentition,
    midlineGap,
    minToothWidth,
    labelHeight,
    primaryScale,
    rowSpacing,
    padding,
    toothAspect,
    Object.hashAll(visibleTeeth),
  );
}

/// One horizontal row of tooth cells (an arch, or a quadrant in compact mode).
class OdontogramRow {
  const OdontogramRow({
    required this.arch,
    required this.dentition,
    required this.quadrant,
    required this.slots,
    required this.cellBounds,
    required this.labelBand,
    required this.cellWidth,
  });

  final Arch arch;
  final Dentition dentition;

  /// Set in compact mode only.
  final Quadrant? quadrant;

  /// Every tooth position in the row in viewer order, visible or not.
  final List<ToothId> slots;

  /// Area holding the tooth cells.
  final Rect cellBounds;

  /// Label strip on the occlusal side of the cells.
  final Rect labelBand;

  /// Width of one tooth column.
  final double cellWidth;

  /// Labels sit below the cells for upper rows and above for lower rows.
  bool get labelsBelow => arch == Arch.upper;
}

/// Result of hit-testing the layout.
@immutable
class ToothHit {
  const ToothHit(this.tooth, this.surface);

  final ToothId tooth;

  /// The surface under the point, or null when the tap is inside the cell
  /// but off the drawn faces.
  final ToothSurface? surface;
}

/// Positions of every tooth as the clinician views the patient: the
/// patient's right on the viewer's left, upper arch above lower arch.
class OdontogramLayout {
  const OdontogramLayout._({
    required this.spec,
    required this.size,
    required this.rows,
    required this.shapes,
    required this.cells,
    required this.midlineX,
  });

  final OdontogramLayoutSpec spec;

  /// Total size needed; may exceed the available width.
  final Size size;
  final List<OdontogramRow> rows;

  /// Shape per visible tooth.
  final Map<ToothId, ToothShape> shapes;

  /// Full touch cell per visible tooth (at least [OdontogramLayoutSpec.minToothWidth] wide).
  final Map<ToothId, Rect> cells;

  /// X of the midline in standard mode, null in compact mode.
  final double? midlineX;

  /// Whether the layout is wider than the space offered.
  bool get overflowsWidth => size.width > spec.availableWidth + 0.5;

  /// The visible tooth whose cell contains [point].
  ToothId? toothAt(Offset point) {
    for (final entry in cells.entries) {
      if (entry.value.contains(point)) return entry.key;
    }
    return null;
  }

  /// Tooth and surface under [point].
  ToothHit? hitTest(Offset point) {
    final tooth = toothAt(point);
    if (tooth == null) return null;
    return ToothHit(tooth, shapes[tooth]!.surfaceAt(point));
  }

  /// Computes the layout for [spec].
  static OdontogramLayout compute(OdontogramLayoutSpec spec) {
    final rowSpecs = _rowSpecs(spec);
    final cols = spec.compact ? 8 : 16;
    final gap = spec.compact ? 0.0 : spec.midlineGap;

    var heightFactor = 0.0;
    for (final r in rowSpecs) {
      heightFactor += spec.toothAspect * (r.primary ? spec.primaryScale : 1);
    }
    final fixedHeight =
        2 * spec.padding +
        rowSpecs.length * spec.labelHeight +
        (rowSpecs.length - 1) * spec.rowSpacing;

    final widthFit = (spec.availableWidth - 2 * spec.padding - gap) / cols;
    final heightFit = spec.availableHeight.isFinite
        ? (spec.availableHeight - fixedHeight) / heightFactor
        : double.infinity;
    var w = widthFit < heightFit ? widthFit : heightFit;
    if (w < spec.minToothWidth) w = spec.minToothWidth;

    final size = Size(
      2 * spec.padding + cols * w + gap,
      heightFactor * w + fixedHeight,
    );
    final visible = spec.visibleTeeth.toSet();
    final rows = <OdontogramRow>[];
    final shapes = <ToothId, ToothShape>{};
    final cells = <ToothId, Rect>{};

    var y = spec.padding;
    for (final r in rowSpecs) {
      final scale = r.primary ? spec.primaryScale : 1.0;
      final cellH = spec.toothAspect * scale * w;
      final cellTop = r.arch == Arch.upper ? y : y + spec.labelHeight;
      final labelTop = r.arch == Arch.upper ? y + cellH : y;
      final rowLeft = spec.padding;
      final rowWidth = cols * w + gap;
      for (final tooth in r.slots) {
        if (!visible.contains(tooth)) continue;
        final col = _column(tooth, spec.compact);
        final x = rowLeft + col * w + (!spec.compact && col >= 8 ? gap : 0);
        final cell = Rect.fromLTWH(x, cellTop, w, cellH);
        cells[tooth] = cell;
        final shapeW = w * scale;
        final shapeBounds = Rect.fromLTWH(
          cell.center.dx - shapeW / 2,
          cellTop,
          shapeW,
          cellH,
        );
        shapes[tooth] = ToothGeometry.build(
          tooth,
          Rect.fromLTWH(
            shapeBounds.left + shapeW * 0.05,
            shapeBounds.top,
            shapeW * 0.9,
            cellH,
          ),
        );
      }
      rows.add(
        OdontogramRow(
          arch: r.arch,
          dentition: r.dentition,
          quadrant: r.quadrant,
          slots: r.slots,
          cellBounds: Rect.fromLTWH(rowLeft, cellTop, rowWidth, cellH),
          labelBand: Rect.fromLTWH(
            rowLeft,
            labelTop,
            rowWidth,
            spec.labelHeight,
          ),
          cellWidth: w,
        ),
      );
      y += cellH + spec.labelHeight + spec.rowSpacing;
    }

    return OdontogramLayout._(
      spec: spec,
      size: size,
      rows: rows,
      shapes: shapes,
      cells: cells,
      midlineX: spec.compact ? null : spec.padding + 8 * w + gap / 2,
    );
  }

  /// Column index (0 = viewer's left) of a tooth in its row.
  static int _column(ToothId tooth, bool compact) {
    final anchor = tooth.isPrimary ? tooth.permanentSuccessor! : tooth;
    if (!compact) return anchor.archIndex - 1;
    return anchor.side == Side.right
        ? 8 - anchor.position
        : anchor.position - 1;
  }

  static List<_RowSpec> _rowSpecs(OdontogramLayoutSpec spec) {
    if (!spec.compact) {
      return [
        _RowSpec.arch(Arch.upper, Dentition.permanent),
        if (spec.mixedDentition) _RowSpec.arch(Arch.upper, Dentition.primary),
        if (spec.mixedDentition) _RowSpec.arch(Arch.lower, Dentition.primary),
        _RowSpec.arch(Arch.lower, Dentition.permanent),
      ];
    }
    final mixed = spec.mixedDentition;
    return [
      _RowSpec.quadrant(Quadrant.upperRight, Dentition.permanent),
      if (mixed) _RowSpec.quadrant(Quadrant.upperRight, Dentition.primary),
      _RowSpec.quadrant(Quadrant.upperLeft, Dentition.permanent),
      if (mixed) _RowSpec.quadrant(Quadrant.upperLeft, Dentition.primary),
      if (mixed) _RowSpec.quadrant(Quadrant.lowerLeft, Dentition.primary),
      _RowSpec.quadrant(Quadrant.lowerLeft, Dentition.permanent),
      if (mixed) _RowSpec.quadrant(Quadrant.lowerRight, Dentition.primary),
      _RowSpec.quadrant(Quadrant.lowerRight, Dentition.permanent),
    ];
  }
}

class _RowSpec {
  _RowSpec.arch(this.arch, this.dentition)
    : quadrant = null,
      slots = ToothId.archRow(arch, dentition);

  _RowSpec.quadrant(Quadrant q, this.dentition)
    : arch = q.arch,
      quadrant = q,
      slots = ToothId.archRow(
        q.arch,
        dentition,
      ).where((t) => t.quadrant == q).toList();

  final Arch arch;
  final Dentition dentition;
  final Quadrant? quadrant;
  final List<ToothId> slots;

  bool get primary => dentition == Dentition.primary;
}

/// Memoises layouts by spec so paths are only rebuilt when the size, mode or
/// visible teeth change. Keeps the most recent [capacity] entries.
class ToothLayoutCache {
  ToothLayoutCache({this.capacity = 4});

  final int capacity;
  final Map<OdontogramLayoutSpec, OdontogramLayout> _entries = {};

  /// Number of cached layouts.
  int get length => _entries.length;

  /// Returns the cached layout for [spec], computing it on a miss.
  OdontogramLayout layoutFor(OdontogramLayoutSpec spec) {
    final cached = _entries.remove(spec);
    if (cached != null) {
      _entries[spec] = cached;
      return cached;
    }
    final layout = OdontogramLayout.compute(spec);
    _entries[spec] = layout;
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
    return layout;
  }

  /// Drops every cached layout.
  void clear() => _entries.clear();
}
