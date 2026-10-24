import 'dart:math' as math;

import 'package:ampdent_core/ampdent_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../layout/perio_grid_layout.dart';
import '../perio/perio_sequence.dart';
import '../style/perio_style.dart';
import 'chart_text_cache.dart';

/// Paints the perio grid: header labels, PD/GM numbers with threshold
/// colours, bleeding and plaque dots, mobility and furcation.
class PerioGridPainter extends CustomPainter {
  PerioGridPainter({
    required this.layout,
    required this.states,
    required this.readings,
    required this.toothReadings,
    required this.notation,
    required this.style,
    required this.textCache,
    this.focusedCell,
  });

  final PerioGridLayout layout;
  final Map<ToothId, ToothState> states;

  /// Site readings keyed by (tooth, site).
  final Map<(ToothId, PerioSite), PerioSiteReading> readings;
  final Map<ToothId, PerioToothReading> toothReadings;
  final ToothNotation notation;
  final PerioStyle style;
  final ChartTextCache textCache;
  final (ToothId, PerioSite)? focusedCell;

  @override
  void paint(Canvas canvas, Size size) {
    final teeth = layout.spec.teeth;
    canvas.drawRect(
      Offset.zero & layout.size,
      Paint()..color = style.cellBackground,
    );
    canvas.drawRect(
      layout.rowRect(PerioRowKind.header),
      Paint()..color = style.headerBackground,
    );
    for (var c = 0; c < teeth.length; c++) {
      final tooth = teeth[c];
      final state = states[tooth];
      final skipped =
          (toothReadings[tooth]?.skipped ?? false) ||
          (state != null &&
              !(state.isDrawnPresent || state == ToothState.implant));
      if (skipped) {
        canvas.drawRect(
          layout.columnRect(c),
          Paint()..color = style.absentColumn,
        );
      }
      _paintHeader(canvas, c, tooth);
      if (!skipped) _paintColumn(canvas, c, tooth);
    }
    _paintGutter(canvas);
    _paintFocus(canvas);
    _paintGrid(canvas);
  }

  void _paintHeader(Canvas canvas, int c, ToothId tooth) {
    textCache.paintCentred(
      canvas,
      notation.formatPlain(tooth),
      layout.cellRect(c, PerioRowKind.header).center,
      fontSize: style.fontSize,
      color: style.text,
      weight: FontWeight.w600,
      fontFamily: style.fontFamily,
    );
  }

  void _paintGutter(Canvas canvas) {
    for (final row in PerioGridLayout.rows) {
      if (row == PerioRowKind.header) continue;
      textCache.paintCentred(
        canvas,
        row.label,
        layout.gutterRect(row).center,
        fontSize: style.fontSize - 1,
        color: style.mutedText,
        fontFamily: style.fontFamily,
      );
    }
  }

  void _paintColumn(Canvas canvas, int c, ToothId tooth) {
    final aspect = layout.spec.aspect;
    for (final site in sitesInViewerOrder(tooth, aspect)) {
      final r = readings[(tooth, site)];
      final pd = r?.probingDepth;
      final gm = r?.gingivalMargin;
      textCache.paintCentred(
        canvas,
        pd?.toString() ?? '–',
        layout.cellRect(c, PerioRowKind.probingDepth, site: site).center,
        fontSize: style.fontSize,
        color: style.depthColor(pd),
        weight: pd != null && pd >= 4 ? FontWeight.w700 : FontWeight.w500,
        fontFamily: style.fontFamily,
      );
      textCache.paintCentred(
        canvas,
        gm?.toString() ?? '–',
        layout.cellRect(c, PerioRowKind.gingivalMargin, site: site).center,
        fontSize: style.fontSize,
        color: gm == null
            ? style.mutedText
            : (gm < 0 ? style.recession : style.text),
        fontFamily: style.fontFamily,
      );
      if (r != null && (r.bleeding || r.suppuration)) {
        final centre = layout
            .cellRect(c, PerioRowKind.bleeding, site: site)
            .center;
        canvas.drawCircle(
          centre,
          _dotRadius,
          Paint()
            ..color = r.suppuration ? style.suppurationDot : style.bleedingDot,
        );
        if (r.bleeding && r.suppuration) {
          canvas.drawCircle(
            centre,
            _dotRadius * 0.5,
            Paint()..color = style.bleedingDot,
          );
        }
      }
      if (r != null && r.plaque) {
        canvas.drawCircle(
          layout.cellRect(c, PerioRowKind.plaque, site: site).center,
          _dotRadius,
          Paint()..color = style.plaqueDot,
        );
      }
    }
    final t = toothReadings[tooth];
    final mobility = t?.mobility;
    if (mobility != null && mobility != MobilityGrade.none) {
      textCache.paintCentred(
        canvas,
        '${mobility.value}',
        layout.cellRect(c, PerioRowKind.mobility).center,
        fontSize: style.fontSize,
        color: mobility.value >= 2 ? style.depthSevere : style.text,
        fontFamily: style.fontFamily,
      );
    }
    final furcation = t?.furcation;
    if (furcation != null && furcation != FurcationGrade.none) {
      textCache.paintCentred(
        canvas,
        furcation.glickmanLabel,
        layout.cellRect(c, PerioRowKind.furcation).center,
        fontSize: style.fontSize,
        color: furcation.value >= 2 ? style.depthSevere : style.text,
        fontFamily: style.fontFamily,
      );
    }
  }

  double get _dotRadius => math.max(3.0, layout.spec.rowHeight * 0.14);

  void _paintFocus(Canvas canvas) {
    final focus = focusedCell;
    if (focus == null) return;
    final c = layout.spec.teeth.indexOf(focus.$1);
    if (c < 0) return;
    final col = layout.columnRect(c);
    final sub = layout.cellRect(c, PerioRowKind.probingDepth, site: focus.$2);
    final highlight = Rect.fromLTRB(
      sub.left,
      col.top + layout.spec.headerHeight,
      sub.right,
      col.bottom,
    );
    canvas.drawRect(highlight, Paint()..color = style.focusedCell);
    canvas.drawRect(
      sub.deflate(1),
      Paint()
        ..color = style.depthWarning
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _paintGrid(Canvas canvas) {
    final paint = Paint()
      ..color = style.gridLine
      ..strokeWidth = 1;
    final thin = Paint()
      ..color = style.gridLine.withValues(alpha: 0.5)
      ..strokeWidth = 0.5;
    for (final row in PerioGridLayout.rows) {
      final r = layout.rowRect(row);
      canvas.drawLine(
        Offset(0, r.bottom),
        Offset(layout.size.width, r.bottom),
        paint,
      );
    }
    final n = layout.spec.teeth.length;
    for (var c = 0; c <= n; c++) {
      final x = layout.spec.gutterWidth + c * layout.columnWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, layout.size.height), paint);
      if (c < n) {
        for (var s = 1; s < 3; s++) {
          final sx = x + s * layout.columnWidth / 3;
          final top = layout.rowRect(PerioRowKind.probingDepth).top;
          final bottom = layout.rowRect(PerioRowKind.plaque).bottom;
          canvas.drawLine(Offset(sx, top), Offset(sx, bottom), thin);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant PerioGridPainter old) =>
      !identical(old.layout, layout) ||
      old.notation != notation ||
      old.style != style ||
      old.focusedCell != focusedCell ||
      !mapEquals(old.states, states) ||
      !identical(old.readings, readings) ||
      !identical(old.toothReadings, toothReadings);
}
