import 'dart:ui';

import 'package:ampdent_core/ampdent_core.dart';

/// Drawing geometry for one tooth inside a rectangular cell: five tappable
/// crown faces keyed by [ToothSurface], a simplified root silhouette and a
/// label anchor. Build one with [ToothGeometry.build].
///
/// Orientation follows the clinician's view of the patient (patient's right
/// on the viewer's left): mesial faces the midline, facial faces the lips
/// (the root side of the cell) and lingual faces the tongue.
class ToothShape {
  const ToothShape._({
    required this.tooth,
    required this.bounds,
    required this.crownBounds,
    required this.surfaces,
    required this.crownOutline,
    required this.rootPath,
    required this.classVPath,
    required this.labelAnchor,
    required this.occlusalCentre,
    required this.rootUp,
  });

  /// The tooth this shape draws.
  final ToothId tooth;

  /// The cell the shape was generated in (root plus crown).
  final Rect bounds;

  /// Bounding box of the crown 'map view'.
  final Rect crownBounds;

  /// The five crown faces (M, O/I, D, F, L) as closed polygons.
  final Map<ToothSurface, Path> surfaces;

  /// Outline of the whole crown.
  final Path crownOutline;

  /// Simplified root silhouette (1-3 roots per [ToothId.typicalRootCount]).
  final Path rootPath;

  /// Thin cervical band on the facial face used for Class V lesions.
  final Path classVPath;

  /// Centre point of the label slot on the occlusal side of the cell.
  final Offset labelAnchor;

  /// Centre of the occlusal / incisal region.
  final Offset occlusalCentre;

  /// True when the root apex points up (upper arch).
  final bool rootUp;

  /// Path for any surface: crown faces, the root, the Class V band or the
  /// whole tooth (crown plus root).
  Path pathForSurface(ToothSurface surface) {
    switch (surface) {
      case ToothSurface.root:
        return rootPath;
      case ToothSurface.classV:
        return classVPath;
      case ToothSurface.whole:
        return Path()
          ..addPath(crownOutline, Offset.zero)
          ..addPath(rootPath, Offset.zero);
      default:
        return surfaces[surface]!;
    }
  }

  /// The crown face under [point] (same coordinate space as [bounds]), the
  /// root when the point is on the root silhouette, or null.
  ToothSurface? surfaceAt(Offset point) {
    if (!bounds.contains(point)) return null;
    for (final entry in surfaces.entries) {
      if (entry.value.contains(point)) return entry.key;
    }
    if (rootPath.contains(point)) return ToothSurface.root;
    return null;
  }

  /// Whether [point] lies on the drawn tooth (crown or root).
  bool contains(Offset point) =>
      bounds.contains(point) &&
      (crownOutline.contains(point) || rootPath.contains(point));
}

/// Procedural tooth shape generator. Shapes are produced in a unit box with
/// the root apex up and mesial to the right, then mirrored for left-side and
/// lower-arch teeth and scaled into the requested cell.
class ToothGeometry {
  const ToothGeometry._();

  /// Fraction of the cell height occupied by the root (canonical top).
  static const double rootFraction = 0.46;

  /// Fraction of the cell width the crown occupies, by tooth.
  static double crownWidthFraction(ToothId tooth) {
    final base = switch (tooth.type) {
      ToothType.molar => 0.92,
      ToothType.premolar => 0.78,
      ToothType.canine => 0.72,
      ToothType.incisor =>
        tooth.position == 1
            ? (tooth.arch == Arch.upper ? 0.76 : 0.60)
            : (tooth.arch == Arch.upper ? 0.64 : 0.62),
    };
    return tooth.isPrimary ? base * 0.94 : base;
  }

