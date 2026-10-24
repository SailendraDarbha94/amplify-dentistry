import 'dart:ui';

import 'package:ampdent_core/ampdent_core.dart';
import 'package:flutter/foundation.dart';

import '../perio/perio_sequence.dart';

/// Rows of the perio grid, top to bottom.
enum PerioRowKind {
  header(null, ''),
  probingDepth(PerioMeasurementType.probingDepth, 'PD'),
  gingivalMargin(PerioMeasurementType.gingivalMargin, 'GM'),
  bleeding(PerioMeasurementType.bleedingOnProbing, 'BOP'),
  plaque(PerioMeasurementType.plaque, 'PL'),
  mobility(PerioMeasurementType.mobility, 'Mob'),
  furcation(PerioMeasurementType.furcation, 'Furc');

  const PerioRowKind(this.type, this.label);

  /// Measurement recorded in this row (null for the header).
  final PerioMeasurementType? type;

  /// Row label drawn in the left gutter.
  final String label;

  /// Whether the row has one sub-cell per site (3) rather than one per tooth.
  bool get isPerSite => type?.isPerSite ?? false;
}

/// One tappable grid cell.
@immutable
class PerioCell {
  const PerioCell({
    required this.tooth,
    required this.site,
    required this.type,
  });

  final ToothId tooth;

  /// Null for per-tooth rows (mobility, furcation).
  final PerioSite? site;
  final PerioMeasurementType type;

  @override
  bool operator ==(Object other) =>
      other is PerioCell &&
      other.tooth == tooth &&
      other.site == site &&
      other.type == type;

  @override
  int get hashCode => Object.hash(tooth, site, type);
}

/// Inputs that determine a [PerioGridLayout].
@immutable
class PerioGridSpec {
  const PerioGridSpec({
    required this.arch,
    required this.aspect,
    required this.teeth,
    required this.availableWidth,
    this.minColumnWidth = 72,
    this.gutterWidth = 44,
    this.rowHeight = 36,
    this.headerHeight = 26,
  });

  final Arch arch;
  final PerioAspect aspect;

  /// Teeth shown as columns, in viewer order.
  final List<ToothId> teeth;
  final double availableWidth;
  final double minColumnWidth;

  /// Width of the row-label gutter on the left.
  final double gutterWidth;
  final double rowHeight;
  final double headerHeight;

  @override
  bool operator ==(Object other) =>
      other is PerioGridSpec &&
      other.arch == arch &&
      other.aspect == aspect &&
      other.availableWidth == availableWidth &&
      other.minColumnWidth == minColumnWidth &&
      other.gutterWidth == gutterWidth &&
      other.rowHeight == rowHeight &&
      other.headerHeight == headerHeight &&
      listEquals(other.teeth, teeth);

  @override
  int get hashCode => Object.hash(
    arch,
    aspect,
    availableWidth,
    minColumnWidth,
    gutterWidth,
    rowHeight,
    headerHeight,
    Object.hashAll(teeth),
  );
}

/// Geometry of the perio grid: a column per tooth, a row per measurement,
/// three sub-cells per site row.
class PerioGridLayout {
  PerioGridLayout._(this.spec, this.size, this.columnWidth);

  final PerioGridSpec spec;
  final Size size;
  final double columnWidth;

  /// Rows in display order.
  static const List<PerioRowKind> rows = PerioRowKind.values;

  /// Whether the grid is wider than the space offered.
  bool get overflowsWidth => size.width > spec.availableWidth + 0.5;

  /// Computes the grid for [spec].
  static PerioGridLayout compute(PerioGridSpec spec) {
    final n = spec.teeth.length;
    final fit = n == 0
        ? spec.minColumnWidth
        : (spec.availableWidth - spec.gutterWidth) / n;
    final w = fit < spec.minColumnWidth ? spec.minColumnWidth : fit;
    final height = spec.headerHeight + (rows.length - 1) * spec.rowHeight;
    return PerioGridLayout._(spec, Size(spec.gutterWidth + n * w, height), w);
  }

  /// Horizontal extent of a tooth's column.
  Rect columnRect(int columnIndex) => Rect.fromLTWH(
    spec.gutterWidth + columnIndex * columnWidth,
    0,
    columnWidth,
    size.height,
  );

  /// Vertical extent of a row.
  Rect rowRect(PerioRowKind row) {
    if (row == PerioRowKind.header) {
      return Rect.fromLTWH(0, 0, size.width, spec.headerHeight);
    }
    final top = spec.headerHeight + (row.index - 1) * spec.rowHeight;
    return Rect.fromLTWH(0, top, size.width, spec.rowHeight);
  }

  /// Rect of the gutter label for a row.
  Rect gutterRect(PerioRowKind row) {
    final r = rowRect(row);
    return Rect.fromLTWH(0, r.top, spec.gutterWidth, r.height);
  }

  /// Rect of one cell; [site] selects the sub-cell on per-site rows.
  Rect cellRect(int columnIndex, PerioRowKind row, {PerioSite? site}) {
    final col = columnRect(columnIndex);
    final r = rowRect(row);
    if (!row.isPerSite || site == null) {
      return Rect.fromLTWH(col.left, r.top, col.width, r.height);
    }
    final order = sitesInViewerOrder(spec.teeth[columnIndex], spec.aspect);
    final i = order.indexOf(site);
    final sub = col.width / 3;
    return Rect.fromLTWH(
      col.left + (i < 0 ? 0 : i) * sub,
      r.top,
      sub,
      r.height,
    );
  }

  /// The cell under [point], or null on the header or gutter.
  PerioCell? hitTest(Offset point) {
    if (point.dx < spec.gutterWidth || point.dy < spec.headerHeight) {
      return null;
    }
    final column = ((point.dx - spec.gutterWidth) / columnWidth).floor();
    if (column < 0 || column >= spec.teeth.length) return null;
    final rowIndex =
        ((point.dy - spec.headerHeight) / spec.rowHeight).floor() + 1;
    if (rowIndex < 1 || rowIndex >= rows.length) return null;
    final row = rows[rowIndex];
    final tooth = spec.teeth[column];
    if (!row.isPerSite) {
      return PerioCell(tooth: tooth, site: null, type: row.type!);
    }
    final sub =
        ((point.dx - spec.gutterWidth - column * columnWidth) /
                (columnWidth / 3))
            .floor()
            .clamp(0, 2);
    return PerioCell(
      tooth: tooth,
      site: sitesInViewerOrder(tooth, spec.aspect)[sub],
      type: row.type!,
    );
  }
}
