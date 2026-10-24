import 'package:flutter/material.dart';

import '../model/tooth_overlay.dart';
import '../painting/overlay_painter.dart';
import '../style/odontogram_style.dart';

/// Compact legend of overlay kinds: a swatch (hatched for planned work) and
/// the kind's label. Defaults to the kinds a clinician meets most.
class ToothLegend extends StatelessWidget {
  const ToothLegend({
    super.key,
    this.kinds = defaultKinds,
    this.style,
    this.textStyle,
  });

  /// Kinds shown, in order.
  final List<OverlayKind> kinds;
  final OdontogramStyle? style;
  final TextStyle? textStyle;

  /// Kinds shown when none are specified.
  static const List<OverlayKind> defaultKinds = [
    OverlayKind.caries,
    OverlayKind.restoration,
    OverlayKind.plannedRestoration,
    OverlayKind.rootCanal,
    OverlayKind.crown,
    OverlayKind.implant,
    OverlayKind.extractionPlanned,
    OverlayKind.missing,
  ];

  @override
  Widget build(BuildContext context) {
    final style =
        this.style ?? OdontogramStyle.of(Theme.of(context).brightness);
    final text = textStyle ?? Theme.of(context).textTheme.bodySmall;
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        for (final kind in kinds)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                size: const Size(14, 14),
                painter: _SwatchPainter(kind, style),
              ),
              const SizedBox(width: 4),
              Text(kind.label, style: text),
            ],
          ),
      ],
    );
  }
}

class _SwatchPainter extends CustomPainter {
  const _SwatchPainter(this.kind, this.style);

  final OverlayKind kind;
  final OdontogramStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final color = style.overlayColors[kind] ?? style.planned;
    final path = Path()..addRect(rect);
    if (kind == OverlayKind.missing) {
      OverlayPainter.cross(canvas, rect, color, 2);
      return;
    }
    if (kind.isPlanned) {
      OverlayPainter.hatch(canvas, path, color, 3);
      canvas.drawRect(
        rect.deflate(0.5),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke,
      );
    } else {
      canvas.drawRect(rect, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _SwatchPainter old) =>
      old.kind != kind || old.style != style;
}