  /// Builds the shape for [tooth] inside [bounds].
  static ToothShape build(ToothId tooth, Rect bounds) {
    final frame = _Frame(
      bounds,
      flipX: tooth.side == Side.left,
      flipY: tooth.arch == Arch.lower,
    );
    final wf = crownWidthFraction(tooth);
    final left = (1 - wf) / 2;
    final right = 1 - left;
    const top = rootFraction;
    const bottom = 0.98;
    final width = right - left;
    const height = bottom - top;

    // Centre region: square for posterior teeth, incisal strip for anterior.
    final double cl, cr, ct, cb;
    if (tooth.isPosterior) {
      cl = left + width * 0.30;
      cr = right - width * 0.30;
      ct = top + height * 0.30;
      cb = bottom - height * 0.30;
    } else {
      cl = left + width * 0.20;
      cr = right - width * 0.20;
      final mid = top + height * 0.5;
      ct = mid - height * 0.07;
      cb = mid + height * 0.07;
    }

    final surfaces = <ToothSurface, Path>{
      ToothSurface.facial: frame.polygon([
        (left, top),
        (right, top),
        (cr, ct),
        (cl, ct),
      ]),
      ToothSurface.lingual: frame.polygon([
        (left, bottom),
        (cl, cb),
        (cr, cb),
        (right, bottom),
      ]),
      // Canonical mesial is +x (towards the midline for right-side teeth).
      ToothSurface.mesial: frame.polygon([
        (right, top),
        (right, bottom),
        (cr, cb),
        (cr, ct),
      ]),
      ToothSurface.distal: frame.polygon([
        (left, top),
        (cl, ct),
        (cl, cb),
        (left, bottom),
      ]),
      ToothSurface.occlusal: frame.polygon([
        (cl, ct),
        (cr, ct),
        (cr, cb),
        (cl, cb),
      ]),
    };

    final crownOutline = frame.polygon([
      (left, top),
      (right, top),
      (right, bottom),
      (left, bottom),
    ]);
    final classV = frame.polygon([
      (left, top),
      (right, top),
      (right - width * 0.06, top + height * 0.12),
      (left + width * 0.06, top + height * 0.12),
    ]);

    final crownRect = Rect.fromPoints(
      frame.map(left, top),
      frame.map(right, bottom),
    );
    return ToothShape._(
      tooth: tooth,
      bounds: bounds,
      crownBounds: crownRect,
      surfaces: surfaces,
      crownOutline: crownOutline,
      rootPath: _roots(tooth, frame, left, right, top),
      classVPath: classV,
      labelAnchor: frame.map(0.5, 1.0),
      occlusalCentre: frame.map((cl + cr) / 2, (ct + cb) / 2),
      rootUp: tooth.arch == Arch.upper,
    );
  }

  static Path _roots(
    ToothId tooth,
    _Frame frame,
    double crownLeft,
    double crownRight,
    double baseY,
  ) {
    final width = crownRight - crownLeft;
    final x0 = crownLeft + width * 0.12;
    final x1 = crownRight - width * 0.12;
    final flare = tooth.isPrimary ? 0.07 : 0.0;
    const apexY = 0.03;
    final path = Path();
    switch (tooth.typicalRootCount) {
      case 1:
        _root(path, frame, x0, x1, (x0 + x1) / 2, apexY, baseY);
      case 2:
        final mid = (x0 + x1) / 2;
        final gap = width * 0.05;
        _root(
          path,
          frame,
          x0,
          mid - gap,
          x0 + (mid - gap - x0) * 0.4 - flare,
          apexY + 0.02,
          baseY,
        );
        _root(
          path,
          frame,
          mid + gap,
          x1,
          mid + gap + (x1 - mid - gap) * 0.6 + flare,
          apexY + 0.02,
          baseY,
        );
      default:
        final third = (x1 - x0) / 3;
        final gap = width * 0.03;
        _root(
          path,
          frame,
          x0,
          x0 + third - gap,
          x0 + third * 0.4 - flare,
          apexY + 0.02,
          baseY,
        );
        _root(
          path,
          frame,
          x0 + third + gap,
          x0 + 2 * third - gap,
          x0 + third * 1.5,
          apexY + 0.12,
          baseY,
        );
        _root(
          path,
          frame,
          x0 + 2 * third + gap,
          x1,
          x1 - third * 0.4 + flare,
          apexY + 0.02,
          baseY,
        );
    }
    return path;
  }

  static void _root(
    Path path,
    _Frame frame,
    double x0,
    double x1,
    double apexX,
    double apexY,
    double baseY,
  ) {
    final controlY = apexY + (baseY - apexY) * 0.45;
    final start = frame.map(x0, baseY);
    final c1 = frame.map(x0, controlY);
    final apex = frame.map(apexX, apexY);
    final c2 = frame.map(x1, controlY);
    final end = frame.map(x1, baseY);
    path
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(c1.dx, c1.dy, apex.dx, apex.dy)
      ..quadraticBezierTo(c2.dx, c2.dy, end.dx, end.dy)
      ..close();
  }
}

/// Maps canonical unit coordinates (root up, mesial right) into a cell,
/// mirroring for left-side teeth and the lower arch.
class _Frame {
  const _Frame(this.bounds, {required this.flipX, required this.flipY});

  final Rect bounds;
  final bool flipX;
  final bool flipY;

  Offset map(double ux, double uy) {
    final x = flipX ? 1 - ux : ux;
    final y = flipY ? 1 - uy : uy;
    return Offset(
      bounds.left + x * bounds.width,
      bounds.top + y * bounds.height,
    );
  }

  Path polygon(List<(double, double)> points) {
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = map(points[i].$1, points[i].$2);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }
}
