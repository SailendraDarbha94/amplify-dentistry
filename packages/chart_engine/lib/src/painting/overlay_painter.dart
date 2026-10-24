import 'dart:math' as math;
import 'dart:ui';

import 'package:ampdent_core/ampdent_core.dart';

import '../geometry/tooth_geometry.dart';
import '../model/tooth_overlay.dart';
import '../style/odontogram_style.dart';

/// Low-level dart:ui drawing of a single [ToothOverlay] on a [ToothShape].
/// Pure functions; no Flutter widgets or Material.
class OverlayPainter {
  const OverlayPainter._();

  /// Draws [overlay] on [shape].
  static void paint(
    Canvas canvas,
    ToothShape shape,
    ToothOverlay overlay,
    OdontogramStyle style,
  ) {
    final color = style.colorFor(overlay);
    final planned = overlay.kind.isPlanned;
    switch (overlay.kind) {
      case OverlayKind.caries:
      case OverlayKind.restoration:
      case OverlayKind.sealant:
      case OverlayKind.veneer:
      case OverlayKind.custom:
        _fillSurfaces(canvas, shape, overlay, color, style);
      case OverlayKind.plannedRestoration:
        _hatchSurfaces(canvas, shape, overlay, color, style);
      case OverlayKind.rootCanal:
        canvas.drawPath(shape.rootPath, Paint()..color = color);
      case OverlayKind.plannedRootCanal:
        hatch(canvas, shape.rootPath, color, style.hatchSpacing);
        canvas.drawPath(shape.rootPath, _stroke(color, style.outlineWidth));
      case OverlayKind.crown:
      case OverlayKind.plannedCrown:
        _crown(canvas, shape, color, style, planned: planned);
      case OverlayKind.bridgeAbutment:
        _crown(canvas, shape, color, style, planned: false);
        _bridgeBar(canvas, shape, color, style);
      case OverlayKind.bridgePontic:
        canvas.drawPath(
          shape.crownOutline,
          Paint()..color = color.withValues(alpha: 0.35),
        );
        canvas.drawPath(
          shape.crownOutline,
          _stroke(color, style.outlineWidth * 2),
        );
        _bridgeBar(canvas, shape, color, style);
      case OverlayKind.implant:
      case OverlayKind.plannedImplant:
        implantGlyph(canvas, shape, color, style, planned: planned);
      case OverlayKind.extractionPlanned:
        cross(canvas, shape.crownBounds, color, style.outlineWidth * 2.5);
      case OverlayKind.missing:
        cross(canvas, shape.crownBounds, color, style.outlineWidth * 2);
      case OverlayKind.fracture:
        _fracture(canvas, shape, color, style);
      case OverlayKind.watch:
        _watch(canvas, shape, color, style);
    }
  }

  static Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeJoin = StrokeJoin.round;

  static Iterable<ToothSurface> _targets(ToothOverlay overlay) {
    final set = overlay.surfaces;
    if (set == null || set.isEmpty) {
      return const [
        ToothSurface.mesial,
        ToothSurface.occlusal,
        ToothSurface.distal,
        ToothSurface.facial,
        ToothSurface.lingual,
      ];
    }
    return set.surfaces.where((s) => s != ToothSurface.whole);
  }

  static void _fillSurfaces(
    Canvas canvas,
    ToothShape shape,
    ToothOverlay overlay,
    Color color,
    OdontogramStyle style,
  ) {
    final paint = Paint()..color = color;
    for (final s in _targets(overlay)) {
      canvas.drawPath(shape.pathForSurface(s), paint);
    }
    if (overlay.surfaces?.contains(ToothSurface.whole) ?? false) {
      canvas.drawPath(shape.crownOutline, paint);
    }
  }

  static void _hatchSurfaces(
    Canvas canvas,
    ToothShape shape,
    ToothOverlay overlay,
    Color color,
    OdontogramStyle style,
  ) {
    final outline = _stroke(color, style.outlineWidth * 1.5);
    for (final s in _targets(overlay)) {
      final path = shape.pathForSurface(s);
      hatch(canvas, path, color, style.hatchSpacing);
      canvas.drawPath(path, outline);
    }
  }

