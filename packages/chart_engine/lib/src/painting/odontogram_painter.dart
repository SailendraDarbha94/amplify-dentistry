import 'dart:math' as math;

import 'package:ampdent_core/ampdent_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../geometry/tooth_geometry.dart';
import '../layout/odontogram_layout.dart';
import '../model/tooth_overlay.dart';
import '../style/odontogram_style.dart';
import 'chart_text_cache.dart';
import 'overlay_painter.dart';

/// Paints an [OdontogramLayout]: tooth shapes, overlays, labels, selection
/// ring, surface highlights and badges. All paths come precomputed from the
/// layout; [shouldRepaint] compares inputs so unchanged charts cost nothing.
class OdontogramPainter extends CustomPainter {
  OdontogramPainter({
    required this.layout,
    required this.teeth,
    required this.notation,
    required this.style,
    required this.textCache,
    this.selectedTooth,
    this.selectedSurfaces = const SurfaceSet.empty(),
  });

  final OdontogramLayout layout;
  final Map<ToothId, ToothVisual> teeth;
  final ToothNotation notation;
  final OdontogramStyle style;
  final ChartTextCache textCache;
  final ToothId? selectedTooth;
  final SurfaceSet selectedSurfaces;

  @override
  void paint(Canvas canvas, Size size) {
    _paintMidline(canvas);
    for (final row in layout.rows) {
      for (final tooth in row.slots) {
        final shape = layout.shapes[tooth];
        if (shape == null) continue;
        final visual =
            teeth[tooth] ??
            ToothVisual(tooth: tooth, state: ToothState.present);
        _paintTooth(canvas, shape, visual);
        _paintLabel(canvas, row, shape);
      }
    }
    final selected = selectedTooth;
    if (selected != null) {
      final shape = layout.shapes[selected];
      if (shape != null) _paintSelection(canvas, shape);
    }
  }

  void _paintMidline(Canvas canvas) {
    final x = layout.midlineX;
    if (x == null) return;
    final paint = Paint()
      ..color = style.midlineColor
      ..strokeWidth = 1;
    final top = layout.rows.first.cellBounds.top;
    final bottom = layout.rows.last.cellBounds.bottom;
    for (var y = top; y < bottom; y += 6) {
      canvas.drawLine(Offset(x, y), Offset(x, math.min(y + 3, bottom)), paint);
    }
  }

  void _paintTooth(Canvas canvas, ToothShape shape, ToothVisual visual) {
    final state = visual.state;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = style.outlineWidth
      ..strokeJoin = StrokeJoin.round;

    if (state.isAbsent) {
      outline.color = style.absentOutline;
      canvas.drawPath(shape.crownOutline, outline);
      final hasMissingOverlay = visual.overlays.any(
        (o) => o.kind == OverlayKind.missing,
      );
      if (!hasMissingOverlay) {
        OverlayPainter.cross(
          canvas,
          shape.crownBounds,
          style.missingMark,
          style.outlineWidth * 2,
        );
      }
    } else if (state == ToothState.implant) {
      _paintCrown(canvas, shape, style.toothFill, outline);
      final hasImplantOverlay = visual.overlays.any(
        (o) =>
            o.kind == OverlayKind.implant ||
            o.kind == OverlayKind.plannedImplant,
      );
      if (!hasImplantOverlay) {
        OverlayPainter.implantGlyph(
          canvas,
          shape,
          style.overlayColors[OverlayKind.implant]!,
          style,
          planned: false,
        );
      }
    } else {
      final fill =
          state == ToothState.present || state == ToothState.supernumerary
          ? style.toothFill
          : style.eruptingFill;
      canvas.drawPath(shape.rootPath, Paint()..color = style.rootFill);
      canvas.drawPath(
        shape.rootPath,
        Paint()
          ..color = style.rootOutline
          ..style = PaintingStyle.stroke
          ..strokeWidth = style.outlineWidth,
      );
      _paintCrown(canvas, shape, fill, outline);
    }

    for (final overlay in visual.overlays) {
      OverlayPainter.paint(canvas, shape, overlay, style);
      final label = overlay.label;
      if (label != null && label.isNotEmpty) {
        textCache.paintCentred(
          canvas,
          label,
          shape.occlusalCentre,
          fontSize: math.max(7.0, shape.crownBounds.width * 0.22),
          color: style.labelColor,
          fontFamily: style.fontFamily,
        );
      }
    }

    if (!state.isAbsent) {
      // Re-stroke the face divisions so fills never hide the map lines.
      outline.color = style.toothOutline;
      for (final path in shape.surfaces.values) {
        canvas.drawPath(path, outline);
      }
    }
    if (visual.badgeCount > 0) _paintBadge(canvas, shape, visual.badgeCount);
  }

  void _paintCrown(Canvas canvas, ToothShape shape, Color fill, Paint outline) {
    canvas.drawPath(shape.crownOutline, Paint()..color = fill);
    outline.color = style.toothOutline;
    canvas.drawPath(shape.crownOutline, outline);
  }

  void _paintBadge(Canvas canvas, ToothShape shape, int count) {
    final c = shape.crownBounds;
    final r = math.max(5.0, c.width * 0.18);
    final centre = Offset(c.right - r * 0.6, c.top + r * 0.6);
    canvas.drawCircle(centre, r, Paint()..color = style.badgeFill);
    textCache.paintCentred(
      canvas,
      count > 9 ? '9+' : '$count',
      centre,
      fontSize: r * 1.2,
      color: style.badgeText,
      weight: FontWeight.w700,
      fontFamily: style.fontFamily,
    );
  }

  void _paintLabel(Canvas canvas, OdontogramRow row, ToothShape shape) {
    final text = notation.formatPlain(shape.tooth);
    final fontSize = (row.cellWidth * 0.28).clamp(8.0, style.labelFontSize);
    textCache.paintCentred(
      canvas,
      text,
      Offset(shape.bounds.center.dx, row.labelBand.center.dy),
      fontSize: fontSize,
      color: style.labelColor,
      fontFamily: style.fontFamily,
    );
  }

  void _paintSelection(Canvas canvas, ToothShape shape) {
    if (selectedSurfaces.isNotEmpty) {
      final fill = Paint()..color = style.selectedSurfaceFill;
      for (final s in selectedSurfaces.surfaces) {
        canvas.drawPath(shape.pathForSurface(s), fill);
      }
    }
    final ring = RRect.fromRectAndRadius(
      shape.bounds.deflate(style.selectedRingWidth / 2),
      Radius.circular(shape.bounds.width * 0.15),
    );
    canvas.drawRRect(
      ring,
      Paint()
        ..color = style.selectedRing
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.selectedRingWidth,
    );
  }

  @override
  bool shouldRepaint(covariant OdontogramPainter old) =>
      !identical(old.layout, layout) ||
      old.notation != notation ||
      old.style != style ||
      old.selectedTooth != selectedTooth ||
      old.selectedSurfaces != selectedSurfaces ||
      (!identical(old.teeth, teeth) && !mapEquals(old.teeth, teeth));

  @override
  bool hitTest(Offset position) => true;
}