  /// Fills [path] with diagonal hatch lines in [color].
  static void hatch(Canvas canvas, Path path, Color color, double spacing) {
    final bounds = path.getBounds();
    if (bounds.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.save();
    canvas.clipPath(path);
    final span = bounds.width + bounds.height;
    for (var d = 0.0; d < span; d += spacing) {
      canvas.drawLine(
        Offset(bounds.left + d, bounds.top),
        Offset(bounds.left + d - bounds.height, bounds.bottom),
        paint,
      );
    }
    canvas.restore();
  }

  static void _crown(
    Canvas canvas,
    ToothShape shape,
    Color color,
    OdontogramStyle style, {
    required bool planned,
  }) {
    if (planned) {
      hatch(canvas, shape.crownOutline, color, style.hatchSpacing * 1.5);
      dashedPath(canvas, shape.crownOutline, color, style.outlineWidth * 2);
    } else {
      canvas.drawPath(
        shape.crownOutline,
        Paint()..color = color.withValues(alpha: 0.30),
      );
      canvas.drawPath(
        shape.crownOutline,
        _stroke(color, style.outlineWidth * 2.5),
      );
    }
  }

  static void _bridgeBar(
    Canvas canvas,
    ToothShape shape,
    Color color,
    OdontogramStyle style,
  ) {
    final c = shape.crownBounds;
    final y = shape.occlusalCentre.dy;
    canvas.drawLine(
      Offset(shape.bounds.left - c.width * 0.1, y),
      Offset(shape.bounds.right + c.width * 0.1, y),
      _stroke(color, math.max(2.0, c.height * 0.08)),
    );
  }

  /// Draws a screw-shaped implant glyph in the root area of [shape].
  static void implantGlyph(
    Canvas canvas,
    ToothShape shape,
    Color color,
    OdontogramStyle style, {
    required bool planned,
  }) {
    final root = shape.rootPath.getBounds();
    final cx = root.center.dx;
    final w = root.width * 0.32;
    final apexY = shape.rootUp
        ? root.top + root.height * 0.08
        : root.bottom - root.height * 0.08;
    final baseY = shape.rootUp ? root.bottom : root.top;
    final body = Path()
      ..moveTo(cx - w / 2, baseY)
      ..lineTo(cx + w / 2, baseY)
      ..lineTo(cx + w * 0.22, apexY)
      ..lineTo(cx - w * 0.22, apexY)
      ..close();
    if (planned) {
      hatch(canvas, body, color, style.hatchSpacing);
      canvas.drawPath(body, _stroke(color, style.outlineWidth * 1.5));
    } else {
      canvas.drawPath(body, Paint()..color = color);
    }
    // Threads.
    final thread = _stroke(
      planned ? color : style.toothFill,
      math.max(1.0, style.outlineWidth),
    );
    const turns = 5;
    for (var i = 1; i <= turns; i++) {
      final t = i / (turns + 1);
      final y = baseY + (apexY - baseY) * t;
      final half = (w / 2) * (1 - t * 0.5);
      canvas.drawLine(Offset(cx - half, y), Offset(cx + half, y), thread);
    }
  }

  /// Draws an X across [rect].
  static void cross(Canvas canvas, Rect rect, Color color, double width) {
    final paint = _stroke(color, width)..strokeCap = StrokeCap.round;
    final r = rect.deflate(rect.shortestSide * 0.12);
    canvas.drawLine(r.topLeft, r.bottomRight, paint);
    canvas.drawLine(r.topRight, r.bottomLeft, paint);
  }

  static void _fracture(
    Canvas canvas,
    ToothShape shape,
    Color color,
    OdontogramStyle style,
  ) {
    final c = shape.crownBounds;
    final path = Path()..moveTo(c.left + c.width * 0.2, c.top + c.height * 0.1);
    const steps = 5;
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      final dx = (i.isOdd ? 0.25 : -0.05) * c.width;
      path.lineTo(
        c.left + c.width * 0.2 + dx + t * c.width * 0.3,
        c.top + c.height * (0.1 + 0.8 * t),
      );
    }
    canvas.drawPath(path, _stroke(color, style.outlineWidth * 2));
  }

  static void _watch(
    Canvas canvas,
    ToothShape shape,
    Color color,
    OdontogramStyle style,
  ) {
    final c = shape.crownBounds;
    final r = math.max(3.0, c.shortestSide * 0.12);
    final centre = Offset(c.left + r * 1.4, c.bottom - r * 1.4);
    canvas.drawCircle(centre, r, _stroke(color, style.outlineWidth * 1.5));
    canvas.drawCircle(centre, r * 0.4, Paint()..color = color);
  }

  /// Strokes [path] with a dash pattern.
  static void dashedPath(Canvas canvas, Path path, Color color, double width) {
    final paint = _stroke(color, width);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dash = 4.0;
      const gap = 3.0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }
}
